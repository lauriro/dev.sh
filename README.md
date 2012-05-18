Set Up A Git Server
-------------------

```
$ sudo adduser git
$ su git
$ cd /home/git/
$ mkdir .ssh
$ chmod 700 ~/.ssh
$ touch ~/.ssh/authorized_keys
$ chmod 600 ~/.ssh/authorized_keys
$ wget --no-check-certificate https://raw.github.com/lauriro/gitserv.sh/devel/gitserv.sh
$ chmod +x gitserv.sh
# Use full path here!
$ /home/git/gitserv.sh user add richard 'ssh-rsa AAAAB3NzaC1yc2E...50i8Q== richard@example.com'
$ /home/git/gitserv.sh user group richard 'all,admin'
$ exit
```

### Manage users

```
# List of users
$ ssh git@repo.example.com user
# Show richard's permissions
$ ssh git@repo.example.com user show richard
$ ssh git@repo.example.com user add richard 'sh-rsa AAAAB3N...50i8Q==' user@example.com
$ ssh git@repo.example.com user group richard all,admin
$ ssh git@repo.example.com user key richard 'sh-rsa AAAAB3N...50i8Q==' user@example.com
$ ssh git@repo.example.com user del richard
```

### Manage repos

```
$ ssh git@repo.example.com repo add test.git
$ ssh git@repo.example.com repo config test.git access.read all
$ ssh git@repo.example.com repo config test.git access.write admin,richard
$ ssh git@repo.example.com repo config test.git access.write.devel all
$ ssh git@repo.example.com repo config test.git access.tag richard
$ ssh git@repo.example.com repo config test.git branch.master.mergeoptions "--ff-only"
$ ssh git@repo.example.com repo config test.git branch.master.denyDeletes true
$ ssh git@repo.example.com repo config test.git branch.devel.mergeoptions "--no-ff"
$ ssh git@repo.example.com repo config test.git tags.denyOverwrite true
$ ssh git@repo.example.com repo config test.git --unset tags.denyOverwrite
$ ssh git@repo.example.com repo del test.git

```


