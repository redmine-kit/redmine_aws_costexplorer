# frozen_string_literal: true

require_relative '../test_helper'

module RedmineServerlessCost
  class ServerlessCostsControllerTest < Redmine::ControllerTest
    include RedmineServerlessCost::TestHelper

    tests ServerlessCostsController

    def setup
      @request.session[:user_id] = 1
    end

    def test_the_account_costs
      fetched_snapshot
      client = stub_cost_explorer
      with_enabled { with_fetcher_client(client) { get :index } }

      assert_response :success
      assert_select 'h3', text: 'Costs of this AWS account'
      assert_select '#serverless-costs-summary tr', text: /This month so far\s*7\.51 USD/
      assert_select '#serverless-costs-summary tr', text: /Forecast for this month\s*22\.20 USD/
      assert_select '#serverless-costs-summary tr', text: /Previous month\s*22\.48 USD/
      assert_select '#serverless-costs-services tbody tr', 4
      assert_select '#serverless-costs-services tbody tr:first-child',
                    text: /Amazon Relational Database Service\s*7\.10 USD\s*20\.50 USD/
      assert_select '#serverless-costs-daily > tbody > tr', 30
      assert_select '#serverless-costs-daily tbody tr:first-child table.progress'
      assert_select '#serverless-costs-tags', 0
      assert_select 'input[type=submit][value=Refresh]:not([disabled])'
      # The page never calls Cost Explorer.
      assert_empty client.api_requests
    end

    def test_costs_by_the_tag
      fetched_snapshot(tag_key: 'redmine:instance')
      with_enabled(tag_key: 'redmine:instance') { get :index }

      assert_select 'h3', text: 'By the cost allocation tag redmine:instance'
      assert_select '#serverless-costs-tags tbody tr', 3
      assert_select '#serverless-costs-tags tbody tr', text: /prod\s*6\.00 USD\s*19\.98 USD/
      assert_select '#serverless-costs-tags tbody tr', text: /\(no tag\)\s*0\.00 USD\s*2\.50 USD/
      assert_select '#serverless-costs-no-tag', 0
      assert_select 'p', text: /makes 4 requests/
    end

    def test_a_notice_without_tag_data
      snapshot = fetched_snapshot(tag_key: 'redmine:instance')
      data = snapshot.data
      data['tags'] = [{ 'name' => 'redmine:instance$', 'this_month' => '7.51', 'previous_month' => '0.0' }]
      snapshot.update!(data: data)
      with_enabled(tag_key: 'redmine:instance') { get :index }

      assert_select '#serverless-costs-no-tag', text: /Activate it as a cost allocation tag/
    end

    def test_no_forecast
      snapshot = fetched_snapshot
      snapshot.update!(data: snapshot.data.merge('forecast' => { 'error' => 'DataUnavailableException: x' }))
      with_enabled { get :index }

      assert_select '#serverless-costs-summary tr', text: /Cost Explorer has no forecast\.\s*DataUnavailableException/
    end

    def test_no_data_yet
      with_enabled { get :index }

      assert_response :success
      assert_select 'p.nodata'
      assert_select 'p.warning', 0
    end

    def test_disabled
      fetched_snapshot
      with_env('REDMINE_COST_ENABLED' => nil) { get :index }

      assert_select 'p.warning', text: /REDMINE_COST_ENABLED/
      assert_select 'input[type=submit]', 0
    end

    def test_the_last_refresh_failed
      fetched_snapshot(requested_at: 3.hours.ago)
      ServerlessCostSnapshot.create!(requested_at: 2.hours.ago, requested_by: 'schedule',
                                     error: 'Seahorse::Client::NetworkingError: execution expired')
      with_enabled { get :index }

      assert_select '#serverless-costs-error', text: /NetworkingError/
      assert_select '#serverless-costs-error', text: /could not be reached/
      assert_select '#serverless-costs-summary'
    end

    def test_a_pending_refresh
      ServerlessCostSnapshot.request!('admin')
      with_enabled { get :index }

      assert_select 'p.flash.notice', text: /waiting or running/
      assert_select 'input[type=submit][value=Refresh][disabled]'
    end

    def test_refresh_enqueues_the_job
      # Redmine's tests run jobs inline; the job itself is in RefreshTest.
      ServerlessCostRefreshJob.expects(:perform_later).once
      with_enabled { post :refresh }

      assert_redirected_to '/admin/serverless/costs'
      assert_equal 'admin', ServerlessCostSnapshot.last_request.requested_by
      assert_equal 'The refresh has been queued.', flash[:notice]
    end

    def test_refresh_once_per_hour
      fetched_snapshot(requested_at: 10.minutes.ago)
      ServerlessCostRefreshJob.expects(:perform_later).never
      with_enabled { post :refresh }

      assert_redirected_to '/admin/serverless/costs'
      assert_match(/once per hour/, flash[:error])
    end

    def test_refresh_when_disabled
      with_env('REDMINE_COST_ENABLED' => nil) { post :refresh }

      assert_response :forbidden
      assert_equal 0, ServerlessCostSnapshot.count
    end

    def test_a_failed_enqueue
      ServerlessCostRefreshJob.stubs(:perform_later).raises(RuntimeError, 'queue unreachable')
      with_enabled { post :refresh }

      assert_equal 'RuntimeError: queue unreachable', flash[:error]
      assert_equal 'RuntimeError: queue unreachable', ServerlessCostSnapshot.last_request.error
    end

    def test_non_administrators_are_refused
      @request.session[:user_id] = 2
      get :index

      assert_response :forbidden
      post :refresh

      assert_response :forbidden
    end
  end
end
