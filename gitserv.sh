#!/bin/sh
#
# Tool for hosting git
#
#    @version  0.1-pre
#    @author   Lauri Rooden - https://github.com/lauriro/gitserv.sh
#    @license  MIT License  - http://lauri.rooden.ee/mit-license.txt
#


export LC_ALL=C
# Exit the script if any statement returns a non-true return value
set -e

cd "${0%/*}/." >/dev/null

SELF="$PWD/${0##*/}"
LOGI="$PWD/access.log"
REPO="$PWD/repo"
KEYS="$HOME/.ssh/authorized_keys"
LINE="command=\"env USER=%s GROUP=all $SELF\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty %s"

cd "$REPO" 2>/dev/null || mkdir -p "$REPO" && cd "$REPO" 2>/dev/null

log() {
	echo "$(date -u +'%Y-%m-%d %H:%M:%S') ${SSH_CLIENT%% *} $USER: $1$SSH_ORIGINAL_COMMAND" >> $LOGI
}

deny() {
	log "ERROR: $1: "
	printf '\n***\n* ERROR: %s.\n***\n\n' "$1" >&2
	exit 1
}

# deny Ctrl-C and unwanted chars
trap "deny 'BYE';kill -9 $$" 1 2 3 6 15
expr "$SSH_ORIGINAL_COMMAND$*" : '[[:alnum:] ,'\''./_@=+-]*$' >/dev/null || deny "DON'T BE NAUGHTY"


is_admin() {
	[ -z "$SSH_CLIENT" ] || grep -q " USER=$USER GROUP=[^ ]*\badmin\b" $KEYS || deny 'Admin access denied'
}

conf() {
	[ -n "$GIT_NAMESPACE" ] && FILE=$GIT_NAMESPACE || FILE="$R/config"
	git config --file "$FILE" $@
}

acc_re() {
	sed -E -e 's/^.*USER='$1' GROUP=([^ ]*) .*$/ .*\\b('$1'|\1)\\b/;ta' -e d -e :a -e 's/,/|/g' $KEYS
}

acc() {
	conf --get-regexp "^access\.$1" | \
	grep -E -q "$(acc_re $USER)" || deny "${2-"Repository not found"}"
}

list_of_repos() {
	{
		grep -Ilr --include=*config '^\s*bare = true' * 2>/dev/null | sed -e 's,/config$,,'
		grep -I '^\s*master = .*' * 2>/dev/null | sed 's/:.*= / -> /'
	} | sort
}



[ $# -eq 0 ] && set -- $SSH_ORIGINAL_COMMAND

# unquoted repo name
R=${2%\'};R=${R#*\'}

# When repo is a file then it is a fork
[ -f "$R" ] && GIT_NAMESPACE=$R && R=$(conf fork.master)

#- Example usage:
#- 
case $1 in
	git-upload-pack|git-upload-archive|git-receive-pack)   # git pull and push
		acc read
		[ $1 = git-receive-pack ] && acc write "WRITE ACCESS DENIED"
		env GIT_NAMESPACE=$GIT_NAMESPACE git shell -c "$1 '$R'"
	;;

	update-hook)         # branch based access control

		case $2 in
			refs/tags/*)
				acc '(write|tag)$'
				[ "true" = "$(conf --bool tags.denyOverwrite)" ] &&
				git rev-parse --verify -q "$2" && deny "You can't overwrite an existing tag"
			;;
			refs/heads/*)
				BRANCH="${2#refs/heads/}"
				acc "(write|write\.$BRANCH)$" "BRANCH '$BRANCH' WRITE"
				
				if expr $3 : '0*$' >/dev/null; then
					# The branch is new
					true
				elif expr $4 : '0*$' >/dev/null; then
					[ "true" = "$(conf --bool branch.$BRANCH.denyDeletes)" ] && deny "BRANCH '$BRANCH' DELETION DENIED"
				elif [ $3 = "$(cd $R>/dev/null; git-merge-base $3 $4)" ]; then
					# Update is fast-forward
					[ "--no-ff" = "$(conf branch.$BRANCH.mergeoptions)" ] && deny 'FAST-FORWARD NOT ALLOWED'
				else
					[ "--ff-only" = "$(conf branch.$BRANCH.mergeoptions)" ] && deny 'ONLY FAST-FORWARD ARE ALLOWED'
				fi
			;;
			*)
				deny "Branch is not under refs/heads or refs/tags. What are you trying to do?"
			;;
		esac

		exit 0
	;;

	repo)
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
#-   $ ssh git@host repo test.git drop
		is_admin

		test -e "$R" -o "$3" = "init" -o -z "$3" || deny "Repository $R not found"
		
		case "$3" in
			init)
				[ -e "$R" ] && deny "Repository exists"
				mkdir -p "$R" && \
				cd "$R" >/dev/null && \
				git init --bare -q && \
				printf '#!/bin/sh\n%s update-hook $@\n' "$SELF" > hooks/update && \
				chmod +x hooks/update
			;;
			drop)
				# Backup repo
				tar -czf "$2.$(date -u +'%Y%m%d%H%M%S').tar.gz" $2

				rm -rf $2
			;;
			config)
				conf ${4-'-l'} $5 >&2
			;;
			fork)
				GIT_NAMESPACE="$4"
				conf fork.master "$R"
			;;
			*)
				printf "\nLIST OF REPOSITORIES:\n%s\n" "$(list_of_repos | xargs du -s)" >&2
			;;
		esac
	;;

	user)
#-   $ ssh git@host user
#-   $ ssh git@host user richard
#-   $ ssh git@host user richard add 'sh-rsa AAAAB3N...50i8Q==' user@example.com
#-   $ ssh git@host user richard key 'sh-rsa AAAAB3N...50i8Q==' user@example.com
#-   $ ssh git@host user richard group all,admin
#-   $ ssh git@host user richard del
#-
		is_admin

		case $3 in
			add)
				grep -q " USER=$2 " $KEYS && deny 'USER EXISTS'
				printf "$LINE\n" "$2" "$4" >> $KEYS
			;;
			del)
				sed -ie "/ USER=$2 /d" $KEYS
			;;
			group)
				sed -ie "/ USER=$2 /s/GROUP=[^ ]*/GROUP=$4/" $KEYS
			;;
			key)
				sed -ie "/ USER=$2 /s/no-pty .*$/no-pty $4/" $KEYS
			;;
			*)
				if [ -n "$2" ];then
					RE="$(acc_re $2)"
					if [ -n "$RE" ]; then
						printf "\nUSER '%s' PERMISSIONS:\n" "$2" >&2

						list_of_repos | while read -r R; do 
							NS=${R%% ->*}
							[ "$NS" != "$R" ] && GIT_NAMESPACE=$NS || GIT_NAMESPACE=""
							ACC=$(conf --get-regexp '^access\.' | grep -E "$RE" | sed -e 's,^access\.,,' -e 's, .*$,,')
							[ "$ACC" ] && echo "$R ["$ACC"]" >&2
						done
					else
						echo "ERROR: User '$2' do not exists" >&2
					fi
				fi
			;;
		esac

		printf "\nLIST OF USERS:\n%s\n" "$(sed -nE -e 's,^.*USER=([^ ]*) GROUP=([^ ]*).*$,\1 [\2],p' $KEYS)" >&2
	;;

	*)
		sed -n "/^#- /s///p" "$SELF" >&2
	;;
esac

log

exit 0

#- 
#- Add GIT alias:
#- 
#-   $ git config --global alias.admin '!sh -c '\''URL=$(git config remote.origin.url) && ssh ${URL%%:*} $*'\'' -' 
#- 
#- Example commands without git alias:
#- 
#-   $ ssh git@repo.example.com user
#-   $ ssh git@repo.example.com user show richard
#- 
