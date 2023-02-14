
dev.sh
======

Host a development server


Install
-------

```sh
# Create a user as root or with sudo
useradd --create-home --skel /dev/null --home-dir /home/git --shell /bin/dash git
# Clone dev.sh to newly created user home directory
su git
git clone git://github.com/lauriro/dev.sh.git $HOME
# Setup .ssh dir and permissions
./dev.sh
# Add first git user
./dev.sh user john add
./dev.sh user john addkey
```

Now you can continue with ssh and newly created user

```sh
ssh git@dev.sh.host
```

In most cases this should be sufficient.

Advanced Configuration
----------------------


Defaults

```sh
ROOT=$HOME/repo
USER_RE='[a-z][-a-z0-9]\{1,16\}[a-z0-9]$'
REPO_RE='[-a-z0-9_.]\{0,30\}.git$'
LINE='command="env USER=%s %s",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty %s\n'
LOGS=$HOME/logs/dev.sh.log
```

It is possible to override logger by adding to conf file

```sh
log() {
	logger -t dev.sh -p ${2-"info"} "${SSH_CLIENT%% *} $USER: $1 -- $CMD"
}
```

```sh
# Watch files for changes and rerun tests
while :;do inotifywait -q -e modify dev.sh test/*.sh;./test/test.sh; done
```



Usage
-----

$ ssh git@localhost help

```
git> repo
git> repo test.git init
git> repo test.git config access.read all
git> repo test.git config access.write admin,richard
git> repo test.git config access.write.devel all
git> repo test.git config access.tag richard
git> repo test.git config branch.master.denyDeletes true
git> repo test.git config branch.master.mergeoptions "--ff-only"
git> repo test.git config branch.devel.mergeoptions "--no-ff"
git> repo test.git config tags.denyOverwrite true
git> repo test.git describe "My cool repo"
git> repo test.git mv new-repo.git
git> repo test.git fork new-repo.git
git> repo test.git sta

git> user john
git> user john add
git> user john addkey <ssh-public-key>
git> user john rmkey john fingerprint
git> user john group admin
git> user john name "John Smith"
git> user john delete
```


### Licence

Copyright (c) 2011-2022 Lauri Rooden <lauri@rooden.ee>  
[The MIT License](https://lauri.rooden.ee/mit-license.txt)


For a simple local test, you can use git-remote-ext:
git clone ext::'git --namespace=foo %s /tmp/prefixed.git'

