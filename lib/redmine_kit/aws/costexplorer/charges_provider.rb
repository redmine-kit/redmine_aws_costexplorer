# frozen_string_literal: true

require 'securerandom'

module RedmineKit
  module Aws
    module Costexplorer
      # The AWS provider of Redmine Kit Charges (redmine_kit_charges): reads one
      # source's charges from Cost Explorer for the projects' 「料金」 pages
      # (docs/README.md#project-charges-redmine-kit-charges). Registered by
      # RedmineKit::Aws::Costexplorer.setup only when redmine_kit_charges is
      # installed; it answers the methods of RedmineKit::Charges::Provider
      # without subclassing it, so that this file loads without that plugin.
      #
      # A source reads one of:
      # - account: the Redmine server's own account (its primary billing view);
      # - billing_view: a custom billing view shared with that account
      #   (BillingViewArn on every request; the recommended way to read several
      #   accounts);
      # - role: another account, through AssumeRole with the source's external
      #   ID (a standalone account, or an organization that can't share a view).
      # ChargesFetch makes the requests, ChargesRequests sends them.
      class ChargesProvider
        METHODS = %w[account billing_view role].freeze
        METRIC_LABELS = { 'UnblendedCost' => :label_aws_costexplorer_unblended_cost,
                          'AmortizedCost' => :label_aws_costexplorer_amortized_cost,
                          'NetUnblendedCost' => :label_aws_costexplorer_net_unblended_cost }.freeze
        # The partitions' billing views and roles.
        BILLING_VIEW_ARN = %r{\Aarn:aws(?:-[a-z]+)*:billing::\d{12}:billingview/[-A-Za-z0-9/:_+=.@]{1,128}\z}
        ROLE_ARN = %r{\Aarn:aws(?:-[a-z]+)*:iam::\d{12}:role/(?:[\x21-\x7E]{1,511}/)?[\w+=,.@-]{1,64}\z}
        # A cost allocation tag's key: what AWS allows, without the '$' that
        # Cost Explorer puts between a key and its value.
        TAG_KEY = %r{\A[\p{L}\p{Z}\p{N}_.:/=+\-@]{1,128}\z}

        # Raised when REDMINE_COSTEXPLORER_ENABLED is not true: the plugin makes
        # no request to AWS without it.
        class Disabled < StandardError; end

        class << self
          def key = :aws_costexplorer
          def label = :label_aws_costexplorer_charges_provider
          def scope_label = :label_aws_costexplorer_account
          # Who bills the charges (redmine_kit_charges' 請求元 / Vendor column).
          def vendor = 'AWS'
          def settings_keys = %w[method billing_view_arn role_arn metric tag_key]

          # The fields of the administrators' source form (redmine_kit_charges
          # draws them): a locale key for each label, choices for the lists,
          # and the generated external ID shown, not edited.
          def settings_fields
            [{ key: 'method', label: :label_aws_costexplorer_method,
               choices: METHODS.map { |method| [:"label_aws_costexplorer_method_#{method}", method] } },
             { key: 'billing_view_arn', label: :label_aws_costexplorer_billing_view_arn },
             { key: 'role_arn', label: :label_aws_costexplorer_role_arn },
             { key: 'external_id', label: :label_aws_costexplorer_external_id, read_only: true,
               info: :text_aws_costexplorer_external_id },
             { key: 'metric', label: :label_aws_costexplorer_metric, choices: METRIC_LABELS.map(&:reverse) },
             { key: 'tag_key', label: :label_aws_costexplorer_cost_allocation_tag,
               info: :text_aws_costexplorer_cost_allocation_tag }]
          end

          # A new source's external ID: not a secret, but unguessable and this
          # source's own, so that another Redmine server can't register the same
          # role and read these charges (the confused deputy).
          def default_settings
            { 'method' => 'account', 'metric' => ChargesFetch::DEFAULT_METRIC,
              'external_id' => "redmine-kit-#{SecureRandom.uuid}" }
          end
        end

        attr_reader :requests

        # client, sts_client, sleeper: for the tests (ChargesRequests).
        def initialize(**options)
          @options = options
          @requests = 0
        end

        # The settings' shape only: no request to AWS.
        def validate(source)
          settings = source.settings
          method = settings['method']
          source.errors.add(:base, :invalid) unless METHODS.include?(method) &&
                                                    METRIC_LABELS.key?(settings['metric'].presence || 'UnblendedCost')
          check(source, 'billing_view_arn', BILLING_VIEW_ARN, required: method == 'billing_view')
          check(source, 'role_arn', ROLE_ARN, required: method == 'role')
          check(source, 'tag_key', TAG_KEY, required: false)
        end

        def fetch(source, window:, today:)
          raise Disabled unless Costexplorer.enabled?

          requests = ChargesRequests.new(source.settings, **@options)
          ChargesFetch.new(source, requests, window: window, today: today).result
        ensure
          @requests = requests&.count.to_i
        end

        private

        def check(source, key, pattern, required:)
          value = source.settings[key].to_s
          return if value.empty? && !required

          source.errors.add(:base, :invalid) unless value.match?(pattern)
        end
      end
    end
  end
end
