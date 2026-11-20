# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../charges_support'

module RedmineKit
  module Aws
    module Costexplorer
      # The account statement of Redmine Kit Charges' provider (R4), with SDK
      # response stubs: one monthly request (in two pages here) per account
      # whose statement a project sees, and the lines it gives.
      class ChargesProviderStatementTest < ActiveSupport::TestCase
        include RedmineKit::Aws::Costexplorer::TestHelper
        include ChargesSupport

        NOT_ADJUSTMENTS = { not: { dimensions: { key: 'RECORD_TYPE', values: %w[Credit Refund Tax] } } }.freeze

        # A source of redmine_kit_charges before the statement.
        OlderSource = Struct.new(:settings, :tag_split_scopes)

        def statement_requests(requests)
          requests.select { |params| params[:group_by]&.pluck(:key) == %w[SERVICE USAGE_TYPE] }
        end

        def accounts(requests)
          statement_requests(requests).map { |params| params[:filter][:and].last[:dimensions][:values] }
        end

        test "each listed account: monthly by service and usage type, with quantities, in the source's view" do
          result, requests = charges_fetch({ 'method' => 'billing_view', 'billing_view_arn' => VIEW },
                                           statement: %w[111111111111 222222222222])
          statement = statement_requests(requests)

          assert_equal 7, result.requests
          assert_equal ([%w[111111111111]] * 2) + ([%w[222222222222]] * 2), accounts(requests)
          statement.each do |params|
            assert_equal [{ start: '2026-10-01', end: '2026-11-11' }, 'MONTHLY', %w[UnblendedCost UsageQuantity],
                          [{ type: 'DIMENSION', key: 'SERVICE' }, { type: 'DIMENSION', key: 'USAGE_TYPE' }], VIEW],
                         params.values_at(:time_period, :granularity, :metrics, :group_by, :billing_view_arn)
            assert_equal NOT_ADJUSTMENTS, params[:filter][:and].first
          end
          assert_equal [nil, 'page-2'] * 2, statement.pluck(:next_page_token)
        end

        test 'every account of the usage when the source lists them all' do
          result, requests = charges_fetch(statement: :all)

          assert_equal ([%w[111111111111]] * 2) + ([%w[222222222222]] * 2), accounts(requests)
          assert_equal %w[111111111111 222222222222], result.statement.pluck(:scope).uniq
        end

        test 'no statement request for a source that lists none or has no statement' do
          [Source.new({}), OlderSource.new(ChargesProvider.default_settings, [])].each do |source|
            result, requests = fetch_source(source)

            assert_equal 3, result.requests
            assert_empty statement_requests(requests)
            assert_equal [], result.statement
          end
        end

        test 'the lines: the month from the window, the quantity and its unit, the amount and its currency' do
          source = Source.new({}, [], %w[111111111111])
          result, = fetch_source(source, window: Date.new(2026, 10, 15)..TODAY)
          lines = result.statement.map do |line|
            line.values_at(:month, :scope, :service, :usage_type, :region, :quantity, :unit, :amount, :currency,
                           :estimated)
          end

          assert_equal [[Date.new(2026, 10, 15), '111111111111', 'AmazonEC2', 'APN1-BoxUsage:t4g.small', '',
                         BigDecimal(744), 'Hrs', BigDecimal('12.5'), 'USD', false],
                        [Date.new(2026, 11, 1), '111111111111', 'AmazonS3', 'APN1-Requests-Tier1', '',
                         BigDecimal(50_000), '', BigDecimal('0.25'), 'USD', true],
                        [Date.new(2026, 11, 1), '111111111111', 'AmazonS3', 'APN1-TimedStorage-ByteHrs', '',
                         BigDecimal(0), '', BigDecimal('0.1'), 'USD', true]], lines
        end
      end
    end
  end
end
