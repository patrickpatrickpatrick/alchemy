# This recipe contains Capistrano recipes for handling the uploads, ferret index and picture cache files while deploying your application.
# It also contains a ferret:rebuild_index task to rebuild the index after deploying your application.
require 'fileutils'
require 'alchemy/tasks/helpers'

include Alchemy::Tasks::Helpers

::Capistrano::Configuration.instance(:must_exist).load do

  after "deploy:setup", "alchemy:shared_folders:create"
  after "deploy:finalize_update", "alchemy:shared_folders:symlink"
  before "deploy:start", "alchemy:db:seed"

  namespace :alchemy do

    namespace :shared_folders do

      # This task creates the shared folders for uploads, picture cache and ferret index while setting up your server.
      # Call after deploy:setup like +after "deploy:setup", "alchemy:create_shared_folders"+ in your +deploy.rb+.
      desc "Creates the uploads and picture cache directory in the shared folder. Call after deploy:setup"
      task :create, :roles => :app do
        run "mkdir -p #{shared_path}/index"
        run "mkdir -p #{shared_path}/uploads/pictures"
        run "mkdir -p #{shared_path}/uploads/attachments"
        run "mkdir -p #{File.join(shared_path, 'cache', Capistrano::CLI.ui.ask("\nWhere is Alchemy CMS mounted at? ('/'): "), 'pictures')}"
      end

      # This task sets the symlinks for uploads, picture cache and ferret index folder.
      # Call after deploy:symlink like +after "deploy:symlink", "alchemy:symlink_folders"+ in your +deploy.rb+.
      desc "Sets the symlinks for uploads, picture cache and ferret index folder. Call after deploy:symlink"
      task :symlink, :roles => :app do
        run "rm -rf #{release_path}/uploads"
        run "ln -nfs #{shared_path}/uploads #{release_path}/"
        run "ln -nfs #{shared_path}/cache/* #{release_path}/public/"
        run "rm -rf #{release_path}/index"
        run "ln -nfs #{shared_path}/index #{release_path}/"
      end

    end

    desc "Upgrades production database to current Alchemy CMS version"
    task :upgrade do
      run "cd #{current_path} && #{rake} RAILS_ENV=#{fetch(:rails_env, 'production')} alchemy:upgrade"
    end

    namespace :database_yml do

      desc "Creates the database.yml file"
      task :create do
        environment      = Capistrano::CLI.ui.ask("\nPlease enter the environment (Default: #{fetch(:rails_env, 'production')})")
        environment      = fetch(:rails_env, 'production') if environment.empty?
        db_adapter       = Capistrano::CLI.ui.ask("Please enter database adapter (Options: mysql2, or postgresql. Default mysql2): ")
        db_adapter       = db_adapter.empty? ? 'mysql2' : db_adapter.gsub(/^mysql$/, 'mysql2')
        db_name          = Capistrano::CLI.ui.ask("Please enter database name: ")
        db_username      = Capistrano::CLI.ui.ask("Please enter database username: ")
        db_password      = Capistrano::CLI.password_prompt("Please enter database password: ")
        default_db_host  = db_adapter == 'mysql2' ? 'localhost' : '127.0.0.1'
        db_host          = Capistrano::CLI.ui.ask("Please enter database host (Default: #{default_db_host}): ")
        db_host          = db_host.empty? ? default_db_host : db_host
        db_config        = ERB.new <<-EOF
#{environment}:
  adapter: #{ db_adapter }
  encoding: utf8
  reconnect: false
  pool: 5
  database: #{ db_name }
  username: #{ db_username }
  password: #{ db_password }
  host: #{ db_host }
EOF
        run "mkdir -p #{shared_path}/config"
        put db_config.result, "#{shared_path}/config/database.yml"
      end

      desc "[internal] Symlinks the database.yml file from shared folder into config folder"
      task :symlink, :except => {:no_release => true} do
        run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
      end

    end

    namespace :db do

      desc "Seeds the database with essential data."
      task :seed, :roles => :db do
        run "cd #{current_path} && #{rake} RAILS_ENV=#{fetch(:rails_env, 'production')} alchemy:db:seed"
      end

      desc "Dumps the database into 'db/dumps' on the server."
      task :dump, :roles => :db do
        timestamp = Time.now.strftime('%Y-%m-%d-%H-%M')
        run "cd #{current_path} && mkdir -p db/dumps && #{rake} RAILS_ENV=#{fetch(:rails_env, 'production')} DUMP_FILENAME=db/dumps/#{timestamp}.sql alchemy:db:dump"
      end

    end

    namespace :import do

      desc "Imports all data (Pictures, attachments and the database) into your local development machine."
      task :all, :roles => [:app, :db] do
        pictures
        attachments
        database
      end

      desc "Imports the server database into your local development machine."
      task :database, :roles => [:db], :only => {:primary => true} do
        require 'spinner'
        server = find_servers_for_task(current_task).first
        spinner = Spinner.new
        print "\n"
        spinner.task("Importing the database. Please wait...") do
          system db_import_cmd(server)
        end
        spinner.spin!
      end

      desc "Imports attachments into your local machine using rsync."
      task :attachments, :roles => [:app] do
        get_files :attachments
      end

      desc "Imports pictures into your local machine using rsync."
      task :pictures, :roles => [:app] do
        get_files :pictures
      end

      def get_files(type)
        FileUtils.mkdir_p "./uploads"
        server = find_servers_for_task(current_task).first
        if server
          system "rsync --progress -rue 'ssh -p #{fetch(:port, 22)}' #{user}@#{server}:#{shared_path}/uploads/#{type} ./uploads/"
        else
          raise "No server found"
        end
      end

      def database_config
        raise "database.yml not found!" if !File.exists?("./config/database.yml")
        @database_config ||= begin
          config_file = YAML.load_file("./config/database.yml")
          if config = config_file.fetch(ENV['RAILS_ENV'] || 'development')
            config
          else
            raise "Database configuration for #{ENV['RAILS_ENV'] || 'development'} not found!"
          end
        end
      end

      def db_import_cmd(server)
        dump_cmd = "cd #{current_path} && #{rake} RAILS_ENV=#{fetch(:rails_env, 'production')} alchemy:db:dump"
        sql_stream = "ssh -p #{fetch(:port, 22)} #{user}@#{server} '#{dump_cmd}'"
        "#{sql_stream} | #{database_import_command(database_config['adapter'])} 1>/dev/null 2>&1"
      end
    end

  end

  namespace :ferret do

    # This task rebuilds the ferret index for the EssenceText and EssenceRichtext Models.
    # Call it before deploy:restart like +before "deploy:restart", "alchemy:rebuild_index"+ in your +deploy.rb+.
    # It uses the +alchemy:rebuild_index+ rake task found in +vendor/plugins/alchemy/lib/tasks+.
    desc "Rebuild the ferret index. Call before deploy:restart"
    task :rebuild_index, :roles => :app do
      run "cd #{current_path} && #{rake} RAILS_ENV=#{fetch(:rails_env, 'production')} ferret:rebuild_index"
    end

  end

end
