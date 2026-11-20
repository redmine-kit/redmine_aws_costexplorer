# frozen_string_literal: true

require 'bigdecimal'

module RedmineKit
  module Aws
    module Costexplorer
      # The lines of an account's statement (ChargesFetch's R4): one per month,
      # service and usage type, with the amount of the source's metric and the
      # usage quantity with its unit. No region: Cost Explorer groups by two
      # keys at most, and the usage type's prefix (such as APN1-) names it.
      class ChargesStatement
        GROUP_BY = %w[SERVICE USAGE_TYPE].freeze
        QUANTITY = 'UsageQuantity'
        # The unit Cost Explorer gives when a group's quantities have none.
        NO_UNIT = 'N/A'

        def initialize(metric, first_day)
          @metric = metric
          @first_day = first_day
        end

        def metrics = [@metric, QUANTITY]

        # A monthly result's lines, on the month's first day in the window, as
        # the adjustments.
        def lines(account, result)
          month = [Date.parse(result.time_period.start), @first_day].max
          result.groups.map { |group| line(month, account, result.estimated, group) }
        end

        private

        def line(month, account, estimated, group)
          quantity = group.metrics[QUANTITY]
          unit = quantity&.unit.to_s
          { month: month, scope: account, service: group.keys[0], usage_type: group.keys[1], region: '',
            quantity: ChargesFetch.decimal(quantity), unit: unit == NO_UNIT ? '' : unit }
            .merge(ChargesFetch.money(group.metrics[@metric], estimated))
        end
      end
    end
  end
end
