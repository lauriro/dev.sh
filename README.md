Install
-------

- Create a user `git`
- Prepare `git` ssh config

        $ cd /home/git/
        $ mkdir .ssh
        $ chmod 0700 ~/.ssh
        $ touch ~/.ssh/authorized_keys
        $ chmod 0600 ~/.ssh/authorized_keys

- Get sshd wraper

        $ wget -O gitserv.sh https://raw.github.com/lauriro/gitserv.sh/devel/gitserv.sh
        $ chmod +x gitserv.sh

- Make initial config

        $ ./gitserv.sh user richard add 'ssh-rsa AAAAB3NzaC1yc2E...50i8Q== richard@example.com'
        $ ./gitserv.sh user richard group 'all,admin'


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
      $ ssh git@host user richard add 'sh-rsa AAAAB3N...50i8Q==' user@example.com
      $ ssh git@host user richard key 'sh-rsa AAAAB3N...50i8Q==' user@example.com
      $ ssh git@host user richard group all,admin
      $ ssh git@host user richard del


### Licence

Copyright (c) 2012 Lauri Rooden &lt;lauri@rooden.ee&gt;  
[The MIT License](http://lauri.rooden.ee/mit-license.txt)

