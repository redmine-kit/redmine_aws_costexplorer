# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module CostExplorer
    class AwsCostexplorerControllerTest < Redmine::ControllerTest
      include RedmineAws::CostExplorer::TestHelper

      tests AwsCostexplorerController

      def setup
        @request.session[:user_id] = 1
      end

      def test_the_account_costs
        fetched_snapshot
        client = stub_cost_explorer
        with_enabled { with_fetcher_client(client) { get :index } }

        assert_response :success
        # This month is always estimated, and the last month is final.
        assert_select '#aws-costexplorer-summary span.badge', 0
        assert_select '#aws-costexplorer-tags', 0
        assert_not_includes response.body, 'Unblended costs from AWS Cost Explorer.'
        assert_select '#aws-costexplorer-updated', text: /Updated: .* \(daily\)/
        assert_select 'input[type=submit][value=Refresh]', 0
        # The page never calls Cost Explorer.
        assert_empty client.api_requests
      end

      # The totals are a section like the others: a heading, then a list with a header row.
      def test_the_totals_heading
        fetched_snapshot
        with_enabled { get :index }

        assert_equal 'Total', css_select('#content h3').first.text
      end

      def test_the_totals
        fetched_snapshot
        with_enabled { get :index }

        assert_equal(['This month', 'Month-end forecast', 'Last month'],
                     css_select('#aws-costexplorer-summary thead th.amount').map { |th| th.text.strip })
        assert_equal(['7.51 USD', '22.20 USD', '22.48 USD'],
                     css_select('#aws-costexplorer-summary tbody td.amount').map { |td| td.text.strip })
      end

      # Each service is a collapsed group of its usage types.
      def test_the_services_with_their_usage_types
        fetched_snapshot
        with_enabled { get :index }

        assert_select '#aws-costexplorer-services tbody tr.group', 4
        # Redmine's own expander of grouped lists (issues/_list.html.erb), nothing more.
        assert_select '#aws-costexplorer-services tr.group span.expander[onclick="toggleRowGroup(this);"]', 4
        assert_select '#aws-costexplorer-services span.expander[onkeydown]', 0
        assert_select '#aws-costexplorer-services span.expander[role]', 0
        assert_select '#aws-costexplorer-services tr.idnt-1[style*="display: none"]', 5
        assert_select '#aws-costexplorer-services tr.idnt-1 td.name', text: 'APN1-RDS:GP3-Storage'
        assert_select '#aws-costexplorer-services tbody tr:first-child',
                      text: /Amazon Relational Database Service\s*7\.10 USD\s*20\.50 USD/
      end

      def test_an_estimated_last_month
        snapshot = fetched_snapshot
        data = snapshot.data
        data['previous_month']['estimated'] = true
        snapshot.update!(data: data)
        with_enabled { get :index }

        assert_select '#aws-costexplorer-summary span.badge', 1
        # In the amount's cell, before the amount.
        assert_select '#aws-costexplorer-summary td.amount', text: /\AEstimated\s*22\.48 USD\z/
        assert_select '#aws-costexplorer-summary td.amount span.badge.badge-status-locked', text: 'Estimated'
      end

      def test_disabled
        fetched_snapshot
        with_env('REDMINE_COSTEXPLORER_ENABLED' => nil) { get :index }

        assert_select 'p.warning', text: /REDMINE_COSTEXPLORER_ENABLED/
      end

      def test_no_data_yet
        with_enabled { get :index }

        assert_response :success
        assert_select 'p.nodata'
        assert_equal 0, AwsCostexplorerSnapshot.count
      end

      def test_no_refresh_route
        assert_raises(ActionController::UrlGenerationError) { post :refresh }
      end

      def test_only_administrators
        { 2 => :forbidden, nil => :redirect }.each do |user_id, status|
          @request.session[:user_id] = user_id
          get :index

          assert_response status, "user #{user_id.inspect}"
        end
      end
    end
  end
end
