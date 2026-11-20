# frozen_string_literal: true

require_relative '../test_helper'
require 'net/http'
require_relative '../charges_support'

module RedmineKit
  module Aws
    module Costexplorer
      # The provider inside Redmine Kit Charges' daily fetch, through the SDK's
      # real requests and parsing, on moto: moto is the backend that can load
      # Cost Explorer data (AWS Emulator answers NotImplemented to
      # GetCostAndUsage; docs/setup.md#tests). GetCostForecast, which moto
      # lacks, is mocked as in cost_explorer_test.rb. Skipped without
      # redmine_kit_charges (bin/test_image adds it when it is next to this
      # checkout) and on LocalStack, which has no cost data.
      class ChargesTest < ActiveSupport::TestCase
        include RedmineKit::Aws::Costexplorer::TestHelper

        fixtures :projects, :users, :members, :member_roles, :roles, :enabled_modules

        ENDPOINT = ENV.fetch('MOTO_ENDPOINT_URL', 'http://moto:5000')

        def setup
          skip 'redmine_kit_charges is not installed' unless Redmine::Plugin.installed?(:redmine_kit_charges)
          skip 'moto only (LocalStack has no cost data)' if ENV['TEST_AWS_BACKEND'] == 'localstack'
          Net::HTTP.post(URI("#{ENDPOINT}/moto-api/reset"), '{}', 'Content-Type' => 'application/json')
          @client = ::Aws::CostExplorer::Client.new(endpoint: ENDPOINT, region: 'us-east-1', retry_limit: 0)
          mock_forecast(@client)
        end

        # GetCostForecast from fixtures/cost_explorer/forecast.json (moto has
        # none), as in cost_explorer_test.rb.
        def mock_forecast(client)
          stubs = { get_cost_forecast: http_body(fixture('forecast')) }
          answers = ::Aws::CostExplorer::Client.new(stub_responses: stubs)
          client.define_singleton_method(:get_cost_forecast) do |params = {}, options = {}|
            answers.get_cost_forecast(params, options)
          end
        end

        def money(amount)
          { 'UnblendedCost' => { 'Amount' => amount, 'Unit' => 'USD' } }
        end

        # moto answers the GetCostAndUsage requests with these results, in order:
        # daily usage by account and service, then the month's adjustments.
        def give_results
          usage = { 'ResultsByTime' => [
            { 'TimePeriod' => { 'Start' => '2026-11-09', 'End' => '2026-11-10' }, 'Total' => {}, 'Estimated' => false,
              'Groups' => [{ 'Keys' => %w[111111111111 AmazonS3], 'Metrics' => money('1.25') },
                           { 'Keys' => %w[222222222222 AmazonEC2], 'Metrics' => money('9.5') }] }
          ], 'DimensionValueAttributes' => ChargesSupport::ACCOUNT_NAMES }
          credits = { 'ResultsByTime' => [
            { 'TimePeriod' => { 'Start' => '2026-11-01', 'End' => '2026-11-11' }, 'Total' => {}, 'Estimated' => true,
              'Groups' => [{ 'Keys' => %w[111111111111 Credit], 'Metrics' => money('-0.25') }] }
          ] }
          post_results(usage, credits)
        end

        def post_results(*results)
          response = Net::HTTP.post(URI("#{ENDPOINT}/moto-api/static/ce/cost-and-usage-results"),
                                    { results: results }.to_json, 'Content-Type' => 'application/json')

          assert_equal '201', response.code
        end

        # A source of this account, allocated to project 1 for its account
        # 111111111111, which jsmith (Manager) may see.
        def allocated_source
          RedmineKit::Charges.register_provider(ChargesProvider)
          source = ChargeSource.create!(name: 'AWS', provider: 'aws_costexplorer')
          ChargeAllocation.create!(source: source, projects: [Project.find(1)], scopes: %w[111111111111])
          EnabledModule.create!(project_id: 1, name: 'charges')
          Role.find(1).add_permission!(:view_charges)
          source
        end

        test "a project sees its allocated account's charges, fetched through Cost Explorer" do
          give_results
          source = allocated_source
          provider = ChargesProvider.new(client: @client)
          ChargesProvider.stubs(:new).returns(provider)
          fetch = with_enabled { RedmineKit::Charges::Refresh.new(today: TODAY).fetch(source) }

          assert_nil fetch.error
          assert_equal 3, fetch.requests
          allocation = RedmineKit::Charges::Allocation.new(Project.find(1), User.find(2))

          assert_equal BigDecimal('1.25'), allocation.amounts.usage.sum(:amount)
          assert_equal BigDecimal('-0.25'), allocation.amounts.adjustments.sum(:amount)
          assert_equal({ [source.id, '111111111111'] => 'prod' }, allocation.scope_names)
          # 10.75 until yesterday (both accounts: the source's forecast) and the mocked 15.0
          assert_equal BigDecimal('25.75'), source.forecasts.sole.amount
        end
      end
    end
  end
end
