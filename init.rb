# frozen_string_literal: true

# The plugins this one requires (config/dependencies.yml): without one,
# Redmine stops here and names it.
load File.expand_path('config/dependencies.rb', __dir__)

# Redmine runs this when it prepares the code, again on every reload. Without
# REDMINE_COSTEXPLORER_ENABLED=true the plugin makes no requests to AWS.
Redmine::Plugin.register :redmine_kit_aws_costexplorer do
  # This folder, as Redmine's plugin loader found it: plugins/redmine_kit_aws_costexplorer (a checkout
  # or a link), or the installed gem's folder (boot/redmine_kit_aws_costexplorer.rb). Redmine's
  # default is plugins/<id>, which a gem doesn't have.
  directory File.dirname(__FILE__)
  requires_redmine version_or_higher: '7.0.0'
  name 'Redmine Kit AWS Cost Explorer'
  author 'Redmine Kit'
  description 'Shows AWS account costs'
  version RedmineKit::Aws::Costexplorer::VERSION
  url 'https://github.com/redmine-kit/redmine_aws_costexplorer'
  author_url 'https://github.com/redmine-kit'
end

RedmineKit::Aws::Costexplorer.setup
