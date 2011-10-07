#!/bin/sh

# user and permissions are passed from authorized_keys

LOG=/home/lauri/gitserv.log
echo "$(date -u +'%Y-%m-%d %H:%M:%S') $USER@$ACC $*" >> $LOG
#env >> $LOG

case $1 in
  # git push
  git-receive-pack)
        echo "Tere $USER!" >&2
        git shell -c "$*"
  ;;
  # git pull
  git-upload-pack)
        echo "Tere $USER!" >&2
        git shell -c "$*"

  ;;
  *)
        echo "ssh not allowed" >&2
        exit 0
  ;;
esac

