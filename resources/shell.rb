resource_name :rvm_shell

property :user, String, required: true, default: lazy { user_installed_rvm? ? new_resource.user : nil }
property :ruby_string, String, required: true, default: lazy { "#{rubie}#{gemset}" }
property :rvm_env, String, required: true, default: lazy { new_resource.user }
property :rubie, String, required: true, default: lazy { normalize_ruby_string(new_resource.gemset.split('').first) }
property :gemset, String, required: true, default: lazy { select_gemset(new_resource.gemset) }

action :run do
  user_rvm = @user_rvm

  # ensure ruby is installed and gemset exists
  unless env_exists?(@ruby_string)
    e = rvm_environment @ruby_string do
      user    user_rvm
      action :nothing
    end
    e.run_action(:create)
  end

  script_wrapper :run
  new_resource.updated_by_last_action(true)
end

private

##
# Wraps the script resource for RVM-dependent code.
#
# @param [Symbol] action to be performed with gem_package provider
def script_wrapper(exec_action)
  profile = find_profile_to_source

  script_code = <<-CODE
    if [ -s "${HOME}/.rvm/scripts/rvm" ]; then
      source "${HOME}/.rvm/scripts/rvm"
    elif [ -s "#{profile}" ]; then
      source "#{profile}"
    fi
    rvm use #{@ruby_string}
    #{new_resource.code}
  CODE

  if new_resource.user
    user_rvm  = user_installed_rvm?
    user_home = user_dir
  end

  s = script new_resource.name do
    interpreter   "bash"

    if new_resource.user
      user        new_resource.user
      if user_rvm && new_resource.environment
        environment({ 'USER' => new_resource.user, 'HOME' => user_home }.merge(
          new_resource.environment))
      elsif user_rvm
        environment({ 'USER' => new_resource.user, 'HOME' => user_home })
      end
    end

    code          script_code
    creates       new_resource.creates      if new_resource.creates
    cwd           new_resource.cwd          if new_resource.cwd
    group         new_resource.group        if new_resource.group
    path          new_resource.path         if new_resource.path
    returns       new_resource.returns      if new_resource.returns
    timeout       new_resource.timeout      if new_resource.timeout
    umask         new_resource.umask        if new_resource.umask
    action        :nothing
  end
  s.run_action(exec_action)
  new_resource.updated_by_last_action(true) if s.updated_by_last_action?
end

##
# Whether or not the user has an isolated RVM installation
#
# @return [true,false] does the user have RVM installed for themselves?
def user_installed_rvm?
  return false unless new_resource.user

  ::File.exists?("#{user_dir}/.rvm/VERSION")
end

##
# Determines the user's home directory
#
# @return [String] the path to the user's home directory
def user_dir
  return nil unless new_resource.user

  Etc.getpwnam(new_resource.user).dir
end
