# frozen_string_literal: true

# The plugins this one requires (config/dependencies.yml): without one,
# Redmine stops here and names it.
load File.expand_path('config/dependencies.rb', __dir__)

# Redmine runs this when it prepares the code, again on every reload. Without
# REDMINE_COSTEXPLORER_ENABLED=true the plugin makes no requests to AWS.
Redmine::Plugin.register :redmine_kit_aws_costexplorer do
  requires_redmine version_or_higher: '7.0.0'
  name 'Redmine Kit AWS Cost Explorer'
  author 'Redmine Kit'
  description 'Shows AWS account costs'
  version RedmineKit::Aws::Costexplorer::VERSION
  url 'https://github.com/redmine-kit/redmine_aws_costexplorer'
  author_url 'https://github.com/redmine-kit'
end

RedmineKit::Aws::Costexplorer.setup
