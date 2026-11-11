# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module CostExplorer
    # The costs by the cost allocation tag on the "Cost Explorer" tab.
    class AwsCostexplorerTagsTest < Redmine::ControllerTest
      include RedmineAws::CostExplorer::TestHelper

      tests AwsCostexplorerController

      def setup
        @request.session[:user_id] = 1
      end

      def test_costs_by_the_tag
        fetched_snapshot(tag_key: 'redmine:instance')
        with_enabled(tag_key: 'redmine:instance') { get :index }

        assert_select 'h3', text: 'By cost allocation tag (redmine:instance)'
        assert_select '#aws-costexplorer-tags tbody tr', 3
        assert_select '#aws-costexplorer-tags tbody tr', text: /prod\s*6\.00 USD\s*19\.98 USD/
        assert_select '#aws-costexplorer-tags tbody tr', text: /\(no tag\)\s*0\.00 USD\s*2\.50 USD/
        assert_select '#aws-costexplorer-no-tag', 0
      end

      def test_a_notice_without_tag_data
        snapshot = fetched_snapshot(tag_key: 'redmine:instance')
        data = snapshot.data
        data['tags'] = [{ 'name' => 'redmine:instance$', 'this_month' => '7.51', 'previous_month' => '0.0' }]
        snapshot.update!(data: data)
        with_enabled(tag_key: 'redmine:instance') { get :index }

        assert_select '#aws-costexplorer-no-tag', text: /Activate it as a cost allocation tag/
      end

      # A tag value that reads like the "(no tag)" label is a tag value.
      def test_a_tag_value_like_the_untagged_label
        snapshot = fetched_snapshot(tag_key: 'redmine:instance')
        data = snapshot.data
        data['tags'] = [{ 'name' => 'redmine:instance$(no tag)', 'this_month' => '7.51', 'previous_month' => '0.0' }]
        snapshot.update!(data: data)
        with_enabled(tag_key: 'redmine:instance') { get :index }

        assert_select '#aws-costexplorer-no-tag', 0
        assert_select '#aws-costexplorer-tags tbody tr', 1
      end
    end
  end
end
