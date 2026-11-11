# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module CostExplorer
    class FetcherTest < ActiveSupport::TestCase
      include RedmineAws::CostExplorer::TestHelper

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

      # The class of the error as the other errors of the AWS plugins, and the
      # message in the log.
      def test_no_forecast
        client = stub_cost_explorer(forecast: 'DataUnavailableException')
        forecast = nil
        log = capture_log { forecast = fetcher(client).fetch['forecast'] }

        assert_equal 'Aws::CostExplorer::Errors::DataUnavailableException: stubbed-response-error-message',
                     forecast['error']
        assert_includes log, 'no forecast: Aws::CostExplorer::Errors::DataUnavailableException: ' \
                             'stubbed-response-error-message'
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

      def test_errors_are_raised
        client = ::Aws::CostExplorer::Client.new(stub_responses: { get_cost_and_usage: 'AccessDeniedException' })

        assert_raises(::Aws::CostExplorer::Errors::AccessDeniedException) { fetcher(client).fetch }
      end
    end
  end
end
