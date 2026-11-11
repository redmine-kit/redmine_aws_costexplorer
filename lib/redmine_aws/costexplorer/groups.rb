# frozen_string_literal: true

require 'bigdecimal'

module RedmineAws
  module Costexplorer
    # The rows of the tab from the monthly groups of Fetcher#monthly
    # ({ previous: { groups: { [keys] => amount } }, this: ... }).
    module Groups
      module_function

      # The months with the groups keyed by the first key only (summed), or by
      # the second key of the groups whose first key is the given one.
      def by_first_key(months)
        months.transform_values do |month|
          groups = Hash.new(BigDecimal(0))
          month[:groups].each { |keys, value| groups[keys.first] += value }
          month.merge(groups: groups)
        end
      end

      def by_second_key(months, first)
        months.transform_values do |month|
          groups = Hash.new(BigDecimal(0))
          month[:groups].each { |keys, value| groups[keys.last] += value if keys.first == first }
          month.merge(groups: groups)
        end
      end

      # The rows of the services, each with its usage types as 'details'.
      def service_rows(months)
        rows(by_first_key(months)).each { |row| row['details'] = rows(by_second_key(months, row['name'])) }
      end

      # [{ 'name', 'this_month', 'previous_month' }], the largest this month first.
      def rows(months)
        names = months[:this][:groups].keys | months[:previous][:groups].keys
        names.sort_by! { |name| [-months[:this][:groups][name], -months[:previous][:groups][name], name] }
        names.map do |name|
          { 'name' => name, 'this_month' => months[:this][:groups][name].to_s('F'),
            'previous_month' => months[:previous][:groups][name].to_s('F') }
        end
      end
    end
  end
end
