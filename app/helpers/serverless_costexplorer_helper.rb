# frozen_string_literal: true

require 'bigdecimal'

module ServerlessCostexplorerHelper
  # "1,234.57 USD"
  def serverless_costexplorer_amount(value, currency)
    return '-' if value.nil?

    "#{number_with_delimiter(format('%.2f', BigDecimal(value.to_s)))} #{currency}"
  end

  # A bar the width of the value's share of the largest value.
  def serverless_costexplorer_bar(value, max, title)
    max = BigDecimal(max.to_s)
    percent = max.positive? ? (BigDecimal(value.to_s) * 100 / max).floor.clamp(0, 100) : 0
    progress_bar(percent, titles: [title])
  end

  def serverless_costexplorer_estimated(estimated)
    return ''.html_safe unless estimated

    content_tag('em', l(:label_serverless_costexplorer_estimated), class: 'info')
  end

  # A tag value as Cost Explorer returns it ("redmine:instance$prod"), or
  # "(no tag)" for the costs without it.
  def serverless_costexplorer_tag_value(name, tag_key)
    value = name.to_s.delete_prefix("#{tag_key}$").delete_prefix('$')
    value.empty? ? l(:label_serverless_costexplorer_untagged) : value
  end
end
