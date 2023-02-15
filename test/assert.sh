#!/bin/sh

LANG=C
SUB=$1
SEQ=1000

export TMP=$(mktemp -d)

SNAP=$BIN/test/snap

: ${PASS:=0}
: ${FAIL:=0}
: ${SYNC:=0}

red="\033[31m"
green="\033[32m"
yellow="\033[33m"
reset="\033[0m"
bold="\033[1m"

OUT="${green}${bold}PASS:%s${reset} FAIL:%s"
ERR="^^^\n  ${red}✘${reset}"
OK="  ${green}✔${reset}"

[ "$SUB" = "up" ] &&: ERR="  ${yellow}ℹ${reset}" && rm $SNAP/*

die() {
	printf "ERROR: %s\n" "$@" >&2
	exit 2
}
bye() {
	printf "\n$OUT\n\n" $PASS $FAIL
	times
	rm -rf $TMP
	[ "$SUB" = "up" ] && git add $SNAP/
	exit $FAIL
}

trap "bye" 0 1 2 3 6 15


Check() {
	set -- "$SNAP/$1${2-".$NAME"}" "$TMP/$1"
	diff -uN --color=always "$1" "$2" &&: $((PASS+=1)) || {
		LINE=$ERR
		OUT="PASS:%s ${red}${bold}FAIL:%s${reset}"
		[ "$SUB" = "up" ] && cp "$2" "$1" &&: $((SYNC+=1)) ||: $((FAIL+=1))
	}
}

It() {
	assert 0 "It $@"
}
Test() {
	assert 0 "Test $@"
}
Fail() {
	EXIT=$1
	shift
	assert $EXIT "Fail $@"
}

assert() {
	: $((SEQ+=1))
	EXIT=$1
	NAME="${SEQ#?}. $2"
	LINE=$OK
	shift 2
	$CMD $@ >"$TMP/$NAME.stdout" 2>"$TMP/$NAME.stderr"
	_EXIT=$?
	Check "$NAME.stderr" ""
	Check "$NAME.stdout" ""
	[ "$_EXIT" = "$EXIT" ] ||: LINE="exit status expected:$EXIT actual:$_EXIT\n$ERR"
	printf "$LINE $NAME\n"

	[ "$SUB" = "debug" ] && {
		echo "\$ $CMD $@"
		cat "$TMP/$NAME.stdout" "$TMP/$NAME.stderr"
	}
	#sleep 10
}

