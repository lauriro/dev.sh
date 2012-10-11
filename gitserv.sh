#!/bin/sh
#
# Tool for git hosting
#
#
# THE BEER-WARE LICENSE
# =====================
#
# <lauri@rooden.ee> wrote this file. As long as you retain this notice
# you can do whatever you want with this stuff. If we meet some day, and
# you think this stuff is worth it, you can buy me a beer in return.
# -- Lauri Rooden
#
#- 
#- Add GIT alias:
#- 
#-   $ git config --global alias.admin '!sh -c '\''URL=$(git config remote.origin.url) && ssh ${URL%%:*} $*'\'' -' 
#- 
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
#- Example commands without git alias:
#- 
#-   $ ssh git@repo.example.com user
#-   $ ssh git@repo.example.com user show richard
#- 


export LC_ALL=C

# Exit the script if any statement returns a non-true return value
set -e


KEYS=$HOME/.ssh/authorized_keys
REPO=$HOME/repo
LOGI=$HOME/access.log
LINE="command=\"env USER=%s GROUP=all $0 \$SSH_ORIGINAL_COMMAND\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty %s\n"
CMD="$*"


usage() {
	sed -n "/^#- \?/s///p" "$0" >&2
}

log() {
	echo "$(date -u +'%Y-%m-%d %H:%M:%S') ${SSH_CLIENT%% *} $USER: $1$CMD" >> $LOGI
}

deny() {
	log "ERROR: $1: "
	printf '\n*** %s ***\n\n' "$1" >&2
	exit 1
}

is_admin() {
	[ -z "$SSH_CLIENT" ] || grep -q "USER=$USER GROUP=[^ ]*\badmin\b" $KEYS || deny 'ADMIN ACCESS DENIED'
}

access_re() {
	sed -E -e 's/^.*USER='$1' GROUP=([^ ]*) .*$/ .*\\b('$1'|\1)\\b/;ta' -e d -e :a -e 's/,/|/g' $KEYS
}

access_to_repo() {
	git --git-dir=$1 config --get-regexp "^access\.$2" | \
	grep -E -q "$(access_re $USER)" || deny "REPOSITORY '${1#$REPO/}' $3 ACCESS DENIED"
}

list_of_repos() {
	grep -Ilr --include=*config '^\s*bare = true' * 2>/dev/null | sort | sed -e 's,/config$,,'
}


# deny Ctrl-C and unwanted chars
trap "deny 'BYE';kill -9 $$" 1 2 3 6 15
expr "$*" : '[[:alnum:] ,'\''./_@=+-]*$' >/dev/null || deny "DON'T BE NAUGHTY"

cd $REPO 2>/dev/null || mkdir -p $REPO && cd $REPO

case $1 in
	git-upload-pack|git-upload-archive|git-receive-pack)   # git pull and push
		R=${2#\'};R=${R%\'}                                  # unquoted repo name
		
		access_to_repo $R 'read' 'READ'

		[ "$1" = "git-receive-pack" ] && access_to_repo $R 'write' 'WRITE'
	
		git shell -c "$*"
	;;

	update-hook)         # branch based access control
		case $2 in
			refs/tags/*)
				access_to_repo $PWD '(write|tag)$' 'TAGGING'
				[ "true" = "$(git config --bool tags.denyOverwrite)" ] &&
				git rev-parse --verify -q "$2" && deny "You can't overwrite an existing tag"
			;;
			refs/heads/*)
				BRANCH="${2#refs/heads/}"
				access_to_repo $PWD "(write|write\.$BRANCH)$" "BRANCH '$BRANCH' WRITE"
				
				if expr "$3" : '0*$' >/dev/null; then
					# The branch is new
					echo "The branch $BRANCH is new..." >&2
				elif expr "$4" : '0*$' >/dev/null; then
					[ "true" = "$(git config --bool branch.$BRANCH.denyDeletes)" ] && deny "BRANCH '$BRANCH' DELETION DENIED"
				elif [ "$3" = "$(git-merge-base "$3" "$4")" ]; then
					# Update is fast-forward
					[ "--no-ff" = "$(git config branch.$BRANCH.mergeoptions)" ] && deny 'FAST-FORWARD NOT ALLOWED'
				else
					[ "--ff-only" = "$(git config branch.$BRANCH.mergeoptions)" ] && deny 'ONLY FAST-FORWARD ARE ALLOWED'
				fi
			;;
			*)
				deny "Branch is not under refs/heads or refs/tags. What are you trying to do?"
			;;
		esac

		exit 0
	;;

	u*) # user
		is_admin

		case $2 in
			a*) # add
				grep -q "USER=$3 " $KEYS && deny 'USER EXISTS'
				printf "$LINE" "$3" "$4" >> $KEYS
			;;
			d*) # del
				sed -ie "/USER=$3 /d" $KEYS
			;;
			g*) # group
				sed -ie "/USER=$3 /s/GROUP=[^ ]*/GROUP=$4/" $KEYS
			;;
			k*) # key
				sed -ie "/USER=$3 /s/no-pty .*$/no-pty $4/" $KEYS
			;;
			*)
				if [ "$3" ]; then
					RE="$(access_re $3)"
					if [ -n "$RE" ]; then
						echo "USER '$3' PERMISSIONS:" >&2

						list_of_repos | while read -r R; do 
							ACC=$(git --git-dir=$R config --get-regexp '^access\.' | grep -E "$RE" | sed -e 's,^access\.,,' -e 's, .*$,,')
							[ "$ACC" ] && echo "  - $R ["$ACC"]" >&2
						done
					else
						echo "*** USER '$3' DO NOT EXISTS ***" >&2
					fi
				fi

				echo 'LIST OF USERS:' >&2
				sed -E -e 's,^.*USER=([^ ]*) GROUP=([^ ]*).*$,  - \1 [\2],;t' -e d $KEYS >&2
			;;
		esac
	;;

	r*) # repo
		is_admin

		case $2 in
			a*) # add new repo
				[ -d $3 ] && deny "REPOSITORY $3 EXISTS"
				mkdir -p $3 && \
				cd $3 && \
				git init --bare && \
				printf '#!/bin/sh\n%s update-hook \$@\n' "$0" > hooks/update && \
				chmod +x hooks/update
			;;
			d*) # del
				[ -d $3 ] || deny "REPOSITORY $3 DO NOT EXISTS"

				# Backup repo
				(cd $3 && tar -czf "../$3.$(date -u +'%Y%m%d%H%M%S').tar.gz" *)

				rm -rf $3
			;;
			c*) # config
				[ -d $3 ] || deny "REPOSITORY $3 DO NOT EXISTS"
				git --git-dir="$HOME/$3" config ${4-'-l'} $5 >&2
			;;
			*) # List of repos
				echo 'LIST OF REPOSITORIES:' >&2
				du -shc $(list_of_repos) | sed -e 's,^,  - ,' >&2
			;;
		esac
	;;
	*)
		usage
	;;
esac

log

exit 0

