#!/bin/sh
#
# Tool for hosting git repositories.
#
#    @version  0.2
#    @author   Lauri Rooden - https://github.com/lauriro/gitserv
#    @license  MIT License  - http://lauri.rooden.ee/mit-license.txt
#


export LC_ALL=C

ROOT="$HOME/repo"
KEYS="$HOME/.ssh/authorized_keys"

SELF="`cd "${0%/*}";pwd`/${0##*/}"
CMD="$SSH_ORIGINAL_COMMAND $*"



log() {
	local TXT="${SSH_CLIENT%% *} $USER: $1 -- $CMD"
	logger -t gitserv -p ${2-"info"} "$TXT" || echo "`date -u +"%F %T"` $TXT" >> ${SELF%.*}.log
}

die() {
	log "$1" error
	echo "error: $1" >&2
	exit 1
}

is_admin() {
	[ -z "$SSH_CLIENT" ] || grep " USER=$USER GROUP=[^ ]*\badmin\b" $KEYS >/dev/null || die 'Admin access denied'
}

is_safe() {
	case "$1" in
		*..*) die "DON'T BE EVIL";;
		*[!-a-zA-Z0-9_.,/]*) die "DON'T BE CRUEL";;
		#"") die "Repo name?";;
	esac
}

conf() {
	[ -n "$GIT_NAMESPACE" ] && FILE=$GIT_NAMESPACE || FILE="$R/config"
	git config --file "$FILE" $@
}

get_repos() {
	{
		grep -Ilr --include=*config '^\s*bare = true' * | sed -e 's,/config$,,'
		grep -Ir --include=*.git '^\s*upstream = .*' * | sed 's/:.*= / -> /'
	} 2>/dev/null | sort
}

get_users() {
	sed -nEe "s/^.* USER=(${1-"[^ ]*"}) GROUP=([^ ]*).*/\1 [\2]/p" $KEYS
}

acc_re() {
	get_users $1 | tr ", " "|" | tr -d "[]"
}

acc() {
	conf --get-regexp "^access\.$1" | \
	grep -Eq "$(acc_re $USER)" || die "${2-"Repository not found"}"
}


{ cd "$ROOT" || mkdir -p "$ROOT" && cd "$ROOT"; } >/dev/null 2>&1

# deny Ctrl-C and unwanted chars
trap "die 'trap';kill -9 $$" 1 2 3 6 15
expr "$CMD" : '[-a-zA-Z0-9_ +./,'\''@=]*$' >/dev/null || die "DON'T BE NAUGHTY"

[ $# -eq 0 ] && set -- $CMD

# unquoted repo name
R=${2%\'};R=${R#*\'}

# When repo is a file then it is a fork
if [ -f "$R" ]; then
	GIT_NAMESPACE=$R
	R=$(conf fork.upstream)
	BACKEND=$(conf fork.backend)
fi

#- Example usage:
#- 
case $1 in
	git-*)   # git pull and push
		if [ -n "$BACKEND" ]; then
			HOST="host=$BACKEND"
			SIZE=$(expr ${#1} + ${#R} + ${#HOST} + 7)
			PIPE=$(mktemp -u)
			mkfifo -m 600 $PIPE
			exec 4<>"$PIPE"
			nc localhost 9418 <&4 &
			printf "%04x$1 $R\0$HOST\0" $SIZE >&4
			cat - >&4
			rm $PIPE
		else
			[ $1 = git-receive-pack ] && acc write "WRITE ACCESS DENIED" || acc read
			env GIT_NAMESPACE=$GIT_NAMESPACE git shell -c "$1 '$R'"
		fi
	;;

	update-hook)         # branch based access control
		R=${SSH_ORIGINAL_COMMAND%\'};R=${R#*\'}

		case $2 in
			refs/tags/*)
				acc '(write|tag)$'
				[ "true" = "$(conf --bool tags.denyOverwrite)" ] &&
				git rev-parse --verify -q "$2" && die "You can't overwrite an existing tag"
			;;
			refs/heads/*)
				BRANCH="${2#refs/heads/}"
				acc "(write|write\.$BRANCH)$" "Repo $R Branch '$BRANCH' write denied"

				# The branch is new
				expr $3 : '00*$' >/dev/null || {
					MO="$(conf branch.$BRANCH.mergeoptions)"
					if expr $4 : '00*$' >/dev/null; then
						[ "true" = "$(conf --bool branch.$BRANCH.denyDeletes)" ] && die "Branch '$BRANCH' deletion denied"
					elif [ $3 = "$(cd $R>/dev/null; git-merge-base $3 $4)" ]; then
						# Update is fast-forward
						[ "--no-ff" = "$MO" ] && die 'Fast-forward not allowed'
					else
						[ "--ff-only" = "$MO" ] && die 'Only fast-forward are allowed'
					fi
				}
			;;
			*)
				die "Branch is not under refs/heads or refs/tags. What are you trying to do?"
			;;
		esac
		exit 0
	;;

	r*) is_admin
#-   $ ssh git@host repo
#-   $ ssh git@host repo test.git init
#-   $ ssh git@host repo test.git config access.read all
#-   $ ssh git@host repo test.git config access.write admin,richard
#-   $ ssh git@host repo test.git config access.write.devel all
#-   $ ssh git@host repo test.git config access.tag richard
#-   $ ssh git@host repo test.git config branch.master.denyDeletes true
#-   $ ssh git@host repo test.git config branch.master.mergeoptions "--ff-only"
#-   $ ssh git@host repo test.git config branch.devel.mergeoptions "--no-ff"
#-   $ ssh git@host repo test.git config tags.denyOverwrite true
#-   $ ssh git@host repo test.git describe "My cool repo"
#-   $ ssh git@host repo test.git fork new_repo.git
#-   $ ssh git@host repo test.git drop

		test -e "$R" -o "$3" = "init" -o -z "$3" || die "Repository '$R' not found"

		case "$3" in
			init)
				is_safe "$R"
				[ -e "$R" ] && die "Repository exists"
				git init --bare --shared -q "$R" && \
				printf '#!/bin/sh\n%s update-hook $@\n' "$SELF" > $R/hooks/update && \
				chmod +x $R/hooks/update
			;;
			fork)
				is_safe "$4"
				[ -e "$4" ] && die "Repository exists"
				GIT_NAMESPACE="$4"
				[ "${4%/*}" = "$4" ] || mkdir -p ${4%/*}
				conf fork.upstream "$R"
			;;
			c*)
				conf ${4-'-l'} $5 >&2
				# set default branch
				#git symbolic-ref HEAD refs/heads/master
				# make `git pull` on master always use rebase
				#$ git config branch.master.rebase true
				#You can also set up a global option 
				# to set the last property for every new tracked branch:

				# setup rebase for every tracking branch
				#$ git config --global branch.autosetuprebase always


				#Fetch a group of remotes
				#$ git config remotes.default 'origin mislav staging'
				#$ git remote update
				# fetches remotes "origin", "mislav", and "staging"
				# You can also define a named group like so:
				#$ git config remotes.mygroup 'remote1 remote2 ...'
				#$ git fetch mygroup
			;;
			des*)
				[ "$R" = "$2" ] || die "Forks does not have descriptions"
				shift 3
				echo "$*" > $R/description
			;;
			def*)
				git --git-dir "$R" symbolic-ref HEAD refs/heads/$4
				;;
			drop)
				# Backup repo
				tar -czf "$2.$(date -u +'%Y%m%d%H%M%S').tar.gz" $2

				# TODO:2012-10-18:lauriro: Remove namespaced data from repo
				rm -rf $2
			;;
			*)
				if [ -e "$2" ]; then
					printf "Repo: $2 - `cat $R/description`\nSize: `du -hs $2|cut -f1`\n\nPermissions:\n"
					conf --get-regexp '^access\.' | tr ",=" "| " | while read name RE;do
						echo "$name [$RE] - `get_users|grep -E "\\b($RE)\\b"|cut -d" " -f1|sort|tr "\n" " "`"
					done
				else
					printf "LIST OF REPOSITORIES:\n`get_repos`\n"
				fi >&2
			;;
		esac
	;;

	u*) is_admin
#-   $ ssh git@host user
#-   $ ssh git@host user richard
#-   $ ssh git@host user richard add
#-   $ ssh git@host user richard key 'sh-rsa AAAAB3N...50i8Q==' richard@example.com
#-   $ ssh git@host user richard group all,admin
#-   $ ssh git@host user richard del
#-

		case $3 in
			a*) # Add
				grep -q " USER=$2 " $KEYS && die 'User exists'
				printf 'command="env USER=%s GROUP=all %s",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty NOKEY\n' "$2" "$SELF" >> $KEYS
			;;
			del) # Del
				sed -ie "/ USER=$2 /d" $KEYS
			;;
			g*) # Group
				is_safe "$4"
				sed -ie "/ USER=$2 /s/GROUP=[^ ]*/GROUP=$4/" $KEYS
			;;
			k*) # Key
				sed -ie "/ USER=$2 /s/no-pty .*$/no-pty $4/" $KEYS
			;;
			*)
				if [ -n "$2" ]; then
					RE="$(acc_re $2)"
					if [ -n "$RE" ]; then
						printf "User: `get_users $2`\nAccesses to:\n"

						get_repos | while read -r R; do
							NS=${R%% ->*}
							[ "$NS" != "$R" ] && GIT_NAMESPACE=$NS || GIT_NAMESPACE=""
							ACC=$(conf --get-regexp '^access\.' | sed -Ee "/$RE/!d;s,^access\.,,;s, .*$,,")
							[ "$ACC" ] && echo "$R ["$ACC"]"
						done
					else
						echo "error: User '$2' do not exists"
					fi
				else
					printf "LIST OF USERS:\n`get_users`\n"
				fi >&2
			;;
		esac
	;;

	*)
		sed -n "/^#- /s///p" "$SELF" >&2
	;;
esac

log

exit 0


