#!/bin/sh
#
# Host a development server
#
#    @version  22.0.0
#    @author   Lauri Rooden - https://github.com/lauriro/dev.sh
#    @license  MIT License  - http://lauri.rooden.ee/mit-license.txt
#-
#- Commands:
#-     repo <project.git> [init|info|rename|conf|drop]
#-     role <rolename>
#-     user <username> [add|delete|conf|addkey|rmkey|info]
#-     help [command]
#-     exit
#-
#- See 'help <command>' to read more about a specific command.
#-
#repo-
#repo- Examples:
#repo-     git> repo [search filter]
#repo-     git> repo test.git init
#repo-     git> repo test.git config access.read all
#repo-     git> repo test.git config access.write admin,richard
#repo-     git> repo test.git config access.write.devel all
#repo-     git> repo test.git config access.tag richard
#repo-     git> repo test.git config branch.master.denyDeletes true
#repo-     git> repo test.git config branch.master.mergeoptions "--ff-only"
#repo-     git> repo test.git config branch.devel.mergeoptions "--no-ff"
#repo-     git> repo test.git config tags.denyOverwrite true
#repo-     git> repo test.git describe "My cool repo"
#repo-     git> repo test.git mv new-repo.git
#repo-     git> repo test.git fork new-repo.git
#repo-     git> repo test.git sta
#role-
#role- Examples:
#role-     git> role [search filter]
#user-
#user- Examples:
#user-     git> user john
#user-     git> user john add
#user-     git> user john addkey <ssh-public-key>
#user-     git> user john name "John Smith"
#user-     git> user john role admin,web
#user-     git> user john rmkey john <fingerprint>
#user-     git> user john delete
#user-

export LC_ALL=C

DATA=$HOME/repo
USERS=$HOME/users.conf
KEY=$HOME/.ssh/authorized_keys
LOG=$HOME/$0-$(date -u +%F).log

NAME_RE='\([a-z]\)\([-_.]\?[a-z0-9]\)\{0,24\}'
LINE="command='env USER=%s FP=%s $0',no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty %s"

CMD=${SSH_ORIGINAL_COMMAND-"$@"}
WHO="${SSH_CLIENT-${SUDO_USER+sudo}} local"
WHO="${WHO%% *} ${SUDO_USER-$USER}"

now() {
	date -u +%FT%TZ
}
log() {
	printf "%s\n" "$@"
	echo "$(now) $WHO: $1 -- $CMD" >> $LOG
}
die() {
	printf "ERROR: %s\n" "$@" >&2
	echo "$(now) $WHO: ERROR: $1 -- $CMD" >> $LOG
	exit 2
}
ask() {
	expr "$CMD" : ".*--yes" >/dev/null 2>&1 && return
	printf "$1 [N/y] "
	read r
	expr "$r" : "[yY]" >/dev/null 2>&1
}
valid() {
	expr "$1" : "$2" >/dev/null 2>&1 || die "${3:-"Invalid name '$1'"}"
}
usage() {
	sed -n "/^#$1- \?/s///p" $0
}
col() {
	sed ${1-'s/^user\.\|\.created .*//g'} | sort -u |\
	sed -e '100s/.*/.../;100q' | git column --mode=column --padding=2 --indent="   "
}

repo() {
	git config --file "$DATA/${FORK:-$REPO/config}" $@
}
repo_exists() {
	LAST_REPO=$REPO
	FORK=''
	# Unquote repo name and ensure it ends with `.git`
	REPO=${1%\'}
	REPO=${REPO#*\'}
	REPO=${REPO%.git}.git

	valid "${2-$REPO}" "$NAME_RE\(/$NAME_RE\)*.git$"
	# git check-ref-format "refs/heads/$REPO" || die "Invalid ref format."
	# When repo is a file then it is a fork
	if [ -f "$DATA/$REPO" ]; then
		FORK=$REPO
		REPO=$(repo repo.upstream)
	fi
	test -n "$(repo "repo.created")"
}
repo_access() {
	re=$(echo admin,$(repo "repo.createdBy"),$(repo "access.$1") | sed 's/,,*/\\|/g')
	valid ",all,$USER,$G," ".*,\($re\)," "Repo '${FORK-$REPO}' does not exists"
}


test -r "${CONF=./$0.conf}" && . $CONF
# deny Ctrl-C and unwanted chars
trap 'die "trap $LINENO";kill -9 '$$ 1 2 3 6 15
valid "$CMD " "[-_a-zA-Z0-9 +./,'@=|:]*$" "DON'T BE NAUGHTY"


(cd "$DATA" >/dev/null 2>&1) || ask "Setup first?" && {
	# Prepare .ssh folder and files
	mkdir -p "$DATA" $(dirname $KEY $LOG)
	touch $KEY
	chmod 700 $(dirname $KEY)
	chmod 600 $KEY
} || die "Can not do anything without setup"


[ "$1" = "git-upload-pack" -o "$1" = "git-receive-pack" ] && {
	repo_exists "$2" || die "Repository not found."
	[ $1 = git-receive-pack ] && repo_access write "WRITE ACCESS DENIED" || repo_access read
	GIT_NAMESPACE=$FORK exec git shell -c "$1 '$REPO'"
}


repo_create() {
	git init --bare -q "$DATA/$REPO" #
	rm -rf "$DATA/$REPO/hooks"
	ln -fs "$HOME/hooks" "$DATA/$REPO/hooks"
}
repo_delete() {
	# Warning: These steps will permanently delete the repository, wiki, issues, and comments.
	# This action cannot be undone.
	# Please also keep in mind that:
	# - Deleting a repository will delete all of its forks.
	tar -czf "$DATA/deleted-$(now).tar.gz" $DATA/$1 2>/dev/null
	rm -rf $DATA/$1
	[ "$REPO" != "$1" ] && rm -rf "$DATA/$REPO/refs/namespaces/$FORK"
}
repo_mv() {
	mv $REPO $LAST_REPO
	log "repo '$REPO' renamed to '$LAST_REPO'"
}
repo_conf() {
	repo "${3-'-l'}" "$4"
	#repo "repo.$1.$3" "$4"
}
repo_fork() {
	FORK=$LAST_REPO
	DIR=$DATA/$FORK
	mkdir -p ${DIR%/*}
	repo repo.$FORK.created "$(now)"
	repo repo.$FORK.createdBy "$WHO"
	repo repo.$FORK.upstream "$REPO"
	printf "Fork '%s' created.\n" "$FORK"
	printf "You may want to add an upstream:\n   git remote add upstream %s\n" "$REPO"
}
repo_info() {
	ACC_R=$(repo repo.read | sed 's/|/\|/')
	ACC_W=$(repo repo.write)
	printf "Repo:  %s\n" "$REPO${FORK:+"<-$FORK"} [R:$ACC_R W:$ACC_W]"
	printf "Owner: %s\n" "$(repo repo.createdBy)"
	printf "Size:  %s\n" "$(test -d "$1" && (cd $1; git count-objects -H) || echo "- fork -")"
	printf "\nLIST OF USERS WITH ACCESS:   (* = write)\n"
	{
		test -n "$ACC_W" && repo --get-regexp "^.*\.role" "$ACC_W" |\
		sed -e 's/.role .*/*/'
		test -n "$ACC_R" && repo --get-regexp "^.*\.role" "$ACC_R" |\
		sed -e 's/.role .*//'
	} | sort -du | col
}

repo_ls() {
	(
		cd $DATA
		grep -Ilr --include=config '^\s*bare = true' *
		grep -Ir --include='*.git' '^\s*upstream = .*' *
	) 2>/dev/null | sed -e 's,/config$,,;s/:.*= /<-/' | col "/${1:-.}/!d"
}
role_ls() {
	user --get-regexp "^user\..*\.role$" | sed "s/^user\.[^.]*\.role//;s/,/\n/g" | col "/${1:-.}/!d"
}
user_ls() {
	user --get-regexp "^user\..*$1.*\.created$" | col
}

user() {
	git config --file "$USERS" "$@"
}
user_exists() {
	valid "${2:-$1}" "$NAME_RE$" && user user.$1.created >/dev/null
}
user_create() {
	usage user
}
user_delete() {
	user --rename-section user.$1 "deleted.$1 $(now)"
	sed -ie "/ USER=$1 /d" $KEY
}
user_addkey() {
	NAME=$1
	shift
	PUB=$*
	[ -z "$PUB" ] && {
		echo "Input the public key (ssh-rsa AAAAB3Nza... name@for.key):"
		read PUB
	}
	FP=$(echo "$PUB" | ssh-keygen -E md5 -lf- 2>/dev/null | awk '{gsub("^MD5:|:","",$2)}1')
	[ -n "$FP" ] || die "Invalid key: $PUB"
	FP=${FP#* }
	user --get-regexp "[^ ]*.key" "^${FP%% *}" >/dev/null && die "Key '${FP%% *}' exists"

	user --add user.$NAME.key "${FP%% *} $(now)"
	printf "$LINE\n" "$NAME" "$FP" "$PUB" >> $KEY
	printf "key '%s' added for '%s'\n" "$FP" "$NAME"

}
user_rmkey() {
	user --get-regexp "^user.$1.key" "^$2" >/dev/null || die "Key not exists"
	sed -ie "/ FP=$2 /d" $KEY
	user --unset "user.$1.key" "^$2"
	log "key '$2' removed"
}
user_info() {
	user --get-regexp "^user\.$1\." | sed "s/^user\.$1\.//"
}
user_set() {
	user ${4:+"--replace-all"} "$2.$3" ${4:+"$4"}
}


is_admin() {
	test -z "$FP" || valid ",$(user user.$USER.role)," ".*,admin," "Admin access denied"
}

run() {
	is_admin
	case "$1.$3" in
	repo.init|user.add)
		$1_exists "$2" && die "$1 '$2' exists"
		$1_create "$2"
		$1 "$1.$2.created" "$(now)"
		$1 "$1.$2.createdBy" "$WHO"
		log "$1 '$2' created"
		;;
	repo.|role.|user.)
		printf "List of ${1}s: (filter: ${2:-*})\n"
		$1_ls "$2"
		;;
	repo.drop|user.delete)
		$1_exists "$2" || die "$1 '$2' does not exists"
		ask "Delete $1 '$2'?" && {
			$1_delete $2
			log "$1 '$2' deleted"
		}
		;;
	repo.conf|repo.info|user.info|user.addkey|user.rmkey|user.delete|user.exists)
		$1_exists "$2" || die "$1 '$2' does not exists"
		SUB="$1_$3 $2"
		shift 3
		$SUB "$@"
		;;
	repo.default)
		repo_exists "$2" || die "Repository '$REPO' not found"
		GIT_NAMESPACE=$FORK git --git-dir "$REPO" symbolic-ref HEAD refs/heads/$4
		;;
	repo.mv|repo.fork)
		repo_exists "$4" && die "Repository '$REPO' exists"
		repo_exists "$2" || die "Repository '$REPO' not found"
		repo_$@
		;;
	user.name|user.role)
		$1_exists "$2" || die "$1 '$2' does not exists"
		$1 "$1.$2.$3" "$4"
		;;
	help.*)
		usage ${2#--yes};;
	?*)
		echo "Invalid command '$@'"
		usage ;;
	esac
}

[ $# -gt 0 ] && run "$@" && exit $?

usage

C1="ls rm init user repo help"
C2_init=""
C2_user="add delete addkey rmkey"
C2="add drop rename"

# Interactive Shell

# ANSI-C quoting $'...' is not portable
TAB=$(printf '\011')
ESC=$(printf '\033')
DEL=$(printf '\177')
PS="\033[32mdev\033[0m\033(B> "
PL=5 # PS len without control codes

# Command history
HPOS=0
HLEN=0
histAdd() {
	# Remove duplicate history entry
	for i in $(seq 0 $HLEN); do eval '[ "$H'$i'" = "$1" ] && break'; done
	[ $i -lt $HLEN ] && {
		HLEN=$((HLEN - 1))
		for i in $(seq $i $HLEN); do eval H$i=\$H$((i + 1)); done
	}
	# Add new entry
	eval H$HLEN=\$1
	HLEN=$((HLEN+1))
}
histShow() {
	[ "$HPOS" = "$HLEN" ] && [ ${#CMD} -gt 0 ] && histAdd "$CMD"
	HPOS=$((HPOS - $1))
	HPOS=$((HPOS<0?0:HPOS>HLEN?HLEN:HPOS))
	eval CMD=\$H$HPOS
	cursor 0 ${#CMD} ""
}

sub() {
	expr substr "$CMD" $(($1+1)) ${2-${#CMD}}
}

# Auto-complete
complet() {
	set -- $(sub 0 $POS)
	eval 'C=$(expr " $'$#'. ${C'$#'_'$1'-$C'$#'} " : ".* $'$#'\([a-z]* \?\)")'
}

# Cursor movement
cursor() {
	CUT=$((POS<$1?POS:$1))
	[ $CUT -ge 0 ] && CMD=$(sub 0 $((POS-CUT)))$3$(sub $POS)
	[ $CUT -lt 0 ] && CMD=$(sub 0 $POS)$3$(sub $((POS-CUT)))
	POS=$((POS + $2))
	POS=$((POS<0?0:POS>${#CMD}?${#CMD}:POS))
	printf "\r\033[K$PS$CMD\r\033[$((PL+POS))C"
}

while printf "$PS"; do
	CMD=''
	POS=0
	old_stty=$(stty -g)
	while stty -icanon -echo min 1 time 0; do
		C=$(dd bs=4 count=1 2>/dev/null)
		stty "$old_stty"
		case "$C" in
		"$ESC")    ;;
		"$ESC[A")  histShow  1     ;; # UP
		"$ESC[B")  histShow -1     ;; # DOWN
		"$ESC[C")  cursor 0  1     ;; # RIGHT
		"$ESC[D")  cursor 0 -1     ;; # LEFT
		"$ESC[3~") cursor -1 0     ;; # DELETE
		"$DEL")    cursor 1 -1     ;; # BACKSPACE
		"")
			[ "$CMD" = exit ] && exit
			printf "\n"
			[ -n "$CMD" ] && histAdd "$CMD" && (run $CMD)
			HPOS=$HLEN
			break ;;
		*)
			[ "$C" = "$TAB" ] && complet
			cursor 0 ${#C} "$C"
		esac
	done
done


