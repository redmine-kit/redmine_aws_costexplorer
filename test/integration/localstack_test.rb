# frozen_string_literal: true

require_relative '../test_helper'

module RedmineServerlessCostexplorer
  # On LocalStack's Cost Explorer (Ultimate plan), when bin/test runs with
  # LOCALSTACK_AUTH_TOKEN. LocalStack has no billing data; these tests check
  # that the requests the plugin makes are accepted and that the SDK parses
  # the answers, and print what LocalStack returns (docs/setup.md#tests).
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

    def test_forecast
      today = Time.now.utc.to_date
      response = @client.get_cost_forecast(time_period: period(today, today.beginning_of_month.next_month),
                                           metric: 'UNBLENDED_COST', granularity: 'MONTHLY')
      show('GetCostForecast', response)

      assert response.total
    rescue Aws::Errors::ServiceError => e
      puts "\n[LocalStack GetCostForecast] #{e.class}: #{e.message}"
      raise
    end

    def test_the_whole_fetch
      fetcher = Fetcher.new(client: @client, tag_key: 'redmine:instance')
      data = fetcher.fetch
      puts "\n[LocalStack fetch] #{data.to_json.truncate(2000)}"

      assert_equal 4, fetcher.requests
      assert data.key?('this_month')
    end
  end
end
