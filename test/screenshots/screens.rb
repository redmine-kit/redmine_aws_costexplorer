# frozen_string_literal: true

require_relative 'screenshot_case'

# The Cost Explorer tab of docs/README.md, with the breakdown by the tag
# redmine:instance. Cost Explorer answers with SDK response stubs; the
# services and the amounts are an example of a small Serverless account, not
# recorded from one. The daily task fetched the data two hours ago. The daily
# table keeps its first 7 days, to keep the image short.
class RedmineServerlessCostexplorerScreens < ScreenshotCase
  TAG_KEY = 'redmine:instance'
  # Last month's cost of each service, in USD.
  SERVICES = {
    'Amazon Relational Database Service' => 15.42,
    'Amazon Virtual Private Cloud' => 3.65,
    'Amazon Elastic Compute Cloud - Compute' => 3.07,
    'AWS Lambda' => 2.18,
    'AmazonCloudWatch' => 1.35,
    'EC2 - Other' => 0.96,
    'AWS Cost Explorer' => 0.93,
    'Amazon Route 53' => 0.51,
    'Amazon Simple Storage Service' => 0.42,
    'Amazon Simple Email Service' => 0.31,
    'Amazon GuardDuty' => 0.12,
    'Amazon EC2 Container Registry (ECR)' => 0.08,
    'Amazon Simple Queue Service' => 0.02
  }.freeze
  # The share of each instance (the value of the tag) and of untagged costs.
  TAGS = { 'redmine' => 0.78, 'redmine-staging' => 0.14, '' => 0.08 }.freeze

  def setup
    super
    @saved = %w[REDMINE_COSTEXPLORER_ENABLED REDMINE_COSTEXPLORER_TAG_KEY].index_with { |name| ENV.fetch(name, nil) }
    ENV['REDMINE_COSTEXPLORER_ENABLED'] = 'true'
    ENV['REDMINE_COSTEXPLORER_TAG_KEY'] = TAG_KEY
    snapshot = ServerlessCostexplorerSnapshot.create!(requested_at: 2.hours.ago, requested_by: 'schedule')
    snapshot.fetch!(RedmineServerlessCostexplorer::Fetcher.new(client: client, tag_key: TAG_KEY, today: today))
    snapshot.update_columns(fetched_at: 2.hours.ago)
  end

  def teardown
    @saved.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end

  def test_screens
    each_language do |language|
      visit '/admin/serverless/costexplorer'
      assert_selector '#serverless-costexplorer-daily'
      page.execute_script("document.querySelectorAll('#serverless-costexplorer-daily > tbody > tr')" \
                          ".forEach((row, index) => { if (index >= 7) row.style.display = 'none'; })")
      shoot 'costexplorer', language
    end
  end

  private

  def today = Time.now.utc.to_date

  # The part of this month so far, for this month's costs.
  def month_share = (today.day - 0.5) / today.end_of_month.day

  def money(amount) = { amount: format('%.4f', amount), unit: 'USD' }

  def client
    client = Aws::CostExplorer::Client.new(stub_responses: true, region: 'us-east-1')
    client.stub_responses(:get_cost_and_usage, lambda { |context|
      group = context.params[:group_by]&.first
      if group.nil? then daily(context.params[:time_period])
      elsif group[:type] == 'TAG' then monthly(TAGS.to_h { |value, share| ["#{TAG_KEY}$#{value}", share * total] })
      else monthly(SERVICES)
      end
    })
    client.stub_responses(:get_cost_forecast, total: money(total * (1 - month_share)))
    client
  end

  def total = SERVICES.values.sum

  def monthly(groups)
    start = today.beginning_of_month
    periods = [[start.prev_month, start, 1.0, false], [start, today + 1, month_share, true]]
    { results_by_time: periods.map do |from, to, share, estimated|
      { time_period: { start: from.iso8601, end: to.iso8601 }, estimated: estimated, total: {},
        groups: groups.map { |key, amount| { keys: [key], metrics: { 'UnblendedCost' => money(amount * share) } } } }
    end }
  end

  # About the same every day, a little more on weekdays; today is partial.
  def daily(time_period)
    days = (Date.parse(time_period[:start])...Date.parse(time_period[:end])).to_a
    daily_total = total / 30.0
    { results_by_time: days.map do |day|
      amount = daily_total * (day.on_weekday? ? 1.08 : 0.8) * (day == today ? 0.5 : 1)
      { time_period: { start: day.iso8601, end: (day + 1).iso8601 }, estimated: day == today,
        total: { 'UnblendedCost' => money(amount) }, groups: [] }
    end }
  end
end
