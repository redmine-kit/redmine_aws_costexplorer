# frozen_string_literal: true

require_relative '../test_helper'
require 'rake'

module RedmineKit
  module Aws
    module Costexplorer
      # The rake task redmine_kit:aws:costexplorer:prune, with DAYS as
      # Serverless's daily schedule passes it.
      class PruneTaskTest < ActiveSupport::TestCase
        include RedmineKit::Aws::Costexplorer::TestHelper

        setup do
          Rails.application.load_tasks unless Rake::Task.task_defined?('redmine_kit:aws:costexplorer:prune')
          # The latest successful fetch is old too: prune keeps it whatever DAYS is.
          snapshot(:latest, 200.days.ago, fetched: true)
          snapshot(:old, 91.days.ago)
          snapshot(:month, 31.days.ago)
          snapshot(:new, 1.hour.ago)
        end

        def snapshot(name, at, fetched: false)
          AwsCostexplorerSnapshot.create!(requested_at: at, error: (name.to_s unless fetched),
                                          fetched_at: (at if fetched), data: ({} if fetched))
        end

        # The output, or the SystemExit of abort.
        def rake_prune(env)
          task = Rake::Task['redmine_kit:aws:costexplorer:prune'].tap(&:reenable)
          with_env({ 'DAYS' => nil }.merge(env)) { capture_io { task.invoke } }
        end

        def kept
          AwsCostexplorerSnapshot.order(:requested_at).map { |s| s.error || 'latest' }
        end

        def test_the_task_is_in_the_redmine_kit_namespace
          assert_empty Rake::Task['redmine_kit:aws:costexplorer:prune'].arg_names
          assert_empty Rake::Task.tasks.map(&:name).grep(/\Aredmine_kit_aws_costexplorer:/)
        end

        def test_without_days_keeps_90_days_and_the_latest_successful_fetch
          out, = rake_prune({})

          assert_equal "deleted 1 snapshot(s) older than 90 days\n", out
          assert_equal %w[latest month new], kept
        end

        def test_days_sets_the_number_of_days
          out, = rake_prune('DAYS' => '30')

          assert_equal "deleted 2 snapshot(s) older than 30 days\n", out
          assert_equal %w[latest new], kept
        end

        def test_an_invalid_days_aborts_and_deletes_nothing
          ['', '0', '-1', 'abc', '30abc', '1.5', ' 30', "30\n", '100000'].each do |value|
            error = assert_raises(SystemExit, "DAYS=#{value.inspect}") { rake_prune('DAYS' => value) }

            assert_not error.success?
            assert_equal %w[latest old month new], kept, "DAYS=#{value.inspect}"
          end
        end

        def test_the_message_of_an_invalid_days
          assert_equal ['Invalid DAYS abc given. The value must be an integer from 1 to 99999.', false],
                       Tasks.prune('DAYS' => 'abc')
        end
      end
    end
  end
end
