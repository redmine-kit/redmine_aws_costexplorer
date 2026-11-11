# frozen_string_literal: true

# Redmine AWS Cost Explorer: the AWS account's costs from Cost Explorer on the
# "Cost Explorer" tab of the AWS administration page (docs/README.md).
#
# The plugin is on only when REDMINE_COSTEXPLORER_ENABLED is true. The page
# never calls Cost Explorer: the rake task redmine_aws_costexplorer:refresh,
# run once a day, fetches the costs and keeps them in
# aws_costexplorer_snapshots.
module RedmineAws
  module CostExplorer
    VERSION = '0.1.0'

    # Environment variables (docs/setup.md#configuration).
    ENV_ENABLED = 'REDMINE_COSTEXPLORER_ENABLED'
    ENV_TAG_KEY = 'REDMINE_COSTEXPLORER_TAG_KEY'

    # Snapshots older than this are deleted after each scheduled fetch.
    KEEP_DAYS = 90

    class << self
      def enabled?
        RedmineAws.env_true?(ENV_ENABLED)
      end

      # The cost allocation tag that splits the costs per Redmine server, or
      # nil when the split is off (the default).
      def tag_key
        value = ENV.fetch(ENV_TAG_KEY, '').strip
        value.empty? ? nil : value
      end

      # Called from init.rb, on every code reload.
      def setup
        RedmineAws::Admin.register_tab(
          :costexplorer, label: :label_aws_costexplorer,
                         url: { controller: 'aws_costexplorer', action: 'index' }, position: 60
        )
      end
    end
  end
end
