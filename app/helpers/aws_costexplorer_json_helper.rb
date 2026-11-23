# frozen_string_literal: true

# The tab as the new UI's JSON (GET admin/aws/costexplorer.json), formatted as
# Redmine's page formats it (AwsCostexplorerHelper), from the controller's
# @enabled, @snapshot and @last_request.
module AwsCostexplorerJsonHelper
  # The failure of the last fetch (its class only), a fetch still running,
  # when the costs were read, and the costs.
  def aws_costexplorer_json
    { enabled: @enabled,
      failure: @last_request&.failed? ? aws_costexplorer_failure_json(@last_request) : nil,
      pending: aws_costexplorer_pending_text,
      updated: @snapshot && format_time(@snapshot.fetched_at),
      costs: @snapshot && aws_costexplorer_costs_json(@snapshot) }
  end

  def aws_costexplorer_pending_text
    return unless @last_request&.pending?

    l(:text_aws_costexplorer_pending, time: format_time(@last_request.requested_at))
  end

  def aws_costexplorer_failure_json(request)
    { text: l(:text_aws_costexplorer_failed, time: format_time(request.requested_at),
                                             error: aws_costexplorer_failure(request)),
      unreachable: request.unreachable? ? l(:text_aws_costexplorer_unreachable) : nil }
  end

  def aws_costexplorer_costs_json(snapshot)
    costs = snapshot.data
    { currency: costs['currency'], totals: aws_costexplorer_totals_json(costs),
      services: Array(costs['services']).map { |row| aws_costexplorer_service_json(row, costs['currency']) },
      tag: costs['tag_key'] && aws_costexplorer_tag_json(costs) }.merge(aws_costexplorer_days_json(snapshot))
  end

  # A row of costs per period, the amounts formatted.
  def aws_costexplorer_row_json(name, row, currency)
    { name: name, this_month: aws_costexplorer_amount(row['this_month'], currency),
      previous_month: aws_costexplorer_amount(row['previous_month'], currency) }
  end

  # A service, with its usage types.
  def aws_costexplorer_service_json(row, currency)
    details = Array(row['details']).map { |detail| aws_costexplorer_row_json(detail['name'], detail, currency) }
    aws_costexplorer_row_json(row['name'], row, currency).merge(details: details)
  end

  # The days, newest first, and the chart's data, oldest first.
  def aws_costexplorer_days_json(snapshot)
    today = aws_costexplorer_today(snapshot)
    days = aws_costexplorer_days(snapshot.data)
    daily = days.reverse.map { |day| aws_costexplorer_day_json(day, today, snapshot.data['currency']) }
    { daily: daily, chart: days.any? ? aws_costexplorer_daily_chart(days, today) : nil }
  end

  def aws_costexplorer_day_json(day, today, currency)
    { date: format_date(Date.parse(day['date'])), amount: aws_costexplorer_amount(day['amount'], currency),
      estimated: aws_costexplorer_estimated_day?(day, today) }
  end

  def aws_costexplorer_totals_json(costs)
    currency = costs['currency']
    forecast = costs.dig('forecast', 'total')
    { this_month: aws_costexplorer_amount(costs.dig('this_month', 'total'), currency),
      forecast: forecast && aws_costexplorer_amount(forecast, currency),
      no_forecast: forecast ? nil : aws_costexplorer_no_forecast(costs),
      previous_month: aws_costexplorer_amount(costs.dig('previous_month', 'total'), currency),
      previous_estimated: costs.dig('previous_month', 'estimated') == true }
  end

  def aws_costexplorer_no_forecast(costs)
    l(:text_aws_costexplorer_no_forecast, error: aws_costexplorer_error_name(costs.dig('forecast', 'error')))
  end

  def aws_costexplorer_tag_json(costs)
    key = costs['tag_key']
    { key: key, label: l(:label_aws_costexplorer_by_tag, tag: key), no_data: aws_costexplorer_no_tag_data?(costs),
      rows: Array(costs['tags']).map do |row|
        aws_costexplorer_row_json(aws_costexplorer_tag_value(row['name'], key), row, costs['currency'])
      end }
  end
end
