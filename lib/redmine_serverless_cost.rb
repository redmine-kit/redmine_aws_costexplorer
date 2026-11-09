# frozen_string_literal: true

# Redmine Serverless Cost: the AWS account's costs from Cost Explorer on the
# "Costs" tab of the Serverless administration page (docs/README.md).
#
# The plugin is on only when REDMINE_COST_ENABLED is true. The page never
# calls Cost Explorer: the rake task redmine_serverless_cost:refresh (daily)
# and the "Refresh" button fetch the costs and keep them in
# serverless_cost_snapshots.
module RedmineServerlessCost
  VERSION = '0.1.0'

  # Environment variables (docs/setup.md#configuration).
  ENV_ENABLED = 'REDMINE_COST_ENABLED'
  ENV_TAG_KEY = 'REDMINE_COST_TAG_KEY'

  # The "Refresh" button may start a fetch once in this many seconds.
  REFRESH_INTERVAL = 3600
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
      RedmineServerlessAdmin.register_tab(:costs, label: :label_serverless_costs,
                                                  url: { controller: 'serverless_costs', action: 'index' },
                                                  position: 60)
      # With Redmine Serverless SQS, only the allowed job classes run from the
      # queue.
      RedmineServerlessSqsBoot.allow_job('ServerlessCostRefreshJob') if defined?(RedmineServerlessSqsBoot)
    end
  end
end
