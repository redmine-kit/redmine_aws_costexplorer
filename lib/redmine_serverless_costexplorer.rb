# frozen_string_literal: true

# Redmine Serverless Cost Explorer: the AWS account's costs from Cost Explorer on the
# "Cost Explorer" tab of the Serverless administration page (docs/README.md).
#
# The plugin is on only when REDMINE_COSTEXPLORER_ENABLED is true. The page
# never calls Cost Explorer: the rake task redmine_serverless_costexplorer:refresh,
# run once a day, fetches the costs and keeps them in
# serverless_costexplorer_snapshots.
module RedmineServerlessCostexplorer
  VERSION = '0.1.3'

  # Environment variables (docs/setup.md#configuration).
  ENV_ENABLED = 'REDMINE_COSTEXPLORER_ENABLED'
  ENV_TAG_KEY = 'REDMINE_COSTEXPLORER_TAG_KEY'

  # Snapshots older than this are deleted after each scheduled fetch.
  KEEP_DAYS = 90

  class << self
    def enabled?
      ENV.fetch(ENV_ENABLED, '').strip.casecmp?('true')
    end

    # The cost allocation tag that splits the costs per Redmine instance, or
    # nil when the split is off (the default).
    def tag_key
      value = ENV.fetch(ENV_TAG_KEY, '').strip
      value.empty? ? nil : value
    end

    # Called from init.rb, on every code reload.
    def setup
      RedmineServerlessAdmin.register_tab(
        :costexplorer, label: :label_serverless_costexplorer,
                       url: { controller: 'serverless_costexplorer', action: 'index' }, position: 60
      )
    end
  end
end
