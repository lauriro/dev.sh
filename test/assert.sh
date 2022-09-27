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
ERR="${red}✘${reset}"
OK="${green}✔${reset}"

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
	[ -f "$TMP/$2.stdout" ] && die "duplicated test name: $2"
	ICON=$OK
	#sleep 10
	$CMD $3 >$TMP/$2.stdout 2>$TMP/$2.stderr
	EXIT=$?
	compare $2.stderr
	compare $2.stdout
	printf "  $ICON $((SEQ+=1)). $2\n$DIFF"
	[ "$EXIT" = "$1" ] || die "exit status expected:$1 actual:$EXIT"

	[ "$SUB" = "debug" ] && {
		echo "\$ $CMD $3"
		cat $TMP/$2.stdout $TMP/$2.stderr
	}
}

