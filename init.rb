# frozen_string_literal: true

# Redmine runs this when it prepares the code, again on every reload. Without
# REDMINE_COSTEXPLORER_ENABLED=true the plugin makes no requests to AWS.
Redmine::Plugin.register :redmine_serverless_costexplorer do
  name 'Redmine Serverless Cost Explorer'
  author 'Redmine Kit'
  description "Shows the AWS account's costs from Cost Explorer in the administration"
  version RedmineServerlessCostexplorer::VERSION
  url 'https://github.com/redmine-kit/redmine_serverless_costexplorer'
  author_url 'https://github.com/redmine-kit'
  requires_redmine version_or_higher: '7.0.0'
end

RedmineServerlessCostexplorer.setup
