# frozen_string_literal: true

# Redmine Kit AWS Cost Explorer: the AWS account's costs from Cost Explorer on the
# "Cost Explorer" tab of the AWS administration page (docs/README.md).
#
# The plugin is on only when REDMINE_COSTEXPLORER_ENABLED is true. The page
# never calls Cost Explorer: the rake task redmine_kit:aws:costexplorer:refresh,
# run once a day, fetches the costs and keeps them in
# aws_costexplorer_snapshots.
module RedmineKit
  module Aws
    module Costexplorer
      VERSION = '0.1.0'

      # Environment variables (docs/setup.md#configuration).
      ENV_ENABLED = 'REDMINE_COSTEXPLORER_ENABLED'
      ENV_TAG_KEY = 'REDMINE_COSTEXPLORER_TAG_KEY'

      # The days redmine_kit:aws:costexplorer:prune keeps the snapshots for
      # when DAYS is not given.
      KEEP_DAYS = 90

      class << self
        def enabled?
          RedmineKit::Aws.env_true?(ENV_ENABLED)
        end

        # The cost allocation tag that splits the costs per Redmine server, or
        # nil when the split is off (the default).
        def tag_key
          value = ENV.fetch(ENV_TAG_KEY, '').strip
          value.empty? ? nil : value
        end

        # Called from init.rb, on every code reload.
        def setup
          RedmineKit::Aws::Admin.register_tab(
            :costexplorer, label: :label_aws_costexplorer,
                           url: { controller: 'aws_costexplorer', action: 'index' }, position: 60
          )
          ActiveSupport.on_load(:redmine_kit_billing) { RedmineKit::Aws::Costexplorer.register_charges_provider }
        end

        # The AWS provider of Redmine Kit Billing, when that plugin is installed
        # (an optional dependency): setup's on_load(:redmine_kit_billing) calls
        # it when billing has loaded, whatever order Redmine runs the plugins'
        # init.rb in. Without it, nothing is registered and the tab works
        # alone.
        def register_charges_provider
          return unless RedmineKit.const_defined?(:Billing, false) &&
                        RedmineKit::Billing.respond_to?(:register_provider)

          RedmineKit::Billing.register_provider(ChargesProvider)
        end
      end
    end
  end
end
