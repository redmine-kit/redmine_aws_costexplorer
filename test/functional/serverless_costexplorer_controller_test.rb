# frozen_string_literal: true

require_relative '../test_helper'

module RedmineServerlessCostexplorer
  class ServerlessCostexplorerControllerTest < Redmine::ControllerTest
    include RedmineServerlessCostexplorer::TestHelper

    tests ServerlessCostexplorerController

    def setup
      @request.session[:user_id] = 1
    end

    def test_the_account_costs
      fetched_snapshot
      client = stub_cost_explorer
      with_settings(date_format: '%Y-%m-%d') { with_enabled { with_fetcher_client(client) { get :index } } }

      assert_response :success
      # No heading first: the description line and the update time on the right.
      assert_equal 'By service', css_select('#content h3').first.text
      assert_select '#serverless-costexplorer-summary tr', text: /This month's costs\s*7\.51 USD/
      assert_select '#serverless-costexplorer-summary td.name', text: "This month's costs"
      assert_select '#serverless-costexplorer-summary td.amount', text: '7.51 USD'
      assert_select '#serverless-costexplorer-summary tr', text: /Forecasted month-end costs\s*22\.20 USD/
      assert_select '#serverless-costexplorer-summary tr', text: /Last month's costs\s*22\.48 USD/
      # This month is always estimated, and the last month is final.
      assert_select '#serverless-costexplorer-summary span.badge', 0
      assert_select '#serverless-costexplorer-daily > tbody > tr', 30
      assert_select '#serverless-costexplorer-daily tbody tr:first-child', text: /2026-11-10\s*0\.30 USD/
      # Today is always estimated: no badge.
      assert_select '#serverless-costexplorer-daily span.badge', 0
      assert_select 'div[data-controller="serverless-costexplorer--daily"] canvas[role=img]'
      assert_select 'script[type=module][src*="serverless_costexplorer"]'
      assert_select '#serverless-costexplorer-tags', 0
      assert_select 'p', text: 'Unblended costs from AWS Cost Explorer.'
      assert_select '#serverless-costexplorer-updated', text: /Updated: .* \(daily\)/
      assert_select 'input[type=submit][value=Refresh]', 0
      # The page never calls Cost Explorer.
      assert_empty client.api_requests
    end

    # Each service is a collapsed group of its usage types.
    def test_the_services_with_their_usage_types
      fetched_snapshot
      with_enabled { get :index }

      assert_select '#serverless-costexplorer-services tbody tr.group', 4
      assert_select '#serverless-costexplorer-services tr.group span.expander[aria-expanded=false][tabindex="0"]', 4
      assert_select '#serverless-costexplorer-services tr.idnt-1[style*="display: none"]', 5
      assert_select '#serverless-costexplorer-services tr.idnt-1 td.name', text: 'APN1-RDS:GP3-Storage'
      assert_select '#serverless-costexplorer-services tbody tr:first-child',
                    text: /Amazon Relational Database Service\s*7\.10 USD\s*20\.50 USD/
    end

    def test_an_estimated_last_month
      snapshot = fetched_snapshot
      data = snapshot.data
      data['previous_month']['estimated'] = true
      snapshot.update!(data: data)
      with_enabled { get :index }

      assert_select '#serverless-costexplorer-summary span.badge', 1
      assert_select '#serverless-costexplorer-summary tr', text: /Last month's costs\s*22\.48 USD\s*Estimated/
      assert_select '#serverless-costexplorer-summary tr span.badge.badge-status-locked', text: 'Estimated'
    end

    def test_the_daily_chart
      fetched_snapshot
      with_settings(date_format: '%Y-%m-%d') { with_enabled { get :index } }

      chart = daily_chart
      assert_equal 30, chart[:labels].size
      assert_equal %w[2026-10-12 2026-11-10], [chart[:labels].first, chart[:labels].last]
      assert_equal ['Unblended cost'], chart[:datasets].pluck('label')
      assert_equal [0.5, 0.8, 0.3], chart[:datasets].first['data'].values_at(0, 20, 29)
    end

    def test_an_estimated_past_day
      snapshot = fetched_snapshot
      data = snapshot.data
      data['daily'].find { |day| day['date'] == '2026-11-08' }['estimated'] = true
      snapshot.update!(data: data)
      with_settings(date_format: '%Y-%m-%d') { with_enabled { get :index } }

      assert_select '#serverless-costexplorer-daily span.badge', 1
      assert_select '#serverless-costexplorer-daily tbody tr', text: /2026-11-08\s*0\.80 USD\s*Estimated/
      chart = daily_chart
      final, estimated = chart[:datasets]
      assert_equal ['Unblended cost', 'Estimated'], [final['label'], estimated['label']]
      # One bar a day: the day is in the estimated dataset only.
      assert_equal [nil, 0.8, 29], [final['data'][27], estimated['data'][27], estimated['data'].count(nil)]
    end

    def test_costs_by_the_tag
      fetched_snapshot(tag_key: 'redmine:instance')
      with_enabled(tag_key: 'redmine:instance') { get :index }

      assert_select 'h3', text: 'By cost allocation tag (redmine:instance)'
      assert_select '#serverless-costexplorer-tags tbody tr', 3
      assert_select '#serverless-costexplorer-tags tbody tr', text: /prod\s*6\.00 USD\s*19\.98 USD/
      assert_select '#serverless-costexplorer-tags tbody tr', text: /\(no tag\)\s*0\.00 USD\s*2\.50 USD/
      assert_select '#serverless-costexplorer-no-tag', 0
    end

    def test_a_notice_without_tag_data
      snapshot = fetched_snapshot(tag_key: 'redmine:instance')
      data = snapshot.data
      data['tags'] = [{ 'name' => 'redmine:instance$', 'this_month' => '7.51', 'previous_month' => '0.0' }]
      snapshot.update!(data: data)
      with_enabled(tag_key: 'redmine:instance') { get :index }

      assert_select '#serverless-costexplorer-no-tag', text: /Activate it as a cost allocation tag/
    end

    def test_no_forecast
      snapshot = fetched_snapshot
      snapshot.update!(data: snapshot.data.merge('forecast' => { 'error' => 'DataUnavailableException: x' }))
      with_enabled { get :index }

      assert_select '#serverless-costexplorer-summary tr',
                    text: /No forecast \(DataUnavailableException\)/
    end

    def test_disabled
      fetched_snapshot
      with_env('REDMINE_COSTEXPLORER_ENABLED' => nil) { get :index }

      assert_select 'p.warning', text: /REDMINE_COSTEXPLORER_ENABLED/
    end

    def test_no_data_yet
      with_enabled { get :index }

      assert_response :success
      assert_select 'p.nodata'
      assert_equal 0, ServerlessCostexplorerSnapshot.count
    end

    def test_the_last_daily_fetch_failed
      fetched_snapshot(requested_at: 3.hours.ago)
      ServerlessCostexplorerSnapshot.create!(requested_at: 2.hours.ago, requested_by: 'schedule',
                                             error: 'Seahorse::Client::NetworkingError: execution expired')
      with_enabled { get :index }

      assert_select '#serverless-costexplorer-error', text: /Fetch error: .* \(Seahorse::Client::NetworkingError\)/
      assert_select '#serverless-costexplorer-error', text: /NetworkingError/
      assert_select 'div.flash.error#serverless-costexplorer-error'
      assert_select '#serverless-costexplorer-error', text: /could not be reached/
      assert_not_includes response.body, 'execution expired', 'the message stays in the log'
      assert_select '#serverless-costexplorer-summary'
    end

    def test_a_running_daily_fetch
      ServerlessCostexplorerSnapshot.request!(ServerlessCostexplorerSnapshot::SCHEDULE)
      with_enabled { get :index }

      assert_select '#serverless-costexplorer-updated', text: /Updated: running \(since .*\)/
    end

    def test_no_refresh_route
      assert_raises(ActionController::UrlGenerationError) { post :refresh }
    end

    def test_non_administrators_are_refused
      @request.session[:user_id] = 2
      get :index

      assert_response :forbidden
    end

    private

    # The labels and datasets that the view passes to the chart.
    def daily_chart
      json = lambda { |target|
        JSON.parse(css_select("template[data-serverless-costexplorer--daily-target=#{target}]").first.text)
      }
      { labels: json.call('labels'), datasets: json.call('datasets') }
    end
  end
end
