# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module CostExplorer
    class AwsCostexplorerHelperTest < Redmine::HelperTest
      include AwsCostexplorerHelper

      TAG = 'redmine:instance'

      def test_tag_values
        { "#{TAG}$prod" => 'prod', "#{TAG}$" => '(no tag)', '$' => '(no tag)',
          "#{TAG}$(no tag)" => '(no tag)' }.each do |name, value|
          assert_equal value, aws_costexplorer_tag_value(name, TAG), name
        end
      end

      # A tag value that reads like the "(no tag)" label is still a value.
      def test_untagged_is_the_empty_value
        { "#{TAG}$" => true, '$' => true, nil => true, "#{TAG}$prod" => false,
          "#{TAG}$(no tag)" => false }.each do |name, untagged|
          assert_equal untagged, aws_costexplorer_untagged?(name, TAG), name.inspect
        end
      end

      def test_no_tag_data
        rows = ->(*names) { { 'tag_key' => TAG, 'tags' => names.map { |name| { 'name' => name } } } }

        assert aws_costexplorer_no_tag_data?(rows.call)
        assert aws_costexplorer_no_tag_data?(rows.call("#{TAG}$"))
        assert_not aws_costexplorer_no_tag_data?(rows.call("#{TAG}$", "#{TAG}$prod"))
        assert_not aws_costexplorer_no_tag_data?(rows.call("#{TAG}$(no tag)"))
      end

      def test_today_of_a_snapshot
        fetched = Time.utc(2026, 11, 10, 23, 30)

        assert_equal Date.new(2026, 11, 9), aws_costexplorer_today(snapshot({ 'today' => '2026-11-09' }, at: fetched))
        assert_equal Date.new(2026, 11, 10), aws_costexplorer_today(snapshot(at: fetched))
      end

      def test_the_last_days
        days = (1..35).map { |day| { 'date' => format('2026-10-%02d', day) } }

        assert_equal Fetcher::DAYS, aws_costexplorer_days('daily' => days).size
        assert_equal '2026-10-35', aws_costexplorer_days('daily' => days).last['date']
        assert_empty aws_costexplorer_days({})
      end

      def test_error_name
        error = "Aws::CostExplorer::Errors::AccessDeniedException: User: arn:...\nmore"

        assert_equal 'Aws::CostExplorer::Errors::AccessDeniedException', aws_costexplorer_error_name(error)
        assert_equal 'Aws::CostExplorer::Errors::DataUnavailableException',
                     aws_costexplorer_error_name('Aws::CostExplorer::Errors::DataUnavailableException')
        assert_equal '', aws_costexplorer_error_name(nil)
      end

      private

      def snapshot(data = {}, at:)
        AwsCostexplorerSnapshot.new(data: data, fetched_at: at)
      end
    end
  end
end
