require 'vlad'

class String
  def cleanup
    if ENV['FULL'] then
      gsub(/\s+/, ' ').strip # TODO: make this prettier
    else
      self[/\A.*?\./]
    end
  end
end

namespace :vlad do
  desc "show the vlad setup"
  task :debug do
    y Vlad.instance
  end

  desc "Prepares one or more servers for deployment. Before you can
    use any of the deployment tasks with your project, you will need
    to make sure all of your servers have been prepared with 'rake
    setup'. It is safe to run this task on servers that have already
    been set up; it will not destroy any deployed revisions or data.".cleanup

  remote_task :setup do
    dirs = [deploy_to, releases_path, shared_path]
    dirs += %w(system log pids).map { |d| File.join(shared_path, d) }
    run "umask 02 && mkdir -p #{dirs.join(' ')}"
  end

  desc "Invoke a single command on the remote servers. This is useful
  for performing one-off commands that may not require a full task to
  be written for them.  Simply specify the command to execute via the
  COMMAND environment variable.  To execute the command only on
  certain roles, specify the ROLES environment variable as a
  comma-delimited list of role names.

    $ rake vlad:invoke COMMAND='uptime'".cleanup

  remote_task :invoke do
    command = ENV["COMMAND"]
    abort "Please specify a command to execute on the remote servers (via the COMMAND environment variable)" unless command
    puts run(command)
  end

  desc "Start the application servers. This will attempt to invoke a
    script in your application called 'script/spin', which must know
    how to start your application listeners. For Rails applications,
    you might just have that script invoke 'script/process/spawner'
    with the appropriate arguments.

    By default, the script will be executed via sudo as the 'app' user. If
    you wish to run it as a different user, set the :runner variable to
    that user. If you are in an environment where you can't use sudo, set
    the :use_sudo variable to false.".cleanup

  remote_task :start, :roles => :app do
    # TODO: extend run to automatically handle sudo and user options
    run "cd #{current_path} && nohup script/spin"
  end

  desc "Stop the application servers. This will call script/process/reaper for
    both the spawner process, and all of the application processes it has
    spawned. As such, it is fairly Rails specific and may need to be
    overridden for other systems.

    By default, the script will be executed via sudo as the 'app' user. If
    you wish to run it as a different user, set the :runner variable to
    that user. If you are in an environment where you can't use sudo, set
    the :use_sudo variable to false.".cleanup

  remote_task :stop, :roles => :app do
    run("#{current_path}/script/process/reaper -a kill -r dispatch.spawner.pid " +
        "|| #{current_path}/script/process/reaper -a kill")
  end

end # namespace vlad

  # set :scm, :subversion
  # set :deploy_via, :checkout

  # set(:deploy_to) { "/u/apps/#{application}" }
  # set(:revision)  { source.head }

  # set(:source)            { Capistrano::Deploy::SCM.new(scm, self) }
  # set(:real_revision)     { source.local.query_revision(revision) { |cmd| with_env("LC_ALL", "C") { '#{cmd}' } } }

  # set(:strategy)          { Capistrano::Deploy::Strategy.new(deploy_via, self) }

  # set(:release_name)      { set :deploy_timestamped, true; Time.now.utc.strftime("%Y%m%d%H%M%S") }
  # set(:release_path)      { File.join(releases_path, release_name) }

  # set(:releases)          { capture("ls -x #{releases_path}").split.sort }
  # set(:current_release)   { File.join(releases_path, releases.last) }
  # set(:previous_release)  { File.join(releases_path, releases[-2]) }

  # set(:current_revision)  { capture("cat #{current_path}/REVISION").chomp }
  # set(:latest_revision)   { capture("cat #{current_release}/REVISION").chomp }
  # set(:previous_revision) { capture("cat #{previous_release}/REVISION").chomp }

  # set(:run_method)        { fetch(:use_sudo, true) ? :sudo : :run }

  # set(:latest_release) { exists?(:deploy_timestamped) ? release_path : current_release }

############################################################

# namespace :deploy do
#   desc <<-DESC
#     Deploys your project. This calls both 'update' and 'restart'. Note that
#     this will generally only work for applications that have already been deployed
#     once. For a "cold" deploy, you'll want to take a look at the 'deploy:cold'
#     task, which handles the cold start specifically.
#   DESC
#   task :default do
#     update
#     restart
#   end

#   desc <<-DESC
#     Copies your project and updates the symlink. It does this in a
#     transaction, so that if either 'update_code' or 'symlink' fail, all
#     changes made to the remote servers will be rolled back, leaving your
#     system in the same state it was in before 'update' was invoked. Usually,
#     you will want to call 'deploy' instead of 'update', but 'update' can be
#     handy if you want to deploy, but not immediately restart your application.
#   DESC
#   task :update do
#     transaction do
#       update_code
#       symlink
#     end
#   end

#   desc <<-DESC
#     Copies your project to the remote servers. This is the first stage
#     of any deployment; moving your updated code and assets to the deployment
#     servers. You will rarely call this task directly, however; instead, you
#     should call the 'deploy' task (to do a complete deploy) or the 'update'
#     task (if you want to perform the 'restart' task separately).

#     You will need to make sure you set the :scm variable to the source
#     control software you are using (it defaults to :subversion), and the
#     :deploy_via variable to the strategy you want to use to deploy (it
#     defaults to :checkout).
#   DESC
#   task :update_code, :except => { :no_release => true } do
#     on_rollback { run "rm -rf #{release_path}; true" }
#     strategy.deploy!
#     finalize_update
#   end

#   desc <<-DESC
#     [internal] Touches up the released code. This is called by update_code
#     after the basic deploy finishes. It assumes a Rails project was deployed,
#     so if you are deploying something else, you may want to override this
#     task with your own environment's requirements.

#     This task will make the release group-writable (if the :group_writable
#     variable is set to true, which is the default). It will then set up
#     symlinks to the shared directory for the log, system, and tmp/pids
#     directories, and will lastly touch all assets in public/images,
#     public/stylesheets, and public/javascripts so that the times are
#     consistent (so that asset timestamping works).
#   DESC
#   task :finalize_update, :except => { :no_release => true } do
#     run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)

#     # mkdir -p is making sure that the directories are there for some SCM's that don't
#     # save empty folders
#     run <<-CMD
#       rm -rf #{latest_release}/log #{latest_release}/public/system #{latest_release}/tmp/pids &&
#       mkdir -p #{latest_release}/public &&
#       mkdir -p #{latest_release}/tmp &&
#       ln -s #{shared_path}/log #{latest_release}/log &&
#       ln -s #{shared_path}/system #{latest_release}/public/system &&
#       ln -s #{shared_path}/pids #{latest_release}/tmp/pids
#     CMD

#     stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
#     asset_paths = %w(images stylesheets javascripts).map { |p| "#{latest_release}/public/#{p}" }.join(" ")
#     run "find #{asset_paths} -exec touch -t #{stamp} {} ';'; true", :env => { "TZ" => "UTC" }
#   end

#   desc <<-DESC
#     Updates the symlink to the most recently deployed version. Capistrano works
#     by putting each new release of your application in its own directory. When
#     you deploy a new version, this task's job is to update the 'current' symlink
#     to point at the new version. You will rarely need to call this task
#     directly; instead, use the 'deploy' task (which performs a complete
#     deploy, including 'restart') or the 'update' task (which does everything
#     except 'restart').
#   DESC
#   task :symlink, :except => { :no_release => true } do
#     on_rollback { run "rm -f #{current_path}; ln -s #{previous_release} #{current_path}; true" }
#     run "rm -f #{current_path} && ln -s #{latest_release} #{current_path}"
#   end

#   desc <<-DESC
#     Copy files to the currently deployed version. This is useful for updating
#     files piecemeal, such as when you need to quickly deploy only a single
#     file. Some files, such as updated templates, images, or stylesheets,
#     might not require a full deploy, and especially in emergency situations
#     it can be handy to just push the updates to production, quickly.

#     To use this task, specify the files and directories you want to copy as a
#     comma-delimited list in the FILES environment variable. All directories
#     will be processed recursively, with all files being pushed to the
#     deployment servers. Any file or directory starting with a '.' character
#     will be ignored.

#       $ cap deploy:upload FILES=templates,controller.rb
#   DESC
#   task :upload, :except => { :no_release => true } do
#     files = (ENV["FILES"] || "").
#       split(",").
#       map { |f| f.strip!; File.directory?(f) ? Dir["#{f}/**/*"] : f }.
#       flatten.
#       reject { |f| File.directory?(f) || File.basename(f)[0] == ?. }

#     abort "Please specify at least one file to update (via the FILES environment variable)" if files.empty?

#     files.each do |file|
#       put File.read(file), File.join(current_path, file)
#     end
#   end

#   desc <<-DESC
#     Restarts your application. This works by calling the script/process/reaper
#     script under the current path. By default, this will be invoked via sudo,
#     but if you are in an environment where sudo is not an option, or is not
#     allowed, you can indicate that restarts should use 'run' instead by
#     setting the 'use_sudo' variable to false:

#       set :use_sudo, false
#   DESC
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     invoke_command "#{current_path}/script/process/reaper", :via => run_method
#   end

#   desc <<-DESC
#     Rolls back to the previously deployed version. The 'current' symlink will
#     be updated to point at the previously deployed version, and then the
#     current release will be removed from the servers. You'll generally want
#     to call 'rollback' instead, as it performs a 'restart' as well.
#   DESC
#   task :rollback_code, :except => { :no_release => true } do
#     if releases.length < 2
#       abort "could not rollback the code because there is no prior release"
#     else
#       run "rm #{current_path}; ln -s #{previous_release} #{current_path} && rm -rf #{current_release}"
#     end
#   end

#   desc <<-DESC
#     Rolls back to a previous version and restarts. This is handy if you ever
#     discover that you've deployed a lemon; 'cap rollback' and you're right
#     back where you were, on the previously deployed version.
#   DESC
#   task :rollback do
#     rollback_code
#     restart
#   end

#   desc <<-DESC
#     Run the migrate rake task. By default, it runs this in most recently
#     deployed version of the app. However, you can specify a different release
#     via the migrate_target variable, which must be one of :latest (for the
#     default behavior), or :current (for the release indicated by the
#     'current' symlink). Strings will work for those values instead of symbols,
#     too. You can also specify additional environment variables to pass to rake
#     via the migrate_env variable. Finally, you can specify the full path to the
#     rake executable by setting the rake variable. The defaults are:

#       set :rake,           "rake"
#       set :rails_env,      "production"
#       set :migrate_env,    ""
#       set :migrate_target, :latest
#   DESC
#   task :migrate, :roles => :db, :only => { :primary => true } do
#     rake = fetch(:rake, "rake")
#     rails_env = fetch(:rails_env, "production")
#     migrate_env = fetch(:migrate_env, "")
#     migrate_target = fetch(:migrate_target, :latest)

#     directory = case migrate_target.to_sym
#       when :current then current_path
#       when :latest  then current_release
#       else raise ArgumentError, "unknown migration target #{migrate_target.inspect}"
#       end

#     run "cd #{directory}; #{rake} RAILS_ENV=#{rails_env} #{migrate_env} db:migrate"
#   end

#   desc <<-DESC
#     Deploy and run pending migrations. This will work similarly to the
#     'deploy' task, but will also run any pending migrations (via the
#     'deploy:migrate' task) prior to updating the symlink. Note that the
#     update in this case it is not atomic, and transactions are not used,
#     because migrations are not guaranteed to be reversible.
#   DESC
#   task :migrations do
#     set :migrate_target, :latest
#     update_code
#     migrate
#     symlink
#     restart
#   end

#   desc <<-DESC
#     Clean up old releases. By default, the last 5 releases are kept on each
#     server (though you can change this with the keep_releases variable). All
#     other deployed revisions are removed from the servers. By default, this
#     will use sudo to clean up the old releases, but if sudo is not available
#     for your environment, set the :use_sudo variable to false instead.
#   DESC
#   task :cleanup, :except => { :no_release => true } do
#     count = fetch(:keep_releases, 5).to_i
#     if count >= releases.length
#       logger.important "no old releases to clean up"
#     else
#       logger.info "keeping #{count} of #{releases.length} deployed releases"

#       directories = (releases - releases.last(count)).map { |release|
#         File.join(releases_path, release) }.join(" ")

#       invoke_command "rm -rf #{directories}", :via => run_method
#     end
#   end

#   desc <<-DESC
#     Test deployment dependencies. Checks things like directory permissions,
#     necessary utilities, and so forth, reporting on the things that appear to
#     be incorrect or missing. This is good for making sure a deploy has a
#     chance of working before you actually run 'cap deploy'.

#     You can define your own dependencies, as well, using the 'depend' method:

#       depend :remote, :gem, "tzinfo", ">=0.3.3"
#       depend :local, :command, "svn"
#       depend :remote, :directory, "/u/depot/files"
#   DESC
#   task :check, :except => { :no_release => true } do
#     dependencies = strategy.check!

#     other = fetch(:dependencies, {})
#     other.each do |location, types|
#       types.each do |type, calls|
#         if type == :gem
#           dependencies.send(location).command(fetch(:gem_command, "gem")).or("'gem' command could not be found. Try setting :gem_command")
#         end

#         calls.each do |args|
#           dependencies.send(location).send(type, *args)
#         end
#       end
#     end

#     if dependencies.pass?
#       puts "You appear to have all necessary dependencies installed"
#     else
#       puts "The following dependencies failed. Please check them and try again:"
#       dependencies.reject { |d| d.pass? }.each do |d|
#         puts "--> #{d.message}"
#       end
#       abort
#     end
#   end

#   desc <<-DESC
#     Deploys and starts a 'cold' application. This is useful if you have not
#     deployed your application before, or if your application is (for some
#     other reason) not currently running. It will deploy the code, run any
#     pending migrations, and then instead of invoking 'deploy:restart', it will
#     invoke 'deploy:start' to fire up the application servers.
#   DESC
#   task :cold do
#     update
#     migrate
#     start
#   end

############################################################

#   namespace :web do
#     desc <<-DESC
#       Present a maintenance page to visitors. Disables your application's web
#       interface by writing a "maintenance.html" file to each web server. The
#       servers must be configured to detect the presence of this file, and if
#       it is present, always display it instead of performing the request.

#       By default, the maintenance page will just say the site is down for
#       "maintenance", and will be back "shortly", but you can customize the
#       page by specifying the REASON and UNTIL environment variables:

#         $ cap deploy:web:disable
#               REASON="hardware upgrade"
#               UNTIL="12pm Central Time"

#       Further customization will require that you write your own task.
#     DESC
#     task :disable, :roles => :web, :except => { :no_release => true } do
#       require 'erb'
#       on_rollback { run "rm #{shared_path}/system/maintenance.html" }

#       reason = ENV['REASON']
#       deadline = ENV['UNTIL']

#       template = File.read(File.join(File.dirname(__FILE__), "templates", "maintenance.rhtml"))
#       result = ERB.new(template).result(binding)

#       put result, "#{shared_path}/system/maintenance.html", :mode => 0644
#     end

#     desc <<-DESC
#       Makes the application web-accessible again. Removes the
#       "maintenance.html" page generated by deploy:web:disable, which (if your
#       web servers are configured correctly) will make your application
#       web-accessible again.
#     DESC
#     task :enable, :roles => :web, :except => { :no_release => true } do
#       run "rm #{shared_path}/system/maintenance.html"
#     end
#   end
# end

