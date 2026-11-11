# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module CostExplorer
    class AwsCostexplorerSnapshotTest < ActiveSupport::TestCase
      include RedmineAws::CostExplorer::TestHelper

      def test_a_fetch_keeps_the_data
        snapshot = fetched_snapshot

        assert_not snapshot.pending?
        assert_nil snapshot.error
        assert_equal 3, snapshot.requests
        assert_equal '7.51', snapshot.reload.data.dig('this_month', 'total')
        assert_equal snapshot, AwsCostexplorerSnapshot.latest
      end

      def test_a_failed_fetch_keeps_the_error
        snapshot = AwsCostexplorerSnapshot.request!

        assert_not snapshot.fetch!(fetcher(denied_client))
        assert_match(/\AAws::CostExplorer::Errors::AccessDeniedException: /, snapshot.error)
        assert_equal 1, snapshot.requests
        assert_not snapshot.unreachable?
      end

      def test_a_failed_fetch_is_the_last_request_but_not_the_latest_data
        snapshot = AwsCostexplorerSnapshot.request!
        snapshot.fetch!(fetcher(denied_client))

        assert_nil snapshot.fetched_at
        assert_nil AwsCostexplorerSnapshot.latest
        assert_equal snapshot, AwsCostexplorerSnapshot.last_request
      end

      def test_an_unreachable_endpoint
        client = ::Aws::CostExplorer::Client.new(stub_responses: true)
        client.stub_responses(:get_cost_and_usage,
                              Seahorse::Client::NetworkingError.new(Net::OpenTimeout.new('execution expired')))
        snapshot = AwsCostexplorerSnapshot.request!
        snapshot.fetch!(fetcher(client))

        assert_predicate snapshot, :unreachable?
      end

      def test_the_latest_successful_snapshot
        older = fetched_snapshot(requested_at: 1.day.ago)
        AwsCostexplorerSnapshot.request!.update!(error: 'RuntimeError: boom')

        assert_equal older, AwsCostexplorerSnapshot.latest
      end

      def test_prune_keeps_the_latest_successful_snapshot
        kept = fetched_snapshot(requested_at: 100.days.ago)
        AwsCostexplorerSnapshot.create!(requested_at: 95.days.ago, error: 'boom')
        recent = AwsCostexplorerSnapshot.request!

        assert_equal 1, AwsCostexplorerSnapshot.prune
        assert_equal [kept, recent].map(&:id).sort, AwsCostexplorerSnapshot.pluck(:id).sort
      end

      private

      def denied_client
        ::Aws::CostExplorer::Client.new(stub_responses: { get_cost_and_usage: 'AccessDeniedException' })
      end
    end
  end
end
