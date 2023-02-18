This project is a set of Ansible playbooks for setting up a full Rails
deployment stack (Nginx+Puma with LetsEncrypt, Sidekiq, PostgreSQL,
Redis, and other commonly used services) on Ubuntu 22.04.

The playbooks assume that Rails will be deployed with Mina, but you
could could use e.g. Capistrano or a custom script as well. For
non-Mina deployment scripts, the Rails app should be placed in
{{app_directory}}/current, and the deployer should deploy as user
admin (created by the playbooks).

Installing with Ansible
-----------------------

When preparing to deploy to a new server, as a rule of thumb, creating
a new environment for a new server takes about 15 minutes, depending
on experience. The installation process itself will usually take at
least 1 hour, depending on network and cpu speed, as it involves
installing many packages, some of which are compiled. In total,
reserve 1+ hour, preferably 2 hours for an install from scratch.

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

1. Create a copy of 'example.yaml', say 'staging.yaml', changing
   ansible_host, ansible_user and so on appropriately:

   The complete list of variables that need to be set:

   * ansible_host - ip or hostname of server
   * ansible_user -  which user ansible will be (must be a sudoer)
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
   * rails_db_password - db password for username (this goes into Rails database.yml as well)

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
2. Create an SSH key for the admin user for the environment:

   Locally, run:

   `ssh-keygen -t rsa -b 4096 -C "you@address.com"`

   Put the key in envs/ENVIRONMENT/ENVIRONMENT.key (ENVIRONMENT.key.pub is also created)

   Add the key to your keyring:

   `eval "$(ssh-agent -s)"`

   `ssh-add -K envs/ENVIRONMENT/ENVIRONMENT.key`

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

`ansible-playbook -i ENVIRONMENT.yaml --private-key PATH_TO_SSH_KEY site.yml`

The environment is now properly setup, the next step is to configure
app deployment, which is beyond the scope of this project. If you have
an existing Mina deploy.rb, you should be able to deploy immediately.

TODO
----

General features:

- add out-of-the-box Capistrano support
- harden ssh automatically (don't allow password login etc)
- make nginx/rails error pages configurable
- add license
- make sure letsencrypt renewal actually works
- puma service restart behavior
- puma when not using unix domain sockets
- lint the playbooks
- postgresql user/db creation

Move the following playbook content into this Git repo as well:

- ElasticSearch setup
- Postgres WAL-G with S3
- Redis backup to S3
- Log backup to S3
