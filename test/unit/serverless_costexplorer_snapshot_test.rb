# frozen_string_literal: true

require_relative '../test_helper'

module RedmineServerlessCostexplorer
  class ServerlessCostexplorerSnapshotTest < ActiveSupport::TestCase
    include RedmineServerlessCostexplorer::TestHelper

    def test_a_fetch_keeps_the_data
      snapshot = fetched_snapshot

      assert_not snapshot.pending?
      assert_nil snapshot.error
      assert_equal 3, snapshot.requests
      assert_equal '7.51', snapshot.reload.data.dig('this_month', 'total')
      assert_equal snapshot, ServerlessCostexplorerSnapshot.latest
    end

    def test_a_failed_fetch_keeps_the_error
      client = Aws::CostExplorer::Client.new(stub_responses: { get_cost_and_usage: 'AccessDeniedException' })
      snapshot = ServerlessCostexplorerSnapshot.request!('admin')

      assert_not snapshot.fetch!(fetcher(client))
      assert_match(/\AAws::CostExplorer::Errors::AccessDeniedException: /, snapshot.error)
      assert_equal 1, snapshot.requests
      assert_nil snapshot.fetched_at
      assert_not snapshot.unreachable?
      assert_nil ServerlessCostexplorerSnapshot.latest
      assert_equal snapshot, ServerlessCostexplorerSnapshot.last_request
    end

    def test_an_unreachable_endpoint
      client = Aws::CostExplorer::Client.new(stub_responses: true)
      client.stub_responses(:get_cost_and_usage,
                            Seahorse::Client::NetworkingError.new(Net::OpenTimeout.new('execution expired')))
      snapshot = ServerlessCostexplorerSnapshot.request!('admin')
      snapshot.fetch!(fetcher(client))

      assert_predicate snapshot, :unreachable?
    end

    def test_the_latest_successful_snapshot
      older = fetched_snapshot(requested_at: 1.day.ago)
      ServerlessCostexplorerSnapshot.request!('admin').update!(error: 'RuntimeError: boom')

      assert_equal older, ServerlessCostexplorerSnapshot.latest
    end

    def test_refresh_once_per_hour
      assert_predicate ServerlessCostexplorerSnapshot, :refresh_allowed?
      ServerlessCostexplorerSnapshot.create!(requested_at: 30.minutes.ago, requested_by: 'admin')

      assert_not ServerlessCostexplorerSnapshot.refresh_allowed?
      assert_in_delta 30.minutes.from_now, ServerlessCostexplorerSnapshot.refresh_allowed_at, 5
      ServerlessCostexplorerSnapshot.update_all(requested_at: 61.minutes.ago)

      assert_predicate ServerlessCostexplorerSnapshot, :refresh_allowed?
    end

    def test_stale_after_an_hour
      assert_predicate ServerlessCostexplorerSnapshot, :stale?
      snapshot = fetched_snapshot

      assert_not ServerlessCostexplorerSnapshot.stale?
      snapshot.update!(fetched_at: 61.minutes.ago)

      assert_predicate ServerlessCostexplorerSnapshot, :stale?
    end

    def test_request_refresh_once_per_hour
      first = ServerlessCostexplorerSnapshot.request_refresh!('view')

      assert_equal 'view', first.requested_by
      assert_nil ServerlessCostexplorerSnapshot.request_refresh!('admin')
    end

    def test_prune_keeps_the_latest_successful_snapshot
      kept = fetched_snapshot(requested_at: 100.days.ago)
      ServerlessCostexplorerSnapshot.create!(requested_at: 95.days.ago, requested_by: 'admin', error: 'boom')
      recent = ServerlessCostexplorerSnapshot.request!('admin')

      assert_equal 1, ServerlessCostexplorerSnapshot.prune
      assert_equal [kept, recent].map(&:id).sort, ServerlessCostexplorerSnapshot.pluck(:id).sort
    end
  end
end
