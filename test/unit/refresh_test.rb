# frozen_string_literal: true

require_relative '../test_helper'
require 'rake'

module RedmineAws
  module CostExplorer
    # The rake task redmine_aws_costexplorer:refresh, the only fetch.
    class RefreshTest < ActiveSupport::TestCase
      include RedmineAws::CostExplorer::TestHelper

      def setup
        Rails.application.load_tasks unless Rake::Task.task_defined?('redmine_aws_costexplorer:refresh')
      end

      def run_task
        task = Rake::Task['redmine_aws_costexplorer:refresh']
        task.reenable
        capture_io { task.invoke }
      end

      def test_the_task_fetches_and_prunes
        AwsCostexplorerSnapshot.create!(requested_at: 100.days.ago, error: 'boom')
        out, = with_enabled { with_fetcher_client(stub_cost_explorer) { run_task } }

        assert_match(/fetched the costs with 3 request\(s\); deleted 1 old snapshot\(s\)/, out)
        assert_not_nil AwsCostexplorerSnapshot.latest
      end

      def test_the_task_with_the_tag_key
        out, = with_enabled(tag_key: 'redmine:instance') { with_fetcher_client(stub_cost_explorer) { run_task } }

        assert_match(/with 4 request/, out)
        assert_equal 'redmine:instance', AwsCostexplorerSnapshot.latest.data['tag_key']
      end

      def test_the_task_fails_with_the_error
        client = ::Aws::CostExplorer::Client.new(stub_responses: { get_cost_and_usage: 'AccessDeniedException' })
        error = assert_raises(SystemExit) do
          with_enabled { with_fetcher_client(client) { run_task } }
        end

        assert_not error.success?
        assert_match(/AccessDeniedException/, AwsCostexplorerSnapshot.last_request.error)
      end

      def test_the_task_does_nothing_when_disabled
        out, = with_env('REDMINE_COSTEXPLORER_ENABLED' => 'false') { run_task }

        assert_match(/nothing fetched/, out)
        assert_equal 0, AwsCostexplorerSnapshot.count
      end

      def test_settings_from_the_environment
        with_env('REDMINE_COSTEXPLORER_ENABLED' => ' TRUE ', 'REDMINE_COSTEXPLORER_TAG_KEY' => ' ') do
          assert_predicate RedmineAws::CostExplorer, :enabled?
          assert_nil RedmineAws::CostExplorer.tag_key
        end
        with_env('REDMINE_COSTEXPLORER_ENABLED' => '1', 'REDMINE_COSTEXPLORER_TAG_KEY' => 'redmine:instance') do
          assert_not RedmineAws::CostExplorer.enabled?
          assert_equal 'redmine:instance', RedmineAws::CostExplorer.tag_key
        end
      end
    end
  end
end
