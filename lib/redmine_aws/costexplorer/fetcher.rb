# frozen_string_literal: true

require 'bigdecimal'

module RedmineAws
  module CostExplorer
    # Reads the account's costs from Cost Explorer (docs/README.md#what-the-tab-shows):
    # three requests, four with the cost allocation tag, and one more for each
    # further page of a long answer. Amounts are unblended costs, as strings in
    # the currency that Cost Explorer returns. Dates are in UTC, as in Cost
    # Explorer.
    class Fetcher
      METRIC = 'UnblendedCost'
      FORECAST_METRIC = 'UNBLENDED_COST'
      # Cost Explorer's API is only in us-east-1 (ce.us-east-1.amazonaws.com).
      REGION = 'us-east-1'
      DAYS = 30
      # The services with their usage types (the details of a service).
      BY_SERVICE_AND_USAGE_TYPE = [{ type: 'DIMENSION', key: 'SERVICE' },
                                   { type: 'DIMENSION', key: 'USAGE_TYPE' }].freeze

      attr_reader :requests

      def initialize(client: nil, tag_key: RedmineAws::CostExplorer.tag_key, today: Time.now.utc.to_date)
        @client = client
        @tag_key = tag_key
        @today = today
        @requests = 0
      end

      def client
        # Short timeouts, so that an unreachable endpoint fails in seconds.
        @client ||= RedmineAws.client(::Aws::CostExplorer::Client,
                                      region: REGION, http_open_timeout: 5, http_read_timeout: 30, retry_limit: 2)
      end

      # The costs as a hash of plain values, kept as JSON in a snapshot. The
      # services come with their usage types (the details of a service), from
      # the same request grouped by both.
      def fetch
        months = monthly(group_by: BY_SERVICE_AND_USAGE_TYPE)
        daily = daily_costs
        data = { 'currency' => @currency || 'USD', 'today' => @today.iso8601,
                 'this_month' => month_summary(months[:this]), 'previous_month' => month_summary(months[:previous]),
                 'services' => Groups.service_rows(months), 'daily' => daily }
        data['forecast'] = forecast(daily)
        data['tag_key'] = @tag_key
        data['tags'] = tag_rows if @tag_key
        data
      end

      private

      def this_month_start
        @today.beginning_of_month
      end

      # End dates are exclusive in Cost Explorer; tomorrow includes today's
      # costs so far.
      def tomorrow = @today + 1

      # One request for the previous month and this month, by the given
      # groupings (up to two): { previous: { estimated:, groups: { [keys] => amount } }, this: ... }.
      def monthly(group_by:)
        periods = { previous: { estimated: false, groups: Hash.new(BigDecimal(0)) },
                    this: { estimated: false, groups: Hash.new(BigDecimal(0)) } }
        each_page(time_period: period(this_month_start.prev_month, tomorrow), granularity: 'MONTHLY',
                  metrics: [METRIC], group_by: group_by) { |result| add_month(periods, result) }
        periods
      end

      # Adds one month of a monthly answer to its period.
      def add_month(periods, result)
        month = periods[Date.parse(result.time_period.start) < this_month_start ? :previous : :this]
        month[:estimated] ||= result.estimated
        result.groups.each { |group| month[:groups][group.keys] += amount(group.metrics) }
      end

      # The rows of the cost allocation tag's values.
      def tag_rows
        Groups.rows(Groups.by_first_key(monthly(group_by: [{ type: 'TAG', key: @tag_key }])))
      end

      def daily_costs
        start = [@today - (DAYS - 1), this_month_start].min
        days = []
        each_page(time_period: period(start, tomorrow), granularity: 'DAILY', metrics: [METRIC]) do |result|
          days << { 'date' => result.time_period.start, 'amount' => amount(result.total).to_s('F'),
                    'estimated' => result.estimated }
        end
        days
      end

      # The month's total: the costs until yesterday plus Cost Explorer's
      # forecast from today to the end of the month. nil with the reason when
      # Cost Explorer has no forecast (for example, too little history).
      def forecast(daily)
        response = request(:get_cost_forecast, time_period: period(@today, this_month_start.next_month),
                                               metric: FORECAST_METRIC, granularity: 'MONTHLY')
        { 'total' => (until_yesterday(daily) + BigDecimal(response.total.amount)).to_s('F') }
      rescue ::Aws::Errors::ServiceError => e
        { 'error' => "#{e.class.name.demodulize}: #{e.message}" }
      end

      def until_yesterday(daily)
        daily.select { |day| Date.parse(day['date']).between?(this_month_start, @today - 1) }
             .sum(BigDecimal(0)) { |day| BigDecimal(day['amount']) }
      end

      def month_summary(month)
        { 'total' => month[:groups].values.sum(BigDecimal(0)).to_s('F'), 'estimated' => month[:estimated] }
      end

      def each_page(**params, &)
        token = nil
        loop do
          response = request(:get_cost_and_usage, **params, next_page_token: token)
          response.results_by_time.each(&)
          token = response.next_page_token
          break if token.blank?
        end
      end

      def request(operation, **params)
        @requests += 1
        client.public_send(operation, params.compact)
      end

      def period(start, finish)
        { start: start.iso8601, end: finish.iso8601 }
      end

      def amount(metrics)
        value = metrics[METRIC] or return BigDecimal(0)
        @currency ||= value.unit
        BigDecimal(value.amount)
      end
    end
  end
end
