# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module CostExplorer
    # The requests that Fetcher sends to Cost Explorer: their parameters,
    # further pages and the periods on the first and last days of a month.
    class FetcherRequestsTest < ActiveSupport::TestCase
      include RedmineAws::CostExplorer::TestHelper

      def test_the_requests
        client = stub_cost_explorer
        subject = fetcher(client)
        subject.fetch

        assert_equal 3, subject.requests
        assert_equal %i[get_cost_and_usage get_cost_and_usage get_cost_forecast],
                     client.api_requests.pluck(:operation_name)
      end

      def test_the_monthly_request
        services = request_params(0)

        assert_equal({ start: '2026-10-01', end: '2026-11-11' }, services[:time_period])
        assert_equal 'MONTHLY', services[:granularity]
        assert_equal ['UnblendedCost'], services[:metrics]
        assert_equal [{ type: 'DIMENSION', key: 'SERVICE' }, { type: 'DIMENSION', key: 'USAGE_TYPE' }],
                     services[:group_by]
      end

      def test_the_daily_request
        daily = request_params(1)

        assert_equal({ start: '2026-10-12', end: '2026-11-11' }, daily[:time_period])
        assert_equal 'DAILY', daily[:granularity]
        assert_nil daily[:group_by]
      end

      def test_the_forecast_request
        forecast = request_params(2)

        assert_equal({ start: '2026-11-10', end: '2026-12-01' }, forecast[:time_period])
        assert_equal 'UNBLENDED_COST', forecast[:metric]
      end

      def test_the_client_is_in_the_region_of_cost_explorer
        client = Fetcher.new.client

        assert_equal 'us-east-1', client.config.region
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

      private

      # The parameters of the request at index of one fetch.
      def request_params(index)
        client = stub_cost_explorer
        fetcher(client).fetch
        client.api_requests[index][:params]
      end

      # The services in two pages: the first group of each month, then the rest.
      def paged_client
        first, second = service_pages
        client = stub_cost_explorer
        client.stub_responses(:get_cost_and_usage, lambda { |context|
          if context.params[:group_by].nil? then http_body(daily_body)
          else http_body((context.params[:next_page_token] ? second : first).to_json)
          end
        })
        client
      end

      def service_pages
        first = JSON.parse(fixture('services'))
        second = first.deep_dup
        first['ResultsByTime'].each { |result| result['Groups'] = result['Groups'].first(1) }
        first['NextPageToken'] = 'page-2'
        second['ResultsByTime'].each { |result| result['Groups'] = result['Groups'].drop(1) }
        [first, second]
      end
    end
  end
end
