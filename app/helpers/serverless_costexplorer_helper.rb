# frozen_string_literal: true

require 'bigdecimal'

module ServerlessCostexplorerHelper
  # "1,234.57 USD"
  def serverless_costexplorer_amount(value, currency)
    return '-' if value.nil?

    "#{number_with_delimiter(format('%.2f', BigDecimal(value.to_s)))} #{currency}"
  end

  # The "Estimated" badge, for a closed period whose costs Cost Explorer has
  # not finalized yet. Periods still running (this month, today) are always
  # estimated, so they carry no badge.
  def serverless_costexplorer_estimated(estimated)
    return ''.html_safe unless estimated

    content_tag('span', l(:label_serverless_costexplorer_estimated), class: 'badge badge-status-locked')
  end

  # A past day that Cost Explorer still marks as estimated. Today is not past.
  def serverless_costexplorer_estimated_day?(day, today)
    day['estimated'] == true && Date.parse(day['date']) < today
  end

  # The labels and datasets of the daily chart, oldest day first: the final
  # costs and the estimated ones as two stacked datasets, so that each day has
  # one bar. The estimated dataset only appears when a day is estimated.
  def serverless_costexplorer_daily_chart(days, today)
    values = days.map do |day|
      [BigDecimal(day['amount']).round(2).to_f, serverless_costexplorer_estimated_day?(day, today)]
    end
    datasets = [serverless_costexplorer_dataset(:label_serverless_costexplorer_unblended_cost, values, false)]
    if values.any?(&:last)
      datasets << serverless_costexplorer_dataset(:label_serverless_costexplorer_estimated, values, true)
    end
    { 'labels' => days.map { |day| format_date(Date.parse(day['date'])) }, 'datasets' => datasets }
  end

  # A dataset with the values of the days that are (or are not) estimated,
  # nil for the others.
  def serverless_costexplorer_dataset(label, values, estimated)
    { 'label' => l(label), 'data' => values.map { |value, est| est == estimated ? value : nil } }
  end

  # A tag value as Cost Explorer returns it ("redmine:instance$prod"), or
  # "(no tag)" for the costs without it.
  def serverless_costexplorer_tag_value(name, tag_key)
    value = name.to_s.delete_prefix("#{tag_key}$").delete_prefix('$')
    value.empty? ? l(:label_serverless_costexplorer_untagged) : value
  end
end
