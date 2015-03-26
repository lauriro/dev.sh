#!/bin/sh
#
# Host a git server with git-shell
#
#    @version  0.2
#    @author   Lauri Rooden - https://github.com/lauriro/gitserv
#    @license  MIT License  - http://lauri.rooden.ee/mit-license.txt
#


export LC_ALL=C

ROOT=$HOME/repo
LOGS=$HOME/logs/gitserv.log
KEYS=$HOME/.ssh/authorized_keys
TIME=$(date -u +"%FT%T.%3NZ")

CMD=${SSH_ORIGINAL_COMMAND-"$*"}


log() {
	printf "%s %s %s: %s -- %s\n" \
		"$(date -u +"%F %T")" "${SSH_CLIENT%% *}" "$USER" "$1" "$CMD" >> $LOGS
}

die() {
	log "$1" error
	printf "error: %s${2+"\\nerror: "}%s\n" "$1" "$2" >&2
	exit 2
}

conf() {
	git config --file "${FORK:-$REPO/config}" "$@"
}

user_conf() {
	git config --file "$ROOT/users.conf" "$@"
}

acc() {
	expr ",all,$USER,$GROUP," : ".*,\($(conf --get-regexp "^access\.$1")\)," >/dev/null \
		|| die "${2-"Repository not found"}"
}

read_repo() {
	# unquote repo name
	REPO=${1%\'}
	REPO=${REPO#*\'}

	# append .git when needed
	REPO=${REPO%.git}.git

	# When repo is a file then it is a fork or in other backend
	if [ -f "$REPO" ]; then
		FORK=$REPO
		REPO=$(conf fork.upstream)
		BACKEND=$(conf fork.backend)
	fi
}

test -r "${CONF=/etc/gitserv.conf}" && . "$CONF"

# deny Ctrl-C and unwanted chars
trap "die \"trap $LINENO\";kill -9 $$" 1 2 3 6 15 ERR

expr "$CMD " : '[-a-zA-Z0-9_ +./,'\''@=|]*$' >/dev/null || die "DON'T BE NAUGHTY"



if [ "${0##*/}" = "gitserv.sh" ]; then
	set -- $CMD

	read_repo "$2"

	case $1 in
	git-*)   # git pull and push
		[ $1 = git-receive-pack ] && acc write "WRITE ACCESS DENIED" || acc read
		if [ -n "$BACKEND" ]; then
			SIZE=$(expr length "$1$REPO$BACKEND" + 13)
			PIPE=$(mktemp -u)
			mkfifo -m 600 $PIPE
			exec 4<>"$PIPE"
			nc localhost 9418 <&4 &
			printf "%04x%s /%s\0host=%s\0" $SIZE "$1" "$REPO" "$BACKEND" >&4
			cat - >&4
			rm $PIPE
		else
			env GIT_NAMESPACE=$FORK git shell -c "$1 '$REPO'"

			# Assigns the original repository to a remote called "upstream"
			if [ -n $FORK ]; then
				printf "%s is a fork, you may want to add an upstream:\n" "$FORK" >&2
				printf "   git remote add upstream %s\n" "$REPO" >&2
			fi

			# remote: This repository moved. Please use the new location:
			# remote:   https://github.com/lauriro/lauriro.github.io.git
		fi
		;;
	?*)
		exec git shell -c "$*"
		;;
	*)
		exec git shell ;;
	esac

	log
	exit 0
fi


SELF="$(cd "${0%/*}";pwd)/${0##*/}"
column() {
	git column --mode=auto --padding=2 --indent="   "
}

ask() {
	while true; do
		printf "${1:-"Are you sure?"} [${2:-"Y/n"}] "
		read r
		case "$r${2:-"Y/n"}" in
			y*|Y*) return 0 ;;
			n*|N*) return 1 ;;
			*) printf "Please answer yes or no." ;;
		esac
	done
}

valid() {
	expr "$2" : "$1" >/dev/null
	test "$?$3" = "0" || die "Name '$2' is not available" "It should match to ^$1"
}


