resource_name :rvm_default_ruby

property :user, String, name_property: true
property :ruby_string, String, required: true, default: lazy { "#{rubie}#{gemset}" }
property :rvm_env, String, required: true, default: lazy { new_resource.user }
property :rubie, String, required: true, default: lazy { normalize_ruby_string(new_resource.gemset.split('').first) }
property :gemset, String, required: true, default: lazy { select_gemset(new_resource.gemset) }

action :create do
  next if skip_ruby?

  # ensure ruby is installed and gemset exists (if specified)
  unless env_exists?(ruby_string)
    e = rvm_environment ruby_string do
      user    new_resource.user
      action  :nothing
    end
    e.run_action(:create)
  end

  Chef::Log.info("Setting default ruby to rvm_ruby[#{ruby_string}]")
  rvm_env.rvm :use, ruby_string, :default => true
  new_resource.updated_by_last_action(true)
end

private

def skip_ruby?
  if rubie.nil?
    Chef::Log.warn("#{self.class.name}: RVM ruby string `#{rubie}' " +
      "is not known. Use `rvm list known` to get a full list.")
    true
  elsif ruby_default?(ruby_string)
    Chef::Log.debug("#{self.class.name}: `#{ruby_string}' is already default, " +
      "so skipping")
    true
  else
    false
  end
end
