#!/bin/bash

export BIN=$(cd ${0%/*}/..;pwd)
export CONF=$BIN/test/test.conf
CMD="$BIN/dev.sh"

. ${0%/*}/assert.sh


echo "Test '$CMD' in '$TMP'"

# SSH_CLIENT=88.196.62.133 59858 22
# SSH_AUTH_SOCK=/tmp/ssh-phQnIi9CdW/agent.24863
# SSH_CONNECTION=88.196.62.133 59858 212.24.108.8 22

PUB1="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQCuixTmHBevg4SSghYLja3pyO1pVMy194EgtiXV59trbBOJoXSasNIssXhwi8k3R9sJQJqzQTnh7UwYKM+AvWdXFupKfr1KoPo5k2W+28Q1EpzLr59fvRrs7k2Y8sZHlCpklZL3LPFHSFReL4p7x3r8UX2/37ZsyDtIBE7pH3zvwQ== weak@rsa.key"


Test "setup" help --yes

runExamples() {
	sed -n "/^#$1-     git> /s///p" $CMD |\
	sed \
	-e 's,<ssh-public-key>,"AAAAB3NzaC1yc2EAAAADAQABAAAAgQCuixTmHBevg4SSghYLja3pyO1pVMy194EgtiXV59trbBOJoXSasNIssXhwi8k3R9sJQJqzQTnh7UwYKM+AvWdXFupKfr1KoPo5k2W+28Q1EpzLr59fvRrs7k2Y8sZHlCpklZL3LPFHSFReL4p7x3r8UX2/37ZsyDtIBE7pH3zvwQ== weak@rsa.key",' \
	-e 's,<fingerprint>,8c65c5fcca5d8847674889b4b34312bf,' \
	> $TMP/usage.tmp

	cat $TMP/usage.tmp
	while read line; do
		It "runs $1 example" $line
	done < $TMP/usage.tmp
}
# run user examples
#runExamples user
#Check users.conf



It "has initial users list empty" user
It "should add first user" user test1 add
It "should add user name" user test1 name "First User"
It "should set user roles" user test1 role admin,web
It "shows first user info" user test1 info
It "shows first user exists" user test1 exists
It "lists first user" user

Fail 2 "on adding same user again" user test1 add
Check users.conf

Fail 2 "on checking non-existing user" user test-2 exists
It "should add second user" user test-2 add
It "lists both users" user
Check users.conf


It "Add key to first user" user test1 addkey $PUB1
Check users.conf
Check authorized_keys

Fail 1 "to add same key again" user test-2 addkey $PUB1
Fail 1 "on removing key from wrong user" user test-2 rmkey 8c65c5fcca5d8847674889b4b34312bf
It "should remove key" user test1 rmkey 8c65c5fcca5d8847674889b4b34312bf
Check users.conf

for u in $(seq -w 1 100); do
	It "adds user many$u" user many$u add
done
Check users.conf

It "shows first 100 users" user
It "filter users" user y02


It "has initial repo list empty" repo
It "should init first repo" repo test1 init
It "should test that repo exists" repo test1 exists
It "should test that repo exists" repo test1.git exists
It "should set read access" repo test1.git set access.read all
It "should set write access" repo test1.git set access.write admin,manager
It "should show repo info" repo test1.git info

Fail 1 "on adding same repo again" repo test1 init
Fail 1 "on checking non-existing repo" repo test2 exists
Fail 1 "on checking non-existing repo" repo test2.git exists





Check log


