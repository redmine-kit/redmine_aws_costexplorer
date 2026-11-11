# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module Costexplorer
    class FetcherTest < ActiveSupport::TestCase
      include RedmineAws::Costexplorer::TestHelper

      def test_the_account_costs
        data = fetcher.fetch

        assert_equal 'USD', data['currency']
        assert_equal '7.51', data.dig('this_month', 'total')
        assert data.dig('this_month', 'estimated')
        assert_equal '22.4845678901', data.dig('previous_month', 'total')
        assert_not data.dig('previous_month', 'estimated')
      end

      def test_services_with_the_largest_this_month_first
        services = fetcher.fetch['services']

        assert_equal ['Amazon Relational Database Service', 'AWS Lambda', 'Amazon CloudFront',
                      'Amazon Simple Storage Service'], services.pluck('name')
        assert_equal 'Amazon Simple Storage Service', services.last['name']
        assert_equal ['0.0', '0.75'], services.last.values_at('this_month', 'previous_month')
      end

      # One request grouped by service and usage type: the service is the sum of
      # its usage types, which are kept as its details.
      def test_the_usage_types_of_a_service
        rds = fetcher.fetch['services'].first

        assert_equal ['7.1', '20.5'], rds.values_at('this_month', 'previous_month')
        instance = { 'name' => 'APN1-InstanceUsage:db.t4g.micro', 'this_month' => '6.4', 'previous_month' => '18.5' }
        storage = { 'name' => 'APN1-RDS:GP3-Storage', 'this_month' => '0.7', 'previous_month' => '2.0' }
        assert_equal [instance, storage], rds['details']
      end

      def test_thirty_days
        daily = fetcher.fetch['daily']

        assert_equal 30, daily.size
        assert_equal({ 'date' => '2026-10-12', 'amount' => '0.5', 'estimated' => false }, daily.first)
        assert_equal({ 'date' => '2026-11-10', 'amount' => '0.3', 'estimated' => true }, daily.last)
      end

      def test_the_forecast_adds_the_costs_until_yesterday
        # 7.2 from November 1 to 9, and 15.0 forecast from today.
        assert_equal({ 'total' => '22.2' }, fetcher.fetch['forecast'])
      end

      def test_no_forecast
        client = stub_cost_explorer(forecast: 'DataUnavailableException')
        forecast = fetcher(client).fetch['forecast']

        assert_match(/\ADataUnavailableException: /, forecast['error'])
      end

      def test_the_requests
        client = stub_cost_explorer
        subject = fetcher(client)
        subject.fetch

        requests = client.api_requests
        assert_equal 3, subject.requests
        assert_equal %i[get_cost_and_usage get_cost_and_usage get_cost_forecast], requests.pluck(:operation_name)
        services, daily, forecast = requests.pluck(:params)
        assert_equal({ start: '2026-10-01', end: '2026-11-11' }, services[:time_period])
        assert_equal 'MONTHLY', services[:granularity]
        assert_equal ['UnblendedCost'], services[:metrics]
        assert_equal [{ type: 'DIMENSION', key: 'SERVICE' }, { type: 'DIMENSION', key: 'USAGE_TYPE' }],
                     services[:group_by]
        assert_equal({ start: '2026-10-12', end: '2026-11-11' }, daily[:time_period])
        assert_equal 'DAILY', daily[:granularity]
        assert_nil daily[:group_by]
        assert_equal({ start: '2026-11-10', end: '2026-12-01' }, forecast[:time_period])
        assert_equal 'UNBLENDED_COST', forecast[:metric]
      end

      def test_the_client_is_in_the_region_of_cost_explorer
        client = Fetcher.new.client

        assert_equal 'us-east-1', client.config.region
      end

      def test_no_tag_request_without_the_tag_key
        data = fetcher.fetch

        assert_nil data['tag_key']
        assert_not data.key?('tags')
      end

      def test_costs_by_the_tag
        client = stub_cost_explorer
        subject = fetcher(client, tag_key: 'redmine:instance')
        data = subject.fetch

        assert_equal 4, subject.requests
        assert_equal [{ type: 'TAG', key: 'redmine:instance' }], client.api_requests.last[:params][:group_by]
        assert_equal 'redmine:instance', data['tag_key']
        assert_equal ['redmine:instance$prod', 'redmine:instance$staging', 'redmine:instance$'],
                     data['tags'].pluck('name')
      end

      # The services in two pages: the first group of each month, then the rest.
      def paged_client
        first = JSON.parse(fixture('services'))
        second = first.deep_dup
        first['ResultsByTime'].each { |result| result['Groups'] = result['Groups'].first(1) }
        first['NextPageToken'] = 'page-2'
        second['ResultsByTime'].each { |result| result['Groups'] = result['Groups'].drop(1) }
        client = stub_cost_explorer
        client.stub_responses(:get_cost_and_usage, lambda { |context|
          if context.params[:group_by].nil? then http_body(daily_body)
          else http_body((context.params[:next_page_token] ? second : first).to_json)
          end
        })
        client
      end

      def test_further_pages
        subject = fetcher(paged_client)
        data = subject.fetch

        assert_equal 4, subject.requests
        assert_equal '7.51', data.dig('this_month', 'total')
        assert_equal 4, data['services'].size
      end

      def test_a_first_day_of_the_month
        client = stub_cost_explorer
        Fetcher.new(client: client, tag_key: nil, today: Date.new(2026, 12, 1)).fetch
        services, daily, forecast = client.api_requests.pluck(:params)

        assert_equal({ start: '2026-11-01', end: '2026-12-02' }, services[:time_period])
        assert_equal({ start: '2026-11-02', end: '2026-12-02' }, daily[:time_period])
        assert_equal({ start: '2026-12-01', end: '2027-01-01' }, forecast[:time_period])
      end

      def test_a_thirty_first_day_includes_the_whole_month
        client = stub_cost_explorer
        Fetcher.new(client: client, tag_key: nil, today: Date.new(2026, 12, 31)).fetch

        assert_equal({ start: '2026-12-01', end: '2027-01-01' }, client.api_requests.second[:params][:time_period])
      end

      def test_errors_are_raised
        client = ::Aws::CostExplorer::Client.new(stub_responses: { get_cost_and_usage: 'AccessDeniedException' })

        assert_raises(::Aws::CostExplorer::Errors::AccessDeniedException) { fetcher(client).fetch }
      end
    end
  end
end
