# frozen_string_literal: true

require_relative '../test_helper'
require 'net/http'
require 'rake'

module RedmineServerlessCostexplorer
  # On moto, through the SDK's real requests and parsing. moto answers
  # GetCostAndUsage with results given in advance through its API, in the
  # order of the requests; it has no GetCostForecast (docs/setup.md#tests).
  class CostExplorerTest < ActiveSupport::TestCase
    include RedmineServerlessCostexplorer::TestHelper

    ENDPOINT = ENV.fetch('MOTO_ENDPOINT_URL', 'http://moto:5000')

    def setup
      # moto keeps a result for each distinct request; start empty.
      moto_post('/moto-api/reset', {})
      @client = Aws::CostExplorer::Client.new(endpoint: ENDPOINT, region: 'us-east-1', retry_limit: 0)
    end

    def moto_post(path, body)
      Net::HTTP.post(URI("#{ENDPOINT}#{path}"), body.to_json, 'Content-Type' => 'application/json')
    end

    def give_results(*names)
      results = names.map { |name| JSON.parse(name == 'daily' ? daily_body : fixture(name)) }
      response = moto_post('/moto-api/static/ce/cost-and-usage-results', { results: results })

      assert_equal '201', response.code
    end

    def test_the_costs_from_cost_explorer
      give_results('services', 'daily')
      subject = fetcher(@client)
      data = subject.fetch

      assert_equal '7.51', data.dig('this_month', 'total')
      assert_equal 'Amazon Relational Database Service', data['services'].first['name']
      assert_equal 30, data['daily'].size
      # moto has no GetCostForecast; the costs are kept without the forecast.
      assert data.dig('forecast', 'error')
      assert_equal 3, subject.requests
    end

    def test_the_costs_by_the_tag
      give_results('services', 'daily', 'tags')
      data = fetcher(@client, tag_key: 'redmine:instance').fetch

      assert_equal 'redmine:instance$prod', data['tags'].first['name']
    end

    def test_the_rake_task_keeps_a_snapshot
      give_results('services', 'daily')
      Rails.application.load_tasks unless Rake::Task.task_defined?('redmine_serverless_costexplorer:refresh')
      task = Rake::Task['redmine_serverless_costexplorer:refresh']
      task.reenable
      with_enabled { with_fetcher_client(@client) { capture_io { task.invoke } } }

      snapshot = ServerlessCostexplorerSnapshot.latest

      assert_equal 'schedule', snapshot.requested_by
      assert_equal 30, snapshot.data['daily'].size
      assert_equal 3, snapshot.requests
    end
  end
end
