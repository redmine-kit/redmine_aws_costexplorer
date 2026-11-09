# frozen_string_literal: true

require_relative '../test_helper'

module RedmineServerlessCost
  class ServerlessCostSnapshotTest < ActiveSupport::TestCase
    include RedmineServerlessCost::TestHelper

    def test_a_fetch_keeps_the_data
      snapshot = fetched_snapshot

      assert_not snapshot.pending?
      assert_nil snapshot.error
      assert_equal 3, snapshot.requests
      assert_equal '7.51', snapshot.reload.data.dig('this_month', 'total')
      assert_equal snapshot, ServerlessCostSnapshot.latest
    end

    def test_a_failed_fetch_keeps_the_error
      client = Aws::CostExplorer::Client.new(stub_responses: { get_cost_and_usage: 'AccessDeniedException' })
      snapshot = ServerlessCostSnapshot.request!('admin')

      assert_not snapshot.fetch!(fetcher(client))
      assert_match(/\AAws::CostExplorer::Errors::AccessDeniedException: /, snapshot.error)
      assert_equal 1, snapshot.requests
      assert_nil snapshot.fetched_at
      assert_not snapshot.unreachable?
      assert_nil ServerlessCostSnapshot.latest
      assert_equal snapshot, ServerlessCostSnapshot.last_request
    end

    def test_an_unreachable_endpoint
      client = Aws::CostExplorer::Client.new(stub_responses: true)
      client.stub_responses(:get_cost_and_usage,
                            Seahorse::Client::NetworkingError.new(Net::OpenTimeout.new('execution expired')))
      snapshot = ServerlessCostSnapshot.request!('admin')
      snapshot.fetch!(fetcher(client))

      assert_predicate snapshot, :unreachable?
    end

    def test_the_latest_successful_snapshot
      older = fetched_snapshot(requested_at: 1.day.ago)
      ServerlessCostSnapshot.request!('admin').update!(error: 'RuntimeError: boom')

      assert_equal older, ServerlessCostSnapshot.latest
    end

    def test_refresh_once_per_hour
      assert_predicate ServerlessCostSnapshot, :refresh_allowed?
      ServerlessCostSnapshot.create!(requested_at: 30.minutes.ago, requested_by: 'admin')

      assert_not ServerlessCostSnapshot.refresh_allowed?
      assert_in_delta 30.minutes.from_now, ServerlessCostSnapshot.refresh_allowed_at, 5
      ServerlessCostSnapshot.update_all(requested_at: 61.minutes.ago)

      assert_predicate ServerlessCostSnapshot, :refresh_allowed?
    end

    def test_prune_keeps_the_latest_successful_snapshot
      kept = fetched_snapshot(requested_at: 100.days.ago)
      ServerlessCostSnapshot.create!(requested_at: 95.days.ago, requested_by: 'admin', error: 'boom')
      recent = ServerlessCostSnapshot.request!('admin')

      assert_equal 1, ServerlessCostSnapshot.prune
      assert_equal [kept, recent].map(&:id).sort, ServerlessCostSnapshot.pluck(:id).sort
    end
  end
end
