# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../charges_support'

module RedmineKit
  module Aws
    module Costexplorer
      # Redmine Kit Billing's provider when AWS refuses or throttles: retries
      # while Cost Explorer throttles, AssumeRole with the external ID, no
      # forecast, and nothing at all while the plugin is off.
      class ChargesProviderFailureTest < ActiveSupport::TestCase
        include RedmineKit::Aws::Costexplorer::TestHelper
        include ChargesSupport

        def sts(answer)
          ::Aws::STS::Client.new(stub_responses: true, region: 'us-east-1').tap do |client|
            client.stub_responses(:assume_role, answer)
          end
        end

        def assumed_credentials(source, calls)
          answer = lambda { |context|
            calls << context.params
            { credentials: { access_key_id: 'ASIA', secret_access_key: 's', session_token: 't',
                             expiration: 1.hour.from_now } }
          }
          ChargesRequests.new(source.settings, sts_client: sts(answer)).credentials
        end

        test 'LimitExceededException is retried after a wait, each attempt counted' do
          waits = []
          requests = []
          provider = ChargesProvider.new(client: charges_client(requests, throttled: 2), sleeper: ->(s) { waits << s })
          result = with_enabled { provider.fetch(Source.new({}), window: WINDOW, today: TODAY) }

          assert_equal [2, 4], waits
          assert_equal 5, result.requests
        end

        test 'LimitExceededException past the last retry fails the fetch' do
          assert_raises(::Aws::CostExplorer::Errors::LimitExceededException) { charges_fetch(throttled: 10) }
        end

        test "a forecast Cost Explorer can't give is its error's class" do
          client = charges_client([])
          client.stub_responses(:get_cost_forecast, 'DataUnavailableException')
          provider = ChargesProvider.new(client: client)
          result = with_enabled { provider.fetch(Source.new({}), window: WINDOW, today: TODAY) }

          assert_equal({ error: 'Aws::CostExplorer::Errors::DataUnavailableException' }, result.forecast)
        end

        test "a role: AssumeRole with the source's external ID, for a short session" do
          calls = []
          source = Source.new('method' => 'role', 'role_arn' => ROLE)

          assert_equal 'ASIA', assumed_credentials(source, calls).credentials.access_key_id
          assert_equal [{ role_arn: ROLE, external_id: source.settings['external_id'],
                          role_session_name: 'redmine-kit-billing', duration_seconds: 900 }], calls
        end

        test 'AssumeRole refused (a wrong external ID) fails the fetch' do
          provider = ChargesProvider.new(sts_client: sts('AccessDenied'))
          source = Source.new('method' => 'role', 'role_arn' => ROLE)

          assert_raises(::Aws::STS::Errors::AccessDenied) do
            with_enabled { provider.fetch(source, window: WINDOW, today: TODAY) }
          end
        end

        test 'nothing is requested while the plugin is off' do
          requests = []
          provider = ChargesProvider.new(client: charges_client(requests))

          assert_raises(ChargesProvider::Disabled) do
            with_env('REDMINE_COSTEXPLORER_ENABLED' => nil) do
              provider.fetch(Source.new({}), window: WINDOW, today: TODAY)
            end
          end
          assert_empty requests
        end
      end
    end
  end
end
