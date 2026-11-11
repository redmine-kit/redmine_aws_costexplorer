# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module CostExplorer
    # The state of the daily fetch on the "Cost Explorer" tab: errors, a
    # fetch that never finished, a fetch that is running.
    class AwsCostexplorerFetchStateTest < Redmine::ControllerTest
      include RedmineAws::CostExplorer::TestHelper

      tests AwsCostexplorerController

      def setup
        @request.session[:user_id] = 1
      end

      def test_no_forecast
        snapshot = fetched_snapshot
        error = 'Aws::CostExplorer::Errors::DataUnavailableException: Data is not available for account 111122223333'
        snapshot.update!(data: snapshot.data.merge('forecast' => { 'error' => error }))
        with_enabled { get :index }

        assert_select '#aws-costexplorer-summary td.amount',
                      text: 'No forecast (Aws::CostExplorer::Errors::DataUnavailableException)'
        assert_not_includes response.body, '111122223333'
      end

      def test_the_last_daily_fetch_failed
        fetched_snapshot(requested_at: 3.hours.ago)
        AwsCostexplorerSnapshot.create!(requested_at: 2.hours.ago,
                                        error: 'Seahorse::Client::NetworkingError: execution expired')
        with_enabled { get :index }

        assert_select '#aws-costexplorer-error', text: /Fetch error: .* \(Seahorse::Client::NetworkingError\)/
        assert_select '#aws-costexplorer-error', text: /NetworkingError/
        assert_select 'div.flash.error#aws-costexplorer-error'
        assert_select '#aws-costexplorer-error', text: /could not be reached/
        assert_not_includes response.body, 'execution expired', 'the message stays in the log'
        assert_select '#aws-costexplorer-summary'
      end

      def test_a_daily_fetch_that_never_finished
        fetched_snapshot(requested_at: 3.hours.ago)
        AwsCostexplorerSnapshot.create!(requested_at: 2.hours.ago)
        with_enabled { get :index }

        assert_select '#aws-costexplorer-error', text: /Fetch error: .* \(Timed out\)/
        assert_select '#aws-costexplorer-updated', text: /Updated: .* \(daily\)/
      end

      def test_a_running_daily_fetch
        AwsCostexplorerSnapshot.request!
        with_enabled { get :index }

        assert_select '#aws-costexplorer-updated', text: /Updated: running \(since .*\)/
      end
    end
  end
end
