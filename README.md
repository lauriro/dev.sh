https://github.com/bkuhlmann/git-cop
https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
https://github.com/agis/git-style-guide

https://github.com/agis/git-style-guide

Fix
Add
Update
Remove
Refactor
Replace

Gitserv
=======

Hosting a git server with git-shell

Install
-------

```sh
# Create a user as root or with sudo
useradd --create-home --skel /dev/null --shell /bin/dash git
# Clone gitserv to newly created user home directory
su git
git clone https://github.com/lauriro/gitserv.git $HOME
# Setup .ssh dir and permissions
./gitserv setup
# Add first git user
./gitserv user add john
./gitserv user addkey john
```

Now you can continue with ssh and newly created user

```sh
ssh git@gitserv.host
```

In most cases this should be sufficient.

Advanced Configuration
----------------------

`/etc/gitserv.conf` file can be used.

Defaults

```sh
ROOT=$HOME/repo
USER_RE='[a-z][-a-z0-9]\{1,16\}[a-z0-9]$'
REPO_RE='[-a-z0-9_.]\{0,30\}.git$'
LINE='command="env USER=%s %s",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty %s\n'
LOGS=$HOME/logs/gitserv.log
```

It is possible to override logger by adding to conf file

```sh
log() {
	logger -t gitserv -p ${2-"info"} "${SSH_CLIENT%% *} $USER: $1 -- $CMD"
}
```


### Notes


```
$ git for-each-ref --sort=-committerdate --format='%(refname:short) Updated %(committerdate:relative) by %(committername)' refs/heads/
master Updated 7 months ago by Lauri Rooden


# get the tracking-branch name
tracking_branch=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD))
# creates global variables $1 and $2 based on left vs. right tracking
# inspired by @adam_spiers
set -- $(git rev-list --left-right --count $tracking_branch...HEAD)
behind=$1
ahead=$2

# In modern versions of git, @{u} points to the upstream of the current branch, if one is set.
# So to count how many commits you are behind the remote tracking branch:
git rev-list HEAD..@{u} | wc -l
# And to see how far you are ahead of the remote, just switch the order:
git rev-list @{u}..HEAD | wc -l
# For a more human-readable summary, you could ask for a log instead:
git log --pretty=oneline @{u}..HEAD


$ git ls-tree -r --name-only HEAD | while read filename; do   echo "$filename $(git log -1 --format="%h:%s:%ar" -- $filename)"; done
README.md 65162b1:Update Readme:1 year, 5 months ago
gitserv 53317c7:Cleanup:7 months ago


```



Usage
-----

    $ ssh git@localhost help
    Example usage:
    
      $ ssh git@host repo
      $ ssh git@host repo test.git init
      $ ssh git@host repo test.git config access.read all
      $ ssh git@host repo test.git config access.write admin,richard
      $ ssh git@host repo test.git config access.write.devel all
      $ ssh git@host repo test.git config access.tag richard
      $ ssh git@host repo test.git config branch.master.denyDeletes true
      $ ssh git@host repo test.git config branch.master.mergeoptions "--ff-only"
      $ ssh git@host repo test.git config branch.devel.mergeoptions "--no-ff"
      $ ssh git@host repo test.git config tags.denyOverwrite true
      $ ssh git@host repo test.git describe "My cool repo"
      $ ssh git@host repo test.git fork new_repo.git
      $ ssh git@host repo test.git drop
      $ ssh git@host user
      $ ssh git@host user richard
      $ ssh git@host user richard add
      $ ssh git@host user richard key 'ssh-rsa AAAAB3N...50i8Q==' richard@example.com
      $ ssh git@host user richard group all,admin
      $ ssh git@host user richard del


### Licence

Copyright (c) 2011-2015 Lauri Rooden <lauri@rooden.ee>  
[The MIT License](http://lauri.rooden.ee/mit-license.txt)


