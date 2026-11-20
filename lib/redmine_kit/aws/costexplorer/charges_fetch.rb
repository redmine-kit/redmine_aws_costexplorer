# frozen_string_literal: true

require 'bigdecimal'

module RedmineKit
  module Aws
    module Costexplorer
      # One fetch of a source of Redmine Kit Billing (ChargesProvider), over the
      # window (the previous month's first day to today):
      # - R1: daily usage by account and service, without credits, refunds and
      #   taxes;
      # - R3: for each account an allocation splits by tag value, its daily
      #   usage by tag value and service instead of its R1 rows;
      # - R2: the month's credits, refunds and taxes by account;
      # - R4: for each account whose statement a project sees, its months by
      #   service and usage type, with the quantity (ChargesStatement);
      # - F0: the source's month-end forecast (system administrators only).
      class ChargesFetch
        DEFAULT_METRIC = 'UnblendedCost'
        FORECAST_METRICS = { 'UnblendedCost' => 'UNBLENDED_COST', 'AmortizedCost' => 'AMORTIZED_COST',
                             'NetUnblendedCost' => 'NET_UNBLENDED_COST' }.freeze
        # Cost Explorer's RECORD_TYPE values read apart (R2), and their kind in
        # redmine_kit_billing.
        ADJUSTMENTS = { 'Credit' => 'credit', 'Refund' => 'refund', 'Tax' => 'tax' }.freeze
        # One fetch's answer, as RedmineKit::Billing::Provider::Result has it:
        # its own, so that this file needs nothing of redmine_kit_billing.
        Result = Data.define(:rows, :scopes, :forecast, :requests, :statement)

        # A metric's amount and currency, 0 USD when Cost Explorer gives none;
        # also the statement's (ChargesStatement).
        def self.money(value, estimated)
          { amount: decimal(value), currency: value&.unit || 'USD', estimated: estimated == true }
        end

        def self.decimal(value) = BigDecimal(value&.amount.presence || 0)

        def initialize(source, requests, window:, today:)
          @settings = source.settings
          @split = source.tag_split_scopes
          # :all, account IDs, or none (also for a source without the method).
          @statement = source.respond_to?(:statement_scopes) ? source.statement_scopes : []
          @requests = requests
          @window = window
          @today = today
          @names = {}
          @accounts = []
        end

        def result
          rows = usage + adjustments
          lines = statement
          Result.new(rows: rows, scopes: @names, forecast: forecast(rows), requests: @requests.count,
                     statement: lines)
        end

        private

        def metric = @settings['metric'].presence || DEFAULT_METRIC
        def tag_key = @settings['tag_key'].presence

        def usage
          rows = daily(%w[LINKED_ACCOUNT SERVICE], not_adjustments) { |keys| [keys[0], '', keys[1]] }
          @accounts = rows.pluck(:scope).uniq.sort
          accounts = tag_key ? listed(@split) : []
          rows.reject { |row| accounts.include?(row[:scope]) } + accounts.flat_map { |account| tagged(account) }
        end

        # The accounts the source lists: :all for every account of the usage.
        def listed(scopes) = scopes == :all ? @accounts : Array(scopes)

        def tagged(account)
          filter = { and: [not_adjustments, linked_account(account)] }
          daily([{ type: 'TAG', key: tag_key }, 'SERVICE'], filter) do |keys|
            [account, keys[0].to_s.split('$', 2).last.to_s, keys[1]]
          end
        end

        # One row per month, on its first day in the window.
        def adjustments
          filter = { dimensions: { key: 'RECORD_TYPE', values: ADJUSTMENTS.keys } }
          results(:MONTHLY, %w[LINKED_ACCOUNT RECORD_TYPE], filter).flat_map do |result, _names|
            date = [Date.parse(result.time_period.start), @window.begin].max
            result.groups.filter_map { |group| adjustment(date, result.estimated, group) }
          end
        end

        def adjustment(date, estimated, group)
          type = ADJUSTMENTS[group.keys[1]] or return
          row(date, estimated, group.metrics, [group.keys[0], '', ''], type)
        end

        # R4, one request (and its pages) per account.
        def statement
          lines = ChargesStatement.new(metric, @window.begin)
          listed(@statement).flat_map do |account|
            filter = { and: [not_adjustments, linked_account(account)] }
            results(:MONTHLY, ChargesStatement::GROUP_BY, filter, metrics: lines.metrics).flat_map do |result, _names|
              lines.lines(account, result)
            end
          end
        end

        # The daily rows, the block giving a group's [scope, tag value, service].
        def daily(group_by, filter, &columns)
          results(:DAILY, group_by, filter).flat_map do |result, attributes|
            remember_names(attributes)
            date = Date.parse(result.time_period.start)
            result.groups.map { |group| row(date, result.estimated, group.metrics, columns.call(group.keys), 'usage') }
          end
        end

        # The accounts' names that Cost Explorer gives with LINKED_ACCOUNT.
        def remember_names(attributes)
          attributes.each { |value| @names[value.value] = value.attributes['description'].to_s }
        end

        def results(granularity, group_by, filter, metrics: [metric])
          @requests.each_result(time_period: period(@window.begin, @window.end + 1), granularity: granularity.to_s,
                                metrics: metrics, filter: filter,
                                group_by: group_by.map { |key| key.is_a?(Hash) ? key : dimension(key) })
        end

        def row(date, estimated, metrics, (scope, tag_value, service), record_type)
          { date: date, scope: scope, tag_value: tag_value, service: service,
            record_type: record_type }.merge(self.class.money(metrics[metric], estimated))
        end

        # The usage until yesterday plus Cost Explorer's forecast from today,
        # or the class of its error when Cost Explorer has none.
        def forecast(rows)
          month = @today.beginning_of_month
          total = @requests.send_request(:get_cost_forecast, time_period: period(@today, month.next_month),
                                                             metric: FORECAST_METRICS.fetch(metric),
                                                             granularity: 'MONTHLY').total
          { amount: until_yesterday(rows, month) + BigDecimal(total.amount), currency: total.unit }
        rescue ::Aws::CostExplorer::Errors::ServiceError => e
          { error: e.class.name }
        end

        def until_yesterday(rows, month)
          rows.select { |row| row[:record_type] == 'usage' && row[:date].between?(month, @today - 1) }
              .sum(BigDecimal(0)) { |row| row[:amount] }
        end

        def dimension(key) = { type: 'DIMENSION', key: key }

        def linked_account(account) = { dimensions: { key: 'LINKED_ACCOUNT', values: [account] } }

        def not_adjustments = { not: { dimensions: { key: 'RECORD_TYPE', values: ADJUSTMENTS.keys } } }

        def period(start, finish) = { start: start.iso8601, end: finish.iso8601 }
      end
    end
  end
end
