# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module Aws
    module Costexplorer
      # The "Cost Explorer" tab in Redmine Kit's new UI (redmine_kit_ui,
      # installed by bin/test's first run): the manifest it takes, and the
      # tab's JSON of the browser's session (kit requests), from a snapshot
      # fetched from the fixtures as the functional tests fetch it.
      class KitTest < Redmine::IntegrationTest
        include RedmineKit::Aws::Costexplorer::TestHelper
        include RedmineKit::Ui::TestHelper if Redmine::Plugin.installed?(:redmine_kit_ui)

        fixtures :users, :email_addresses

        def setup
          skip 'redmine_kit_ui is not installed (bin/test runs these with it)' unless kit_ui?
          User.current = nil
        end

        def teardown
          ActionController::Base.allow_forgery_protection = false
        end

        def kit_ui?
          Redmine::Plugin.installed?(:redmine_kit_ui)
        end

        test 'redmine_kit_ui takes the manifest: the tab Cost Explorer of the page AWS' do
          screen = assert_kit_manifest(:redmine_kit_aws_costexplorer).screens.sole
          assert_equal({ path: '/admin/aws/costexplorer', component: 'AwsCostexplorer', layout: 'admin',
                         menu_item: 'aws', tab: 'label_aws_costexplorer', position: 60 },
                       screen.slice(:path, :component, :layout, :menu_item, :tab, :position))
        end

        test "the tab's JSON: the stored costs, formatted as the page formats them" do
          fetched_snapshot(tag_key: 'project')
          headers = kit_session('admin', 'admin')
          with_enabled(tag_key: 'project') { get '/admin/aws/costexplorer.json', headers: headers }
          assert_response :success
          json = response.parsed_body
          assert_equal [true, nil, nil], json.values_at('enabled', 'failure', 'pending')
          costs = json['costs']
          assert_match(/\A[\d,]+\.\d{2} USD\z/, costs['totals']['this_month'])
          assert(costs['services'].all? { |row| row['this_month'].end_with?(' USD') })
          assert_equal costs['daily'].size, costs['chart']['labels'].size
          assert_equal 'project', costs['tag']['key']
        end

        test 'without the costs: no data; not on' do
          get '/admin/aws/costexplorer.json', headers: kit_session('admin', 'admin')
          assert_equal({ 'enabled' => false, 'failure' => nil, 'pending' => nil, 'updated' => nil, 'costs' => nil },
                       response.parsed_body)
        end

        test 'a failed fetch: the class of its error, never its message' do
          AwsCostexplorerSnapshot.create!(requested_at: 1.hour.ago,
                                          error: 'Seahorse::Client::NetworkingError: connect to 10.0.0.1 failed')
          with_enabled { get '/admin/aws/costexplorer.json', headers: kit_session('admin', 'admin') }
          failure = response.parsed_body['failure']
          assert_match(/Seahorse::Client::NetworkingError\)\z/, failure['text'])
          assert failure['unreachable']
          assert_not_includes response.body, '10.0.0.1'
        end

        test 'for system administrators only' do
          get '/admin/aws/costexplorer.json', headers: kit_session('jsmith')
          assert_response :forbidden
        end
      end
    end
  end
end
