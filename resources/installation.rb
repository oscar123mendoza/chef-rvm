resource_name :rvm_installation

property :user, String, name_property: true
property :installer_url, String, required: true, default: lazy { node['rvm']['installer_url'] }
property :installer_flags, String, required: true, default: lazy { node['rvm']['installer_flags'] }
property :install_pkgs, String, required: true, default: lazy { node['rvm']['install_pkgs'] }
property :rvmrc_template_source, String, required: true, default: 'rvmrc.erb'
property :rvmrc_template_cookbook, String, required: true, default: 'rvm'
property :rvmrc_gem_options, String, required: true, default: lazy { node['rvm']['gem_options'] }
property :rvmrc_env, Hash, required: true, default: lazy { node['rvm']["rvmrc_env"] }
property :installed, [TrueClass, FalseClass], required: true, default: false
property :version, String, required: true, default: lazy { node['rvm']['version'] }

action :install do
  converge_by("manage rvmrc for #{user}") {
    template rvmrc_path do
      owner new_resource.user
      group etc_user.gid
      mode 0644
      source rvmrc_template_source
      variables(
        :user => new_resource.user,
        :rvm_path => rvm_path,
        :rvmrc_env => new_resource.rvmrc_env
      )
    end
  }

  if new_resource.installed
    Chef::Log.info("#{user} #{current_resource.version} already installed - nothing to do")
  else
    converge_by("install RVM for #{user}") { install_rvm }
    Chef::Log.info("#{user} #{new_resource.version} installed")
  end
end

action :force do
  converge_by("manage rvmrc for #{user}") {
    template rvmrc_path do
      owner new_resource.user
      group etc_user.gid
      mode 0644
      source rvmrc_template_source
      variables(
        :user => new_resource.user,
        :rvm_path => rvm_path,
        :rvmrc_env => new_resource.rvmrc_env
      )
    end
  }
end

def install_rvm
  install_pkgs.each do |pkg|
    package pkg
  end

  remote_file rvm_installer_path do
    source new_resource.installer_url
    action :create
  end

  rvm_shell_out!(%{bash #{rvm_installer_path} #{new_resource.installer_flags}})

  cmd = rvm('version')
  matches = /^rvm ([\w.]+)/.match(cmd.stdout)

  if cmd.exitstatus != 0
    raise "Could not determine version for #{user}, " +
      "exited (#{cmd.exitstatus})"
  end

  if matches && matches[1]
    return matches[1]
  else
    raise "Could not determine version for #{user} " +
      "from version string [#{cmd.stdout}]"
  end
end

def rvm_installer_path
  ::File.join(Chef::Config[:file_cache_path], "rvm-installer-#{new_resource.user}")
end

def installed?
  cmd = rvm_shell_out(
    %{bash -c "source #{rvm_path}/scripts/rvm && type rvm"}
  )
  (cmd.exitstatus == 0 && cmd.stdout.lines.first == "rvm is a function\n")
end

def rvm_shell_out(cmd)
  user = new_resource.user
  home_dir = etc_user.dir
  opts = {
    :user => user,
    :group => etc_user.gid,
    :cwd => home_dir,
    :env => { "HOME" => home_dir, "USER" => user, "TERM" => "dumb" }
  }

  Chef::Log.debug("Running [#{cmd}] with #{opts}")
  shell_out(cmd, opts)
end

def rvm_shell_out!(*args)
  cmd = rvm_shell_out(*args)
  cmd.error!
  cmd
end

def rvm(subcommand)
  rvm_shell_out(%{#{rvm_path}/bin/rvm #{subcommand}})
end

def rvm_path
  if new_resource.user == "root"
    "/usr/local/rvm"
  else
    ::File.join(etc_user.dir, ".rvm")
  end
end

def rvmrc_path
  if new_resource.user == "root"
    "/etc/rvmrc"
  else
    ::File.join(etc_user.dir, ".rvmrc")
  end
end

def etc_user
  Etc.getpwnam(new_resource.user)
end
