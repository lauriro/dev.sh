#!/bin/sh

. ${0%/*}/assert.sh

export CONF=$HOME/test/test.conf
CMD="$HOME/dev.sh"

echo "Test '$CMD' in '$TMP'"

# SSH_CLIENT=88.196.62.133 59858 22
# SSH_AUTH_SOCK=/tmp/ssh-phQnIi9CdW/agent.24863
# SSH_CONNECTION=88.196.62.133 59858 212.24.108.8 22

assert 0 setup-first "help --yes"
assert 0 empty-users-list "user"

assert 0 add-first-user "user test1 add"
assert 0 first-user-info "user test1"
assert 0 first-user-exists "user test1 exists"
assert 2 fail-on-adding-same-user-again "user test1 add"
assert 0 user-list-1 "user"

assert 2 second-user-does-not-exists "user test2 exists"
assert 0 add-second-user "user test2 add"

compare users.conf -after-adding-second-user

assert 0 user-list-2 "user test"

compare users.conf
compare log

