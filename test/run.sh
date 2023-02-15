#!/bin/bash

. ${0%/*}/assert.sh

export CONF=$HOME/test/test.conf
CMD="$HOME/dev.sh"

echo "Test '$CMD' in '$TMP'"

# SSH_CLIENT=88.196.62.133 59858 22
# SSH_AUTH_SOCK=/tmp/ssh-phQnIi9CdW/agent.24863
# SSH_CONNECTION=88.196.62.133 59858 212.24.108.8 22

Test "setup" help --yes
It "has initial users list empty" user
It "should add first user" user test1 add
Check users.conf
It "shows first user info" user test1 info
It "shows first user exists" user test1 exists
Fail 2 "on adding same user again" user test1 add
It "User list 1" user

Fail 2 "on checking non-existing user" user test-2 exists
It "Add second user" user test-2 add

Check users.conf

It "User list 2" user test

PUB1="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQCuixTmHBevg4SSghYLja3pyO1pVMy194EgtiXV59trbBOJoXSasNIssXhwi8k3R9sJQJqzQTnh7UwYKM+AvWdXFupKfr1KoPo5k2W+28Q1EpzLr59fvRrs7k2Y8sZHlCpklZL3LPFHSFReL4p7x3r8UX2/37ZsyDtIBE7pH3zvwQ== weak@rsa.key"

It "Add key to first user" user test1 addkey $PUB1

Check users.conf

Fail 1 "add same key again" user test-2 addkey $PUB1
Fail 1 "on removing key from wrong user" user test-2 rmkey 8c65c5fcca5d8847674889b4b34312bf

It "should remove key" user test1 rmkey 8c65c5fcca5d8847674889b4b34312bf
Check users.conf


Check log

