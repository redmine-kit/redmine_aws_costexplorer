# frozen_string_literal: true

# Redmine runs this when it prepares the code, again on every reload. Without
# REDMINE_COSTEXPLORER_ENABLED=true the plugin makes no requests to AWS.
Redmine::Plugin.register :redmine_kit_aws_costexplorer do
  # First: without redmine_kit_aws, Redmine says that the plugin requires it,
  # before the lines below need its RedmineKit::Aws namespace.
  requires_redmine_plugin :redmine_kit_aws, version_or_higher: '0.1.0'
  requires_redmine version_or_higher: '7.0.0'
  name 'Redmine Kit AWS Cost Explorer'
  author 'Redmine Kit'
  description 'Shows AWS account costs'
  version RedmineKit::Aws::Costexplorer::VERSION
  url 'https://github.com/redmine-kit/redmine_aws_costexplorer'
  author_url 'https://github.com/redmine-kit'
end

RedmineKit::Aws::Costexplorer.setup
