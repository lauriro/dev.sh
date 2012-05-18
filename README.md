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
$ /home/git/gitserv.sh user richard add 'ssh-rsa AAAAB3NzaC1yc2E...50i8Q== richard@example.com'
$ /home/git/gitserv.sh user richard group 'all,admin'
$ exit
```

### Manage users

```
# List of users
$ ssh git@repo.example.com user
# Show richard's permissions
$ ssh git@repo.example.com user richard
$ ssh git@repo.example.com user richard add 'sh-rsa AAAAB3N...50i8Q==' user@example.com
$ ssh git@repo.example.com user richard group all,admin
$ ssh git@repo.example.com user richard key 'sh-rsa AAAAB3N...50i8Q==' user@example.com
$ ssh git@repo.example.com user richard del
```

### Manage repos

```
$ ssh git@repo.example.com repo test.git add
$ ssh git@repo.example.com repo test.git config access.read all
$ ssh git@repo.example.com repo test.git config access.write admin,richard
$ ssh git@repo.example.com repo test.git config access.write.devel all
$ ssh git@repo.example.com repo test.git config access.tag richard
$ ssh git@repo.example.com repo test.git config branch.master.mergeoptions "--ff-only"
$ ssh git@repo.example.com repo test.git config branch.master.denyDeletes true
$ ssh git@repo.example.com repo test.git config branch.devel.mergeoptions "--no-ff"
$ ssh git@repo.example.com repo test.git config tags.denyOverwrite true
$ ssh git@repo.example.com repo test.git config --unset tags.denyOverwrite
$ ssh git@repo.example.com repo test.git del

```


