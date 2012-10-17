#!/bin/sh
#
# Tool for hosting git
#
#    @version  pre-0.1
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
LINE="command=\"env USER=%s GROUP=all $SELF \$SSH_ORIGINAL_COMMAND\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty %s"

CMD="$*"

log() {
	echo "$(date -u +'%Y-%m-%d %H:%M:%S') ${SSH_CLIENT%% *} $USER: $1$CMD" >> $LOGI
}

deny() {
	log "ERROR: $1: "
	printf '\n***\n* ERROR: %s.\n***\n' "$1" >&2
	exit 1
}

# deny Ctrl-C and unwanted chars
trap "deny 'BYE';kill -9 $$" 1 2 3 6 15
expr "$*" : '[[:alnum:] ,'\''./_@=+-]*$' >/dev/null || deny "DON'T BE NAUGHTY"



usage() {
	sed -n "/^#- /s///p" "$SELF" >&2
}

is_admin() {
	[ -z "$SSH_CLIENT" ] || grep -q "USER=$USER GROUP=[^ ]*\badmin\b" $KEYS || deny 'Admin access denied'
}

access_re() {
	sed -E -e 's/^.*USER='$1' GROUP=([^ ]*) .*$/ .*\\b('$1'|\1)\\b/;ta' -e d -e :a -e 's/,/|/g' $KEYS
}

conf() {
	local FILE="$1/config"
	shift
	[ -n "$GIT_NAMESPACE" ] && FILE="$GIT_NAMESPACE"
	git config --file "$FILE" $@
}

access_to_repo() {
	conf $1 --get-regexp "^access\.$2" | \
	grep -E -q "$(access_re $USER)" || deny "Repository not found"
}

list_of_repos() {
	grep -Ilr --include=*config '^\s*bare = true' * 2>/dev/null | sort | sed -e 's,/config$,,'
}


cd $REPO 2>/dev/null || mkdir -p $REPO && cd $REPO 2>/dev/null

#- Example commands:
#- 
#-   $ git admin user
#-   $ git admin user show richard
#-   $ git admin user add richard 'sh-rsa AAAAB3N...50i8Q==' user@example.com
#-   $ git admin user group richard all,admin
#-   $ git admin user key richard 'sh-rsa AAAAB3N...50i8Q==' user@example.com
#-   $ git admin user del richard
#-   $ git admin repo
#-   $ git admin repo add test.git
#-   $ git admin repo config test.git access.read all
#-   $ git admin repo config test.git access.write admin,richard
#-   $ git admin repo config test.git access.write.devel all
#-   $ git admin repo config test.git access.tag richard
#-   $ git admin repo config test.git branch.master.mergeoptions "--ff-only"
#-   $ git admin repo config test.git branch.master.denyDeletes true
#-   $ git admin repo config test.git branch.devel.mergeoptions "--no-ff"
#-   $ git admin repo config test.git tags.denyOverwrite true
#-   $ git admin repo config test.git --unset tags.denyOverwrite
#-   $ git admin repo del test.git
#-

case $1 in
	git-upload-pack|git-upload-archive|git-receive-pack)   # git pull and push
		# unquote repo name
		R=${2#\'};R=${R%\'}

		[ -f "$R" ] && GIT_NAMESPACE=${R} && R=$(conf $R fork.master)
				printf "\nconf:\n%s\n" "$* :: GIT_NAMESPACE=$GIT_NAMESPACE $2 -> $R" >&2
		
		access_to_repo $R 'read' 'READ'

		[ "$1" = "git-receive-pack" ] && access_to_repo $R 'write' 'WRITE'
	
		git shell -c "$1 '$R'"
	;;

	update-hook)         # branch based access control
				printf "\nup: %s\n" "$* :: GIT_NAMESPACE=$GIT_NAMESPACE" >&2
				env >&2
		case $2 in
			refs/tags/*)
				access_to_repo $PWD '(write|tag)$' 'TAGGING'
				[ "true" = "$(conf $PWD --bool tags.denyOverwrite)" ] &&
				git rev-parse --verify -q "$2" && deny "You can't overwrite an existing tag"
			;;
			refs/heads/*)
				BRANCH="${2#refs/heads/}"
				access_to_repo $PWD "(write|write\.$BRANCH)$" "BRANCH '$BRANCH' WRITE"
				
				if expr "$3" : '0*$' >/dev/null; then
					# The branch is new
					echo "The branch $BRANCH is new..." >&2
				elif expr "$4" : '0*$' >/dev/null; then
					[ "true" = "$(conf $PWD --bool branch.$BRANCH.denyDeletes)" ] && deny "BRANCH '$BRANCH' DELETION DENIED"
				elif [ "$3" = "$(git-merge-base "$3" "$4")" ]; then
					# Update is fast-forward
					[ "--no-ff" = "$(conf $PWD branch.$BRANCH.mergeoptions)" ] && deny 'FAST-FORWARD NOT ALLOWED'
				else
					[ "--ff-only" = "$(conf $PWD branch.$BRANCH.mergeoptions)" ] && deny 'ONLY FAST-FORWARD ARE ALLOWED'
				fi
			;;
			*)
				deny "Branch is not under refs/heads or refs/tags. What are you trying to do?"
			;;
		esac

		exit 0
	;;

	repo)
		is_admin

		R="$3"
		[ -f "$R" ] && GIT_NAMESPACE="$R" && R=$(conf "$R" fork.master)

		test -e "$R" -o "$2" = "add" -o -z "$2" || deny "Repository not found"
		
		case "$2" in
			add)
				[ -e "$R" ] && deny "Repository exists"
				mkdir -p "$R" && \
				cd "$R" >/dev/null && \
				git init --bare -q && \
				printf '#!/bin/sh\n%s update-hook \$@\n' "$0" > hooks/update && \
				chmod +x hooks/update
			;;
			del)
				# Backup repo
				tar -czf "$3.$(date -u +'%Y%m%d%H%M%S').tar.gz" "$3"

				rm -rf "$3"
			;;
			config)
				conf "$R" ${4-'-l'} $5 >&2
			;;
			fork)
				GIT_NAMESPACE="$4"
				conf "$4" fork.master "$R"
			;;
			*)
				printf "\nLIST OF REPOSITORIES:\n%s\n" "$(du -shc $(list_of_repos))" >&2
			;;
		esac
	;;

	user)
		is_admin

		case $2 in
			add)
				grep -q "USER=$3 " $KEYS && deny 'USER EXISTS'
				printf "$LINE\n" "$3" "$4" >> $KEYS
			;;
			del)
				sed -ie "/USER=$3 /d" $KEYS
			;;
			group)
				sed -ie "/USER=$3 /s/GROUP=[^ ]*/GROUP=$4/" $KEYS
			;;
			key)
				sed -ie "/USER=$3 /s/no-pty .*$/no-pty $4/" $KEYS
			;;
			*)
				if [ "$3" ]; then
					RE="$(access_re $3)"
					if [ -n "$RE" ]; then
						printf "\nUSER '%s' PERMISSIONS:\n" "$3" >&2

						list_of_repos | while read -r R; do 
							ACC=$(conf $R --get-regexp '^access\.' | grep -E "$RE" | sed -e 's,^access\.,,' -e 's, .*$,,')
							[ "$ACC" ] && echo "$R ["$ACC"]" >&2
						done
					else
						echo "*** USER '$3' DO NOT EXISTS ***" >&2
					fi
				fi

				printf "\nLIST OF USERS:\n" >&2
				sed -E -e 's,^.*USER=([^ ]*) GROUP=([^ ]*).*$,\1 [\2],;t' -e d $KEYS >&2
			;;
		esac
	;;

	*)
		usage
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
