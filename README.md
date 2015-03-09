Gitserv
=======

Tool for hosting git repositories.


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
gitserv.sh 53317c7:Cleanup:7 months ago


```



Install
-------

```sh
# Create a user `git`
useradd -m git
# Set better shell
chsh -s /bin/dash git

    su git
    # Prepare `git` ssh config
    cd ~
    mkdir ~/.ssh
    chmod 0700 ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod 0600 ~/.ssh/authorized_keys
    # Get sshd wrapper
    wget -O gitserv.sh https://raw.github.com/lauriro/gitserv/master/gitserv.sh
    chmod +x gitserv.sh

    # Make initial config
    ./gitserv.sh user richard add
    ./gitserv.sh user richard key 'ssh-rsa AAAAB3NzaC1yc2E...50i8Q== richard@example.com'
    ./gitserv.sh user richard group 'all,admin'

Conf
----

```
# Override logger
log() {
	logger -t gitserv -p ${2-"info"} "${SSH_CLIENT%% *} $USER: $1 -- $SSH_ORIGINAL_COMMAND"
}
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

Copyright (c) 2012 Lauri Rooden <lauri@rooden.ee>  
[The MIT License](http://lauri.rooden.ee/mit-license.txt)

