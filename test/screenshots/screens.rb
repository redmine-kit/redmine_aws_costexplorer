# frozen_string_literal: true

require_relative '../test_helper'
require File.join(Redmine::Plugin.find(:redmine_aws).directory, 'test/support/redmine_aws/screenshot_case')

module RedmineAws
  module CostExplorer
    # The Cost Explorer tab of docs/README.md, with the breakdown by the tag
    # redmine:instance. Cost Explorer answers with SDK response stubs; the
    # services and the amounts are an example of a small Serverless account, not
    # recorded from one. The daily task fetched the data two hours ago; Cost
    # Explorer has not finalized yesterday yet. The first service is expanded to
    # its usage types, and the daily table keeps its first 7 days, to keep the
    # image short.
    class ScreenshotsTest < ScreenshotCase
      self.docs = File.expand_path('../../docs', __dir__)

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
      # The usage types of a service and their shares; one usage type otherwise.
      USAGE_TYPES = {
        'Amazon Relational Database Service' => { 'APN1-InstanceUsage:db.t4g.micro' => 0.82,
                                                  'APN1-RDS:GP3-Storage' => 0.18 },
        'Amazon Virtual Private Cloud' => { 'APN1-PublicIPv4:InUseAddress' => 1.0 },
        'Amazon Elastic Compute Cloud - Compute' => { 'APN1-BoxUsage:t4g.nano' => 1.0 },
        'AWS Lambda' => { 'APN1-Lambda-GB-Second-ARM' => 0.86, 'APN1-Request-ARM' => 0.14 }
      }.freeze
      # The share of each instance (the value of the tag) and of untagged costs.
      TAGS = { 'redmine' => 0.78, 'redmine-staging' => 0.14, '' => 0.08 }.freeze

      def setup
        super
        names = %w[REDMINE_COSTEXPLORER_ENABLED REDMINE_COSTEXPLORER_TAG_KEY]
        @saved = names.index_with { |name| ENV.fetch(name, nil) }
        ENV['REDMINE_COSTEXPLORER_ENABLED'] = 'true'
        ENV['REDMINE_COSTEXPLORER_TAG_KEY'] = TAG_KEY
        snapshot = AwsCostexplorerSnapshot.create!(requested_at: 2.hours.ago, requested_by: 'schedule')
        snapshot.fetch!(Fetcher.new(client: client, tag_key: TAG_KEY, today: today))
        snapshot.update_columns(fetched_at: 2.hours.ago)
      end

      def teardown
        @saved.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
      end

      def test_screens
        each_language do |language|
          visit '/admin/aws/costexplorer'
          assert_selector '#aws-costexplorer-daily'
          find('#aws-costexplorer-services tr.group span.expander', match: :first).click
          # Away from the expander, so that its tooltip is not in the image.
          find('h2', match: :first).hover
          # Chart.js sizes the canvas when it draws; then its animation ends.
          assert_selector '#aws-costexplorer-daily-chart[style*="box-sizing"]'
          sleep 1.5
          page.execute_script("document.querySelectorAll('#aws-costexplorer-daily > tbody > tr')" \
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
        client = ::Aws::CostExplorer::Client.new(stub_responses: true, region: 'us-east-1')
        client.stub_responses(:get_cost_and_usage, lambda { |context|
          group = context.params[:group_by]&.first
          if group.nil? then daily(context.params[:time_period])
          elsif group[:type] == 'TAG' then monthly(TAGS.to_h { |value, share| ["#{TAG_KEY}$#{value}", share * total] })
          else monthly(usage_types)
          end
        })
        client.stub_responses(:get_cost_forecast, total: money(total * (1 - month_share)))
        client
      end

      def total = SERVICES.values.sum

      # [service, usage type] => amount
      def usage_types
        SERVICES.each_with_object({}) do |(service, amount), groups|
          USAGE_TYPES.fetch(service, { 'APN1-Usage' => 1.0 }).each do |usage_type, share|
            groups[[service, usage_type]] = amount * share
          end
        end
      end

      def monthly(groups)
        start = today.beginning_of_month
        periods = [[start.prev_month, start, 1.0, false], [start, today + 1, month_share, true]]
        { results_by_time: periods.map do |from, to, share, estimated|
          { time_period: { start: from.iso8601, end: to.iso8601 }, estimated: estimated, total: {},
            groups: groups.map do |keys, amount|
              { keys: Array(keys), metrics: { 'UnblendedCost' => money(amount * share) } }
            end }
        end }
      end

      # About the same every day, a little more on weekdays; today is partial.
      def daily(time_period)
        days = (Date.parse(time_period[:start])...Date.parse(time_period[:end])).to_a
        daily_total = total / 30.0
        { results_by_time: days.map do |day|
          amount = daily_total * (day.on_weekday? ? 1.08 : 0.8) * (day == today ? 0.5 : 1)
          { time_period: { start: day.iso8601, end: (day + 1).iso8601 },
            total: { 'UnblendedCost' => money(amount) }, groups: [], estimated: day >= today - 1 }
        end }
      end
    end
  end
end
