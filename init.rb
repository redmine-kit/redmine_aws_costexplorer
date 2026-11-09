# frozen_string_literal: true

# Redmine runs this when it prepares the code, again on every reload. Without
# REDMINE_COST_ENABLED=true the plugin makes no requests to AWS.
Redmine::Plugin.register :redmine_serverless_cost do
  name 'Redmine Serverless Cost'
  author 'Redmine Kit'
  description "Shows the AWS account's costs from Cost Explorer in the administration"
  version RedmineServerlessCost::VERSION
  url 'https://github.com/redmine-kit/redmine_serverless_cost'
  author_url 'https://github.com/redmine-kit'
  requires_redmine version_or_higher: '7.0.0'
end

RedmineServerlessCost.setup
