# frozen_string_literal: true

require 'bigdecimal'

module AwsCostexplorerHelper
  # "1,234.57 USD"
  def aws_costexplorer_amount(value, currency)
    return '-' if value.nil?

    "#{number_with_delimiter(format('%.2f', BigDecimal(value.to_s)))} #{currency}"
  end

  # The "Estimated" badge, for a closed period whose costs Cost Explorer has
  # not finalized yet. Periods still running (this month, today) are always
  # estimated, so they carry no badge.
  def aws_costexplorer_estimated(estimated)
    return ''.html_safe unless estimated

    content_tag('span', l(:label_aws_costexplorer_estimated), class: 'badge badge-status-locked')
  end

  # A past day that Cost Explorer still marks as estimated. Today is not past.
  def aws_costexplorer_estimated_day?(day, today)
    day['estimated'] == true && Date.parse(day['date']) < today
  end

  # The labels and datasets of the daily chart, oldest day first: the final
  # costs and the estimated ones as two stacked datasets, so that each day has
  # one bar. The estimated dataset only appears when a day is estimated.
  def aws_costexplorer_daily_chart(days, today)
    values = days.map do |day|
      [BigDecimal(day['amount']).round(2).to_f, aws_costexplorer_estimated_day?(day, today)]
    end
    datasets = [aws_costexplorer_dataset(:label_aws_costexplorer_unblended_cost, values, false)]
    datasets << aws_costexplorer_dataset(:label_aws_costexplorer_estimated, values, true) if values.any?(&:last)
    { 'labels' => days.map { |day| format_date(Date.parse(day['date'])) }, 'datasets' => datasets }
  end

  # A dataset with the values of the days that are (or are not) estimated,
  # nil for the others.
  def aws_costexplorer_dataset(label, values, estimated)
    { 'label' => l(label), 'data' => values.map { |value, est| est == estimated ? value : nil } }
  end

  # A tag value as Cost Explorer returns it ("redmine:instance$prod"), or
  # "(no tag)" for the costs without it.
  def aws_costexplorer_tag_value(name, tag_key)
    return l(:label_aws_costexplorer_untagged) if aws_costexplorer_untagged?(name, tag_key)

    aws_costexplorer_tag(name, tag_key)
  end

  # Whether a group holds the costs without the tag: Cost Explorer returns
  # them with an empty value ("redmine:instance$").
  def aws_costexplorer_untagged?(name, tag_key)
    aws_costexplorer_tag(name, tag_key).empty?
  end

  # Whether no costs carry the tag yet (it is not activated as a cost
  # allocation tag).
  def aws_costexplorer_no_tag_data?(costs)
    costs['tags'].to_a.all? { |row| aws_costexplorer_untagged?(row['name'], costs['tag_key']) }
  end

  # The class of a stored error ("<class>: <message>"): the page shows the
  # class, and the message stays in the database.
  def aws_costexplorer_error_name(error)
    error.to_s.sub(/: .*/m, '')
  end

  private

  def aws_costexplorer_tag(name, tag_key)
    name.to_s.delete_prefix("#{tag_key}$").delete_prefix('$')
  end
end
