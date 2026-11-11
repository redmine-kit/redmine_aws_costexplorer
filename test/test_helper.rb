# frozen_string_literal: true

# Coverage of the plugin's own files (bin/test sets PLUGIN_COVERAGE for the
# plugin's tests), written as Cobertura XML to coverage/ for Codecov. It starts
# before Redmine loads, so that lib/ and app/ are counted.
if ENV['PLUGIN_COVERAGE']
  require 'simplecov'
  require 'simplecov-cobertura'
  SimpleCov.start do
    root File.expand_path('..', __dir__)
    add_filter '/test/'
    enable_coverage :branch
    formatter SimpleCov::Formatter::CoberturaFormatter
  end
end

require File.expand_path('../../../test/test_helper', __dir__)
require File.join(Redmine::Plugin.find(:redmine_aws).directory, 'test/support/redmine_aws/test_helper')

module RedmineAws
  module CostExplorer
    module TestHelper
      include RedmineAws::TestHelper

      TODAY = Date.new(2026, 11, 10)
      FIXTURES = File.expand_path('fixtures/cost_explorer', __dir__)

      def fixture(name)
        File.read(File.join(FIXTURES, "#{name}.json"))
      end

      # The daily costs from 2026-10-12 to 2026-11-10: 0.5 a day in October,
      # 0.8 a day from November 1 to 9 (7.2) and 0.3 today, estimated.
      def daily_body
        results = (Date.new(2026, 10, 12)..TODAY).map do |day|
          amount = if day == TODAY then '0.3'
                   elsif day.month == 11 then '0.8'
                   else '0.5'
                   end
          { 'TimePeriod' => { 'Start' => day.iso8601, 'End' => (day + 1).iso8601 },
            'Total' => { 'UnblendedCost' => { 'Amount' => amount, 'Unit' => 'USD' } },
            'Groups' => [], 'Estimated' => day == TODAY }
        end
        { 'ResultsByTime' => results, 'DimensionValueAttributes' => [] }.to_json
      end

      def http_body(body)
        { status_code: 200, headers: { 'content-type' => 'application/x-amz-json-1.1' }, body: body }
      end

      # A client whose answers are the fixtures, parsed by the SDK as real
      # answers are.
      def stub_cost_explorer(forecast: http_body(fixture('forecast')))
        client = ::Aws::CostExplorer::Client.new(stub_responses: true, region: 'us-east-1')
        client.stub_responses(:get_cost_and_usage, lambda { |context|
          group = context.params[:group_by]&.first
          if group.nil? then http_body(daily_body)
          elsif group[:type] == 'TAG' then http_body(fixture('tags'))
          else http_body(fixture('services'))
          end
        })
        client.stub_responses(:get_cost_forecast, forecast)
        client
      end

      def fetcher(client = stub_cost_explorer, tag_key: nil)
        RedmineAws::CostExplorer::Fetcher.new(client: client, tag_key: tag_key, today: TODAY)
      end

      def with_enabled(tag_key: nil, &)
        with_env({ 'REDMINE_COSTEXPLORER_ENABLED' => 'true', 'REDMINE_COSTEXPLORER_TAG_KEY' => tag_key }, &)
      end

      # A snapshot fetched from the fixtures.
      def fetched_snapshot(tag_key: nil, requested_at: 2.hours.ago)
        snapshot = AwsCostexplorerSnapshot.create!(requested_at: requested_at)
        snapshot.fetch!(fetcher(tag_key: tag_key))
        snapshot
      end

      # Makes every new Fetcher use the given client.
      def with_fetcher_client(client)
        RedmineAws::CostExplorer::Fetcher.any_instance.stubs(:client).returns(client)
        yield
      ensure
        RedmineAws::CostExplorer::Fetcher.any_instance.unstub(:client)
      end
    end
  end
end
