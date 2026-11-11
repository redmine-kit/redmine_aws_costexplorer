# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module CostExplorer
    # The daily costs of the "Cost Explorer" tab: the table and the chart.
    class AwsCostexplorerDailyTest < Redmine::ControllerTest
      include RedmineAws::CostExplorer::TestHelper

      tests AwsCostexplorerController

      def setup
        @request.session[:user_id] = 1
      end

      def test_the_daily_table
        fetched_snapshot
        with_settings(date_format: '%Y-%m-%d') { with_enabled { get :index } }

        assert_select '#aws-costexplorer-daily > tbody > tr', 30
        assert_select '#aws-costexplorer-daily tbody tr:first-child', text: /2026-11-10\s*0\.30 USD/
        # Today is always estimated: no badge.
        assert_select '#aws-costexplorer-daily span.badge', 0
      end

      def test_the_daily_chart_markup
        fetched_snapshot
        with_enabled { get :index }

        assert_select 'div[data-controller="aws-costexplorer--daily"] canvas[role=img]'
        assert_select 'div[data-aws-costexplorer--daily-title-value]', 0
        assert_select 'script[type=module][src*="aws_costexplorer"]'
      end

      def test_the_daily_chart
        fetched_snapshot
        with_settings(date_format: '%Y-%m-%d') { with_enabled { get :index } }

        labels = daily_chart[:labels]
        assert_equal 30, labels.size
        assert_equal %w[2026-10-12 2026-11-10], [labels.first, labels.last]
      end

      def test_the_daily_chart_datasets
        fetched_snapshot
        with_enabled { get :index }

        chart = daily_chart
        assert_equal ['Unblended cost'], chart[:datasets].pluck('label')
        assert_equal [0.5, 0.8, 0.3], chart[:datasets].first['data'].values_at(0, 20, 29)
      end

      def test_an_estimated_past_day
        estimated_past_day
        with_settings(date_format: '%Y-%m-%d') { with_enabled { get :index } }

        assert_select '#aws-costexplorer-daily span.badge', 1
        # The badge is in the amount's cell, before the amount; the table has two columns.
        assert_select '#aws-costexplorer-daily tbody tr td.amount', text: /\AEstimated\s*0\.80 USD\z/
        assert_select '#aws-costexplorer-daily thead th', 2
      end

      def test_an_estimated_past_day_in_the_chart
        estimated_past_day
        with_enabled { get :index }

        final, estimated = daily_chart[:datasets]
        assert_equal ['Unblended cost', 'Estimated'], [final['label'], estimated['label']]
        # One bar a day: the day is in the estimated dataset only.
        assert_equal [nil, 0.8, 29], [final['data'][27], estimated['data'][27], estimated['data'].count(nil)]
      end

      private

      def estimated_past_day
        snapshot = fetched_snapshot
        data = snapshot.data
        data['daily'].find { |day| day['date'] == '2026-11-08' }['estimated'] = true
        snapshot.update!(data: data)
      end

      # The labels and datasets that the view passes to the chart.
      def daily_chart
        json = lambda { |target|
          JSON.parse(css_select("template[data-aws-costexplorer--daily-target=#{target}]").first.text)
        }
        { labels: json.call('labels'), datasets: json.call('datasets') }
      end
    end
  end
end
