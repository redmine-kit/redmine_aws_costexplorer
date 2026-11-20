# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../charges_support'

module RedmineKit
  module Aws
    module Costexplorer
      # Redmine Kit Charges' provider, with SDK response stubs: the requests of
      # each kind of source and the rows they give.
      class ChargesProviderFetchTest < ActiveSupport::TestCase
        include RedmineKit::Aws::Costexplorer::TestHelper
        include ChargesSupport

        ADJUSTMENT_TYPES = { dimensions: { key: 'RECORD_TYPE', values: %w[Credit Refund Tax] } }.freeze

        def usage_rows(result)
          result.rows.select { |row| row[:record_type] == 'usage' }
                .map { |row| row.values_at(:date, :scope, :service, :amount, :estimated) }
        end

        test 'this account: usage by account and service, three requests' do
          result, requests = charges_fetch

          assert_equal 3, result.requests
          assert(requests.none? { |params| params.key?(:billing_view_arn) })
          assert_equal({ start: '2026-10-01', end: '2026-11-11' }, requests.first[:time_period])
          assert_equal [[Date.new(2026, 11, 9), '111111111111', 'AmazonS3', BigDecimal('1.5'), false],
                        [Date.new(2026, 11, 9), '222222222222', 'AmazonEC2', BigDecimal(3), false],
                        [TODAY, '111111111111', 'AmazonS3', BigDecimal('0.5'), true]], usage_rows(result)
          assert_equal({ '111111111111' => 'prod' }, result.scopes)
        end

        test 'the credits, refunds and taxes apart, by record type' do
          result, requests = charges_fetch
          adjustments = result.rows.reject { |row| row[:record_type] == 'usage' }

          assert_equal({ not: ADJUSTMENT_TYPES }, requests[0][:filter])
          assert_equal [ADJUSTMENT_TYPES, 'MONTHLY'], requests[1].values_at(:filter, :granularity)
          kinds = adjustments.map { |row| [row[:record_type], row[:amount].to_s('F')] }

          assert_equal [%w[credit -2.0], %w[tax 0.3]], kinds
        end

        test "the forecast: the usage until yesterday and Cost Explorer's" do
          result, = charges_fetch

          assert_equal({ amount: BigDecimal('19.5'), currency: 'USD' }, result.forecast)
        end

        test 'a shared billing view: its ARN on every request' do
          _, requests = charges_fetch({ 'method' => 'billing_view', 'billing_view_arn' => VIEW })

          assert_equal [VIEW] * 3, requests.pluck(:billing_view_arn)
        end

        test "an account split by tag value: its rows by tag instead, the key's prefix taken off" do
          result, requests = charges_fetch({ 'tag_key' => 'project' }, split: %w[222222222222])
          rows = result.rows.select { |row| row[:scope] == '222222222222' && row[:record_type] == 'usage' }

          assert_equal 4, result.requests
          account = { dimensions: { key: 'LINKED_ACCOUNT', values: %w[222222222222] } }

          assert_equal({ and: [{ not: ADJUSTMENT_TYPES }, account] }, requests[1][:filter])
          assert_equal([['blue', BigDecimal(2)], ['', BigDecimal(1)]],
                       rows.map { |row| row.values_at(:tag_value, :amount) })
        end

        test 'every account split when an allocation names none; none without a tag key' do
          assert_equal 5, charges_fetch({ 'tag_key' => 'project' }, split: :all).first.requests
          assert_equal 3, charges_fetch({}, split: %w[222222222222]).first.requests
        end
      end
    end
  end
end
