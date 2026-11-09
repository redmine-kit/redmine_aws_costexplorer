# frozen_string_literal: true

require_relative '../test_helper'
require 'net/http'
require 'rake'

module RedmineServerlessCostexplorer
  # Cost Explorer through the SDK's real requests and parsing: on LocalStack
  # when bin/test runs with LOCALSTACK_AUTH_TOKEN (as in CI), on moto
  # otherwise. GetCostForecast, which neither implements, is mocked with an
  # answer in the documented shape (docs/setup.md#tests).
  class CostExplorerTest < ActiveSupport::TestCase
    include RedmineServerlessCostexplorer::TestHelper

    LOCALSTACK = ENV['TEST_AWS_BACKEND'] == 'localstack'
    ENDPOINT = LOCALSTACK ? ENV.fetch('LOCALSTACK_ENDPOINT_URL') : ENV.fetch('MOTO_ENDPOINT_URL', 'http://moto:5000')

    def setup
      # moto keeps a result for each distinct request; start empty.
      moto_post('/moto-api/reset', {}) unless LOCALSTACK
      @client = Aws::CostExplorer::Client.new(endpoint: ENDPOINT, region: 'us-east-1', retry_limit: 0)
      mock_forecast(@client)
    end

    # GetCostForecast from fixtures/cost_explorer/forecast.json (a total of
    # 15.0), parsed by the SDK; the other calls go to the backend.
    def mock_forecast(client)
      answers = Aws::CostExplorer::Client.new(stub_responses: { get_cost_forecast: http_body(fixture('forecast')) })
      client.define_singleton_method(:get_cost_forecast) do |params = {}, options = {}|
        answers.get_cost_forecast(params, options)
      end
    end

    def moto_post(path, body)
      Net::HTTP.post(URI("#{ENDPOINT}#{path}"), body.to_json, 'Content-Type' => 'application/json')
    end

    # moto answers GetCostAndUsage with these results, in the order of the
    # requests. LocalStack has no billing data and answers with no results.
    def give_results(*names)
      return if LOCALSTACK

      results = names.map { |name| JSON.parse(name == 'daily' ? daily_body : fixture(name)) }
      response = moto_post('/moto-api/static/ce/cost-and-usage-results', { results: results })

      assert_equal '201', response.code
    end

    def test_the_costs_from_cost_explorer
      give_results('services', 'daily')
      subject = fetcher(@client)
      data = subject.fetch
      puts "\n[#{ENV.fetch('TEST_AWS_BACKEND', 'moto')} fetch] #{data.to_json.truncate(1500)}" if LOCALSTACK

      assert_equal 3, subject.requests
      if LOCALSTACK
        assert_equal({ 'total' => '0.0', 'estimated' => false }, data['this_month'])
        assert_empty data['services']
        assert_empty data['daily']
        assert_equal({ 'total' => '15.0' }, data['forecast'])
      else
        assert_equal '7.51', data.dig('this_month', 'total')
        assert_equal 'Amazon Relational Database Service', data['services'].first['name']
        assert_equal 30, data['daily'].size
        # 7.2 until yesterday and the mocked 15.0.
        assert_equal({ 'total' => '22.2' }, data['forecast'])
      end
    end

    def test_the_costs_by_the_tag
      give_results('services', 'daily', 'tags')
      subject = fetcher(@client, tag_key: 'redmine:instance')
      data = subject.fetch

      assert_equal 4, subject.requests
      if LOCALSTACK
        assert_empty data['tags']
      else
        assert_equal 'redmine:instance$prod', data['tags'].first['name']
      end
    end

    def test_the_rake_task_keeps_a_snapshot
      give_results('services', 'daily')
      Rails.application.load_tasks unless Rake::Task.task_defined?('redmine_serverless_costexplorer:refresh')
      task = Rake::Task['redmine_serverless_costexplorer:refresh']
      task.reenable
      with_enabled { with_fetcher_client(@client) { capture_io { task.invoke } } }
      snapshot = ServerlessCostexplorerSnapshot.latest

      assert_equal 'schedule', snapshot.requested_by
      assert_equal 3, snapshot.requests
      assert_equal(LOCALSTACK ? 0 : 30, snapshot.data['daily'].size)
    end

    # Why GetCostForecast is mocked: LocalStack 2026.10.6 does not implement
    # it. When this fails, LocalStack answers it; remove the mock and update
    # docs/setup.md#tests.
    def test_localstack_has_no_forecast
      skip 'LocalStack runs only with LOCALSTACK_AUTH_TOKEN' unless LOCALSTACK

      real = Aws::CostExplorer::Client.new(endpoint: ENDPOINT, region: 'us-east-1', retry_limit: 0)
      error = assert_raises(Aws::CostExplorer::Errors::InternalFailure) do
        real.get_cost_forecast(time_period: { start: TODAY.iso8601, end: '2026-12-01' }, metric: 'UNBLENDED_COST',
                               granularity: 'MONTHLY')
      end

      assert_match(/not been implemented/, error.message)
    end
  end
end
