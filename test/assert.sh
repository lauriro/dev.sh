#!/bin/sh

LANG=C
SUB=$1

export HOME=$(cd ${0%/*}/..;pwd)
export TMP=$(mktemp -d)


SNAP=$HOME/test/snap

: ${PASS:=0}
: ${FAIL:=0}
: ${SYNC:=0}
: ${SEQ:=0}

red="\033[31m"
green="\033[32m"
yellow="\033[33m"
reset="\033[0m"
bold="\033[1m"

OUT="${green}${bold}PASS:%s${reset} FAIL:%s"
ERR="^^^\n  ${red}✘${reset}"
OK="  ${green}✔${reset}"

[ "$SUB" = "up" ] && ERR="${yellow}ℹ${reset}"

die() {
	printf "ERROR: %s\n" "$@" >&2
	exit 2
}
bye() {
	printf "\n$OUT\n\n" $PASS $FAIL
	times
	rm -rf $TMP
	exit $FAIL
}

trap "bye" 0 1 2 3 6 15


compare() {
	set -- "$SNAP/$1$2" "$TMP/$1"
	diff -uN --color=always $1 $2 &&: $((PASS+=1)) || {
		ICON=$ERR
		OUT="PASS:%s ${red}${bold}FAIL:%s${reset}"
		[ "$SUB" = "up" ] && cp $2 $1 &&: $((SYNC+=1)) ||: $((FAIL+=1))
	}
}

assert() {
	[ -f "$TMP/$2.stdout" ] && die "duplicate test name: $2"
	EXIT=$1
	NAME=$2
	ICON=$OK
	shift 2
	#sleep 10
	$CMD "$@" >"$TMP/$NAME.stdout" 2>"$TMP/$NAME.stderr"
	_EXIT=$?
	compare "$NAME.stderr"
	compare "$NAME.stdout"
	[ "$_EXIT" = "$EXIT" ] || die "exit status expected:$EXIT actual:$EXIT"
	printf "$ICON $((SEQ+=1)). $NAME\n$DIFF"

	[ "$SUB" = "debug" ] && {
		echo "\$ $CMD $@"
		cat "$TMP/$NAME.stdout" "$TMP/$NAME.stderr"
	}
}

