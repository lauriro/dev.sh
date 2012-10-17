#!/bin/sh
#
# Tool for hosting git
#
#    @version  0.1-pre
#    @author   Lauri Rooden - https://github.com/lauriro/gitserv.sh
#    @license  MIT License  - http://lauri.rooden.ee/mit-license.txt
#


export LC_ALL=C

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
expr "$SSH_ORIGINAL_COMMAND$*" : '[-+ [:alnum:],'\''./_@=]*$' >/dev/null || deny "DON'T BE NAUGHTY"
expr "$SSH_ORIGINAL_COMMAND$*" : '.*\.\.' >/dev/null && deny "DON'T BE EVIL"


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
				acc "(write|write\.$BRANCH)$" "Branch '$BRANCH' write denied"
				
				# The branch is new
				expr $3 : '00*$' >/dev/null || {
					MO="$(conf branch.$BRANCH.mergeoptions)"
					if expr $4 : '00*$' >/dev/null; then
						[ "true" = "$(conf --bool branch.$BRANCH.denyDeletes)" ] && deny "Branch '$BRANCH' deletion denied"
					elif [ $3 = "$(cd $R>/dev/null; git-merge-base $3 $4)" ]; then
						# Update is fast-forward
						[ "--no-ff" = "$MO" ] && deny 'Fast-forward not allowed'
					else
						[ "--ff-only" = "$MO" ] && deny 'Only fast-forward are allowed'
					fi
				}
			;;
			*)
				deny "Branch is not under refs/heads or refs/tags. What are you trying to do?"
			;;
		esac
	;;

	repo) is_admin
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

		test -e "$R" -o "$3" = "init" -o -z "$3" || deny "Repository $R not found"
		
		case "$3" in
			init)
				#[ -e "$R" ] && deny "Repository exists"
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
				[ -n "$2" -a -e $2 ] && {
					printf "\nDisk usage: %s\n\nRepo '%s' permissions:\n" "$(du -hs $2 | cut -f1)" "$2"
					conf --get-regexp '^access\.' | sed -e 's,^access\.,,' -e 's/,/|/g' | while read name RE;do
						printf "$name [$RE] - %s\n" "$(sed -E -e 's/^.* USER=([^ ]*) GROUP=([^ ]*) .*$/\1 \2/' $KEYS | grep -E "\\b($RE)\\b" | cut -d" " -f1 | sort | tr "\n" " ")"
					done
				} >&2
				printf "\nLIST OF REPOSITORIES:\n%s\n" "$(list_of_repos)" >&2
			;;
		esac
	;;

	user) is_admin
#-   $ ssh git@host user
#-   $ ssh git@host user richard
#-   $ ssh git@host user richard add 'sh-rsa AAAAB3N...50i8Q==' user@example.com
#-   $ ssh git@host user richard key 'sh-rsa AAAAB3N...50i8Q==' user@example.com
#-   $ ssh git@host user richard group all,admin
#-   $ ssh git@host user richard del
#-

		case $3 in
			add)
				grep -q " USER=$2 " $KEYS && deny 'User exists'
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
				[ -n "$2" ] && {
					RE="$(acc_re $2)"
					if [ -n "$RE" ]; then
						printf "\nUser '%s' permissions:\n" "$2" >&2

						list_of_repos | while read -r R; do 
							NS=${R%% ->*}
							[ "$NS" != "$R" ] && GIT_NAMESPACE=$NS || GIT_NAMESPACE=""
							ACC=$(conf --get-regexp '^access\.' | grep -E "$RE" | sed -e 's,^access\.,,' -e 's, .*$,,')
							[ "$ACC" ] && echo "$R ["$ACC"]" >&2
						done
					else
						echo "ERROR: User '$2' do not exists" >&2
					fi
				}
				printf "\nLIST OF USERS:\n%s\n" "$(sed -nE -e 's,^.*USER=([^ ]*) GROUP=([^ ]*).*$,\1 [\2],p' $KEYS)" >&2
			;;
		esac
	;;

	*)
		sed -n "/^#- /s///p" "$SELF" >&2
	;;
esac

log

exit 0


