resource_name :rvm_gemset

property :user, String, name_property: true
property :ruby_string, String, required: true, default: lazy { "#{rubie}#{gemset}" }
property :rvm_env, String, required: true, default: lazy { new_resource.user }
property :rubie, String, required: true, default: lazy { normalize_ruby_string(new_resource.gemset.split('').first) }
property :gemset, String, required: true, default: lazy { select_gemset(new_resource.gemset) }

def normalize_ruby_string(ruby_string, user = new_resource.user, patch = new_resource.patch)
  return "system" if ruby_string == "system"
  fetched_ruby_string = StringCache.fetch(ruby_string, user)
  return "#{fetched_ruby_string} --patch #{patch}" if patch
  fetched_ruby_string
end

def select_gemset(ruby_string)
  if ruby_string.include?('')
    ruby_string.split('').last
  else
    nil
  end
end

action :create do
  unless ruby_installed?(rubie)
    r = rvm_ruby rubie do
      user    new_resource.user
      action :nothing
    end
    r.run_action(:install)
  end

  if gemset_exists?(:ruby => rubie, :gemset => gemset)
    Chef::Log.debug("rvm_gemset[#{ruby_string}] already exists, so skipping")
  else
    Chef::Log.info("Creating rvm_gemset[#{ruby_string}]")

    rvm_env.use rubie
    if rvm_env.gemset_create gemset
      update_installed_gemsets(rubie)
      Chef::Log.debug("Creation of rvm_gemset[#{ruby_string}] was successful.")
    else
      Chef::Log.warn("Failed to create rvm_gemset[#{ruby_string}].")
    end

    new_resource.updated_by_last_action(true)
  end
end

action :delete do
  if gemset_exists?(:ruby => rubie, :gemset => gemset)
    Chef::Log.info("Deleting rvm_gemset[#{ruby_string}]")

    rvm_env.use rubie
    if rvm_env.gemset_delete gemset
      update_installed_gemsets(rubie)
      Chef::Log.debug("Deletion of rvm_gemset[#{ruby_string}] was successful.")
      new_resource.updated_by_last_action(true)
    else
      Chef::Log.warn("Failed to delete rvm_gemset[#{ruby_string}].")
    end
  else
    Chef::Log.debug("rvm_gemset[#{ruby_string}] does not exist, so skipping")
  end
end

action :empty do
  if gemset_exists?(:ruby => rubie, :gemset => gemset)
    Chef::Log.info("Emptying rvm_gemset[#{ruby_string}]")

    rvm_env.use ruby_string
    if rvm_env.gemset_empty
      update_installed_gemsets(rubie)
      Chef::Log.debug("Emptying of rvm_gemset[#{ruby_string}] was successful.")
      new_resource.updated_by_last_action(true)
    else
      Chef::Log.warn("Failed to empty rvm_gemset[#{ruby_string}].")
    end
  else
    Chef::Log.debug("rvm_gemset[#{ruby_string}] does not exist, so skipping")
  end
end

action :update do
  Chef::Log.info("Updating rvm_gemset[#{ruby_string}]")

  # create gemset if it doesn't exist
  unless gemset_exists?(:ruby => rubie, :gemset => gemset)
    c = rvm_gemset ruby_string do
      user    new_resource.user
      action :nothing
    end
    c.run_action(:create)
  end

  rvm_env.use ruby_string
  if rvm_env.gemset_update
    update_installed_gemsets(rubie)
    Chef::Log.debug("Updating of rvm_gemset[#{ruby_string}] was successful.")
    new_resource.updated_by_last_action(true)
  else
    Chef::Log.warn("Failed to update rvm_gemset[#{ruby_string}].")
  end
end
