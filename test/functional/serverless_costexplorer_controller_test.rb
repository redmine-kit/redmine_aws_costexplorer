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
      with_enabled { with_fetcher_client(client) { get :index } }

      assert_response :success
      assert_select 'h3', text: 'Costs of this AWS account'
      assert_select '#serverless-costexplorer-summary tr', text: /This month so far\s*7\.51 USD/
      assert_select '#serverless-costexplorer-summary tr', text: /Forecast for this month\s*22\.20 USD/
      assert_select '#serverless-costexplorer-summary tr', text: /Previous month\s*22\.48 USD/
      assert_select '#serverless-costexplorer-services tbody tr', 4
      assert_select '#serverless-costexplorer-services tbody tr:first-child',
                    text: /Amazon Relational Database Service\s*7\.10 USD\s*20\.50 USD/
      assert_select '#serverless-costexplorer-daily > tbody > tr', 30
      assert_select '#serverless-costexplorer-daily tbody tr:first-child table.progress'
      assert_select '#serverless-costexplorer-tags', 0
      assert_select 'p', text: /fetched once a day/
      assert_select 'input[type=submit][value=Refresh]', 0
      # The page never calls Cost Explorer.
      assert_empty client.api_requests
    end

    def test_costs_by_the_tag
      fetched_snapshot(tag_key: 'redmine:instance')
      with_enabled(tag_key: 'redmine:instance') { get :index }

      assert_select 'h3', text: 'By the cost allocation tag redmine:instance'
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
                    text: /Cost Explorer has no forecast\.\s*DataUnavailableException/
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

      assert_select '#serverless-costexplorer-error', text: /The daily fetch started at .* failed/
      assert_select '#serverless-costexplorer-error', text: /NetworkingError/
      assert_select '#serverless-costexplorer-error', text: /could not be reached/
      assert_select '#serverless-costexplorer-summary'
    end

    def test_a_running_daily_fetch
      ServerlessCostexplorerSnapshot.request!(ServerlessCostexplorerSnapshot::SCHEDULE)
      with_enabled { get :index }

      assert_select 'p.flash.notice', text: /The daily fetch started at .* is running/
    end

    def test_no_refresh_route
      assert_raises(ActionController::UrlGenerationError) { post :refresh }
    end

    def test_non_administrators_are_refused
      @request.session[:user_id] = 2
      get :index

      assert_response :forbidden
    end
  end
end
