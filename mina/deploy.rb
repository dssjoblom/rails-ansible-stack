require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
require 'mina/rvm'    # for rvm support. (https://rvm.io)
require 'mina/multistage'

Dir.glob('config/deploy/*.rb').each do |file|
  require_relative "deploy/#{File.basename(file)}"
end

# Shared dirs and files will be symlinked into the app-folder by the
# 'deploy:link_shared_paths' step.

# Some plugins already add folders to shared_dirs like `mina/rails`
# add `public/assets`, `vendor/bundle` and many more run `mina -d` to
# see all folders and files already included in `shared_dirs` and
# `shared_files`.
set :shared_dirs, fetch(:shared_dirs, []).push('node_modules',
                                               'public/assets',
                                               'public/packs',
                                               'public/vite',
                                               'log',
                                               'tmp/pids',
                                               'tmp/cache',
                                               'tmp/sockets')

if File.exist?('config/secrets.yml')
  set :shared_files, fetch(:shared_files, []).push('config/secrets.yml')
end

# This task is the environment that is loaded for all remote run
# commands, such as `mina deploy` or `mina rake`.
task :remote_environment do
  invoke :'rvm:use', 'ruby-3.1.3'
end

# Put any custom commands you need to run at setup
# All paths in `shared_dirs` and `shared_paths` will be created on their own.
task :setup do
  # Nothing
end

namespace :puma do
  desc 'Start puma'
  task start: :remote_environment do
    command 'sudo service puma start'
  end

  desc 'Stop puma'
  task stop: :remote_environment do
    command 'sudo service puma stop'
  rescue StandardError => e
    puts "Failed to stop puma: #{e}\n."
  end

  desc 'Restart puma'
  task restart: :remote_environment do
    command 'sudo service puma stop'
    command 'sudo service puma start'
  rescue StandardError => e
    puts "Failed to restart puma: #{e}\nAssuming not started."
  end
end

namespace :nginx do
  desc 'Restart nginx'

  task restart: :remote_environment do
    command 'sudo service nginx restart'
  end
end

task :fix_secrets do
  if File.exist?('config/secrets.yml')
    # Don't know why this doesn't work automatically
    command "cp #{fetch(:deploy_to)}/shared/config/secrets.yml #{fetch(:deploy_to)}/current/config/secrets.yml"
  end
end

task :upload_secrets do
  run :local do
    if File.exist?('config/secrets.yml')
      command "scp config/secrets.yml #{fetch(:user)}@#{fetch(:domain)}:#{fetch(:deploy_to)}/shared/config/secrets.yml"
    end
  end
end

task :restart_sidekiq do
  command 'sudo service sidekiq restart'
end

task :compile_assets do
  command 'bundle exec rake assets:precompile'
end

task :setup_db_task do
  command 'bundle exec rake db:setup'
end

task :reindex_all do
  deploy do
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'deploy:cleanup'
  end
end

# Call this after initial call of mina setup
task :init_deploy do
  invoke :'git:ensure_pushed'

  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'deploy:cleanup'
  end
end

# Call this after initial call of mina init_deploy
task :setup_db do
  invoke :'git:ensure_pushed'

  deploy do
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :setup_db_task
    invoke :'deploy:cleanup'
  end
end

task install_js: :remote_environment do
  command 'yarn install'
end

task tmp_cache_clear: :remote_environment do
  command 'bundle exec rake tmp:cache:clear'
end

# Store our current revision so that it is visible when on-site
set :deployed_revision, %x[git rev-parse #{fetch(:branch)}].strip

desc 'Deploys the current version to the server.'
task :deploy do
  invoke :'git:ensure_pushed'

  deploy do
    # Put things that will set up an empty directory into a fully
    # set-up instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :fix_secrets
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :tmp_cache_clear
    invoke :install_js
    invoke :compile_assets
    invoke :'deploy:cleanup'

    on :launch do
      command "echo '#{fetch(:deployed_revision)}' > #{fetch(:current_path)}/REVISION"
      command "echo '#{fetch(:branch)}' >> #{fetch(:current_path)}/REVISION"

      in_path(fetch(:current_path)) do
        invoke :restart_sidekiq
        invoke :'puma:restart'
        invoke :'nginx:restart'
      end
    end
  end
end
