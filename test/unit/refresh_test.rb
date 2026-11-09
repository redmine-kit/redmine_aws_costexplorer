# frozen_string_literal: true

require_relative '../test_helper'
require 'rake'

module RedmineServerlessCost
  # The job and the rake task redmine_serverless_cost:refresh.
  class RefreshTest < ActiveSupport::TestCase
    include RedmineServerlessCost::TestHelper

    def setup
      Rails.application.load_tasks unless Rake::Task.task_defined?('redmine_serverless_cost:refresh')
    end

    def run_task
      task = Rake::Task['redmine_serverless_cost:refresh']
      task.reenable
      capture_io { task.invoke }
    end

    def test_the_job_fetches_the_snapshot
      snapshot = ServerlessCostSnapshot.request!('admin')
      with_enabled do
        with_fetcher_client(stub_cost_explorer) { ServerlessCostRefreshJob.perform_now(snapshot.id) }
      end

      assert_not_nil snapshot.reload.fetched_at
    end

    def test_the_job_does_nothing_when_disabled
      snapshot = ServerlessCostSnapshot.request!('admin')
      client = stub_cost_explorer
      with_env('REDMINE_COST_ENABLED' => nil) do
        with_fetcher_client(client) { ServerlessCostRefreshJob.perform_now(snapshot.id) }
      end

      assert_predicate snapshot.reload, :pending?
      assert_empty client.api_requests
    end

    def test_the_task_fetches_and_prunes
      ServerlessCostSnapshot.create!(requested_at: 100.days.ago, requested_by: 'schedule', error: 'boom')
      out, = with_enabled { with_fetcher_client(stub_cost_explorer) { run_task } }

      assert_match(/fetched the costs with 3 request\(s\); deleted 1 old snapshot\(s\)/, out)
      assert_equal 'schedule', ServerlessCostSnapshot.latest.requested_by
    end

    def test_the_task_with_the_tag_key
      out, = with_enabled(tag_key: 'redmine:instance') { with_fetcher_client(stub_cost_explorer) { run_task } }

      assert_match(/with 4 request/, out)
      assert_equal 'redmine:instance', ServerlessCostSnapshot.latest.data['tag_key']
    end

    def test_the_task_fails_with_the_error
      client = Aws::CostExplorer::Client.new(stub_responses: { get_cost_and_usage: 'AccessDeniedException' })
      error = assert_raises(SystemExit) do
        with_enabled { with_fetcher_client(client) { run_task } }
      end

      assert_not error.success?
      assert_match(/AccessDeniedException/, ServerlessCostSnapshot.last_request.error)
    end

    def test_the_task_does_nothing_when_disabled
      out, = with_env('REDMINE_COST_ENABLED' => 'false') { run_task }

      assert_match(/nothing fetched/, out)
      assert_equal 0, ServerlessCostSnapshot.count
    end

    def test_the_job_may_run_from_the_sqs_queue
      boot = Module.new do
        def self.allowed_jobs = @allowed_jobs ||= []
        def self.allow_job(name) = allowed_jobs << name
      end
      Object.const_set(:RedmineServerlessSqsBoot, boot)
      RedmineServerlessCost.setup

      assert_equal ['ServerlessCostRefreshJob'], boot.allowed_jobs
    ensure
      Object.send(:remove_const, :RedmineServerlessSqsBoot)
    end

    def test_settings_from_the_environment
      with_env('REDMINE_COST_ENABLED' => ' TRUE ', 'REDMINE_COST_TAG_KEY' => ' ') do
        assert_predicate RedmineServerlessCost, :enabled?
        assert_nil RedmineServerlessCost.tag_key
      end
      with_env('REDMINE_COST_ENABLED' => '1', 'REDMINE_COST_TAG_KEY' => 'redmine:instance') do
        assert_not RedmineServerlessCost.enabled?
        assert_equal 'redmine:instance', RedmineServerlessCost.tag_key
      end
    end
  end
end
