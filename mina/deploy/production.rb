# General settings
#
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)
#   rails_env    - Rails environment
set :domain, 'example.com'
set :deploy_to, '/var/www/example'
set :repository, 'git@github.com:username/repo.git'
set :branch, 'main'
set :rails_env, 'production'

# SSH settings
#
#   user - Username in the server to SSH to
#   port - SSH port number (default is 22)
#   forward_agent - use SSH forward agent
set :user, 'appdeployer'
set :port, '22'
set :forward_agent, true
