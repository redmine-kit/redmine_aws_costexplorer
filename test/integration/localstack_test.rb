# frozen_string_literal: true

require_relative '../test_helper'

module RedmineServerlessCostexplorer
  # On LocalStack's Cost Explorer (Ultimate plan), when bin/test runs with
  # LOCALSTACK_AUTH_TOKEN. LocalStack has no billing data: GetCostAndUsage
  # answers with no results, and GetCostForecast is not implemented
  # (docs/setup.md#tests). The tests check that the plugin's requests are
  # accepted, that the SDK parses the answers, and that a fetch is kept
  # without a forecast; they print what LocalStack returns.
  class LocalstackTest < ActiveSupport::TestCase
    include RedmineServerlessCostexplorer::TestHelper

    def setup
      skip 'LocalStack runs only with LOCALSTACK_AUTH_TOKEN' unless ENV['TEST_AWS_BACKEND'] == 'localstack'

      @client = Aws::CostExplorer::Client.new(endpoint: ENV.fetch('LOCALSTACK_ENDPOINT_URL'), region: 'us-east-1',
                                              retry_limit: 0)
    end

    def show(name, response)
      puts "\n[LocalStack #{name}] #{response.to_h.to_json.truncate(2000)}"
    end

    def period(start, finish)
      { start: start.iso8601, end: finish.iso8601 }
    end

    def test_monthly_by_service
      today = Time.now.utc.to_date
      response = @client.get_cost_and_usage(time_period: period(today.beginning_of_month.prev_month, today + 1),
                                            granularity: 'MONTHLY', metrics: ['UnblendedCost'],
                                            group_by: [{ type: 'DIMENSION', key: 'SERVICE' }])
      show('GetCostAndUsage MONTHLY by SERVICE', response)

      assert_kind_of Array, response.results_by_time
    end

    def test_monthly_by_tag
      today = Time.now.utc.to_date
      response = @client.get_cost_and_usage(time_period: period(today.beginning_of_month.prev_month, today + 1),
                                            granularity: 'MONTHLY', metrics: ['UnblendedCost'],
                                            group_by: [{ type: 'TAG', key: 'redmine:instance' }])
      show('GetCostAndUsage MONTHLY by TAG', response)

      assert_kind_of Array, response.results_by_time
    end

    def test_daily
      today = Time.now.utc.to_date
      response = @client.get_cost_and_usage(time_period: period(today - 29, today + 1), granularity: 'DAILY',
                                            metrics: ['UnblendedCost'])
      show('GetCostAndUsage DAILY', response)

      assert_kind_of Array, response.results_by_time
    end

    # Not implemented in LocalStack 2026.10.6. When this fails, LocalStack
    # has started answering; update docs/setup.md#tests.
    def test_forecast_is_not_implemented
      today = Time.now.utc.to_date
      error = assert_raises(Aws::CostExplorer::Errors::InternalFailure) do
        @client.get_cost_forecast(time_period: period(today, today.beginning_of_month.next_month),
                                  metric: 'UNBLENDED_COST', granularity: 'MONTHLY')
      end
      puts "\n[LocalStack GetCostForecast] #{error.class}: #{error.message}"

      assert_match(/not been implemented/, error.message)
    end

    def test_the_whole_fetch
      fetcher = Fetcher.new(client: @client, tag_key: 'redmine:instance')
      data = fetcher.fetch
      puts "\n[LocalStack fetch] #{data.to_json.truncate(2000)}"

      assert_equal 4, fetcher.requests
      assert_equal({ 'total' => '0.0', 'estimated' => false }, data['this_month'])
      assert data.dig('forecast', 'error')
      assert_empty data['tags']
    end
  end
end
