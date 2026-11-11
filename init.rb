# frozen_string_literal: true

# Redmine runs this when it prepares the code, again on every reload. Without
# REDMINE_COSTEXPLORER_ENABLED=true the plugin makes no requests to AWS.
Redmine::Plugin.register :redmine_aws_costexplorer do
  name 'Redmine AWS Cost Explorer'
  author 'Redmine Kit'
  description "Shows the AWS account's costs from Cost Explorer in the administration"
  version RedmineAwsCostexplorer::VERSION
  url 'https://github.com/redmine-kit/redmine_aws_costexplorer'
  author_url 'https://github.com/redmine-kit'
  requires_redmine version_or_higher: '7.0.0'
  requires_redmine_plugin :redmine_aws, version_or_higher: '0.1.0'
end

RedmineAwsCostexplorer.setup
