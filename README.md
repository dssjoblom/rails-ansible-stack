This project is a set of Ansible playbooks for setting up a full Rails
deployment stack (Nginx+Puma with LetsEncrypt, Sidekiq, PostgreSQL,
Redis, and other commonly used services) on Ubuntu 22.04.

The playbooks assume that Rails will be deployed with Mina, but you
could could use e.g. Capistrano or a custom script as well. For
non-Mina deployment scripts, the Rails app should be placed in
{{app_directory}}/current, and the deployer should deploy as user
admin (created by the playbooks).

Bugs
----

There is something wrong with the ruby installation, ruby, bundler
etc. are not always found when SSH:ing. This can usually be fixed
by logging out and logging in again.

Good to know
------------

UFW is not set up because of an Ubuntu bug:

 * https://bugs.launchpad.net/ubuntu/+source/ufw/+bug/1921350

 * it is highly recommended you set up a firewall as well, unless you
   have already done so.

   For example:

   ```
    sudo ufw allow 22
    sudo ufw allow 80
    sudo ufw allow 443
    sudo ufw enable
   ```

If you fork this repo, make sure you do not commit
the SSH keys that you put into envs/.

Preliminaries
-------------

On the client machine (e.g. computer used for development):

Install Python and Pip:

`sudo apt-get install python3-pip`

Install Ansible:

`pip3 install ansible`

Adding a new environment
------------------------

0. Add a DNS record for the host, for setting up SSL

   How to do this depends on your DNS provider.

1. Set up a deploy user with passwordless sudo on the host. The user
   must also have passwordless ssh login.

   Create user with sudo:

   `sudo adduser deployer`

   `sudo adduser deployer sudo`

   Change to passwordless:

   `sudo visudo`

   Add to the bottom of the file:

   `deployer  ALL=(ALL) NOPASSWD: ALL`

   Copy over ssh key for passwordless login (create the key first if necessary):

   `ssh-copy-id deployer@host`

   After you have verified that this key works for SSH login, disable
   SSH password login by modifying /etc/ssh/sshd_config:

   `PubkeyAuthentication yes`

   `UsePAM no`

   `PasswordAuthentication no`

   Remember to restart sshd:

   `sudo service sshd restart`

2. Create a copy of 'example.yaml', say 'staging.yaml', changing
   ansible_host, ansible_user and so on appropriately:

   The complete list of variables that need to be set:

   * ansible_host - ip or hostname of server
   * ansible_user -  which user ansible will be (the user set up in
     step 1, e.g. deployer)
   * env_name -  the name of the environment (e.g. 'example' or 'staging')
   * nginx_server_name - servername set in nginx.conf (e.g. www.host.com)
   * certbot_domains - comma-separated list of domains to get SSL certs for
(e.g. host.com,www.host.com)
   * admin_email - email address of server admin
   * rails_env - rails environment
   * web_concurrency - rails concurrency (puma)
   * ruby_version - ruby version (should be same as in Gemfile)
   * bundler_version - bundler version (should be same as in Gemfile.lock)
   * app_directory - directory app is deployed to (e.g. /var/www/myapp)
   * disallow_robots - if set to yes, nginx sends a robots.txt that disallows all
   * rails_db_username - username for db user that will created (you will use this in Rails database.yml)
   * rails_db_password - db password for username (this goes into
     Rails database.yml as well, will be exported to RAILS_DATABASE_PASSWORD
     environment variable)
   * timezone - timezone to set on server
   * rails_master_key - rails master key (from config/master.key, generate with e.g. rails:credentials:edit)

   Test the environment:

   `ansible -i ENVIRONMENT.yaml --private-key PATH_TO_KEY_FILE -m ping rails`

   Should produce a message similar to:

   ```
    rails | SUCCESS => {
        "ansible_facts": {
            "discovered_interpreter_python": "/usr/bin/python3"
        },
        "changed": false,
        "ping": "pong"
    }
   ```
3. Create an SSH key for the admin user for the environment:

   Locally, run:

   `ssh-keygen -t ed25519 -C "you@address.com"`

   Put the keys in envs/ENVIRONMENT/ (id_ed25519 and id_ed25519.pub are created)

   Add the key to your keyring:

   `eval "$(ssh-agent -s)"`

   `ssh-add envs/ENVIRONMENT/id_ed25519`

   NOTE: this is a key for the user that is created in the
   environment, not the key you pass to ansible-playbook
   --private-key. The latter is for the user you created in step 1.

Running the playbooks
---------------------

Run a playbook using:

`ansible-playbook -i ENVIRONMENT.yaml --private-key PATH_TO_KEY_FILE PLAYBOOK`

where PLAYBOOK is the playbook.

The playbooks are:

 - site.yml (only one currently)

The playbooks should be run before attempting to deploy Rails to the
server with e.g. Mina or Capistrano, and they should be run in the
listed order.

Installing everything on a new server
-------------------------------------

This section assumes you have configured the environment file as
specified in "Adding a new environment". If the server is not
firewalled, consider setting up UFW manually before proceeding with
Ansible. You should allow ports 22, 80 and 443 and disallow all other
ports.

After this, setup is very simple. Run the following command and wait:

`ansible-playbook -i ENVIRONMENT.yaml --private-key PATH_TO_KEY_FILE site.yml`

The script will take some time to run, from 3 to 15 minutes usually.

The environment is now properly setup, the next step is to set up app
deployment.

App deployment with Mina
------------------------

This section assumes you will use the scripts in mina/.

Copy the scripts to your Rails application's config/ directory:

`cp mina/deploy.rb PATH_TO_APP/config/deploy.rb`

`cp -R mina/deploy PATH_TO_APP/config/deploy`

Modify the config/deploy/production.rb script to suite your needs. You
can also add other environments into config/deploy,
e.g. config/deploy/staging.rb.

Next, make sure Puma is binding to a Unix domain socket (for nginx) in
config/puma.rb:

```ruby
# Setup socket + pid file
if ENV.fetch('RAILS_ENV') != 'development'
  bind 'unix:///var/run/puma/puma.sock'
  pidfile '/run/puma/puma.pid'
else
  port ENV.fetch('PORT') { 3000 }
end
```

After this, run this command once for each environment from the Rails project root:

`mina ENV setup`

Next, you need to copy over an ssh key for your Github (or other git)
repository to the host (matching URL in config/deploy/ENV.rb):

`scp PATH_TO_KEY admin@HOST:/home/admin/.ssh`

Now, set up the database and other things for the project (do this
once for each environment):

`mina ENV init_deploy`

`mina ENV setup_db`

If you can't set up the database due to "missing secret key base", make sure

`config.require_master_key = true`

is set in the Rails environment.

Now, you can deploy your project by running:

`mina ENV deploy`

Where ENV is one of the environments configured in config/deploy/*.rb.
For example, to deploy to production:

`mina production deploy`

When you make changes, simply push them to Git and run `mina ENV
deploy` again. That's it!

TODO
----

General features:

- add out-of-the-box Capistrano support
- harden ssh automatically (don't allow password login etc)
- make nginx/rails error pages configurable
- add license
- make sure letsencrypt renewal actually works
  * https://certbot.eff.org/instructions?ws=nginx&os=ubuntufocal&tab=standard
- puma service restart behavior
- puma when not using unix domain sockets
- lint the playbooks
- postgresql user/db creation
- refactor the big site.yml playbook
- fix Mina + Bundler deprecation warnings
- figure out good way of handling environment variables
- allow specification of software versions

Move the following playbook content into this Git repo as well:

- ElasticSearch setup
- Postgres WAL-G with S3
- Redis backup to S3
- Log backup to S3
