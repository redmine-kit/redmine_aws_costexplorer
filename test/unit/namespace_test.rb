# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'

module RedmineAws
  module CostExplorer
    # The plugin's code is under the RedmineAws namespace of redmine_aws
    # (lib/redmine_aws/costexplorer.rb is RedmineAws::CostExplorer, by the
    # inflection that redmine_aws adds), which Redmine's code loader
    # (Zeitwerk) spreads over both plugins' lib/. Checked in new processes, as
    # at start-up.
    class NamespaceTest < ActiveSupport::TestCase
      def rails(*)
        out, status = Open3.capture2e({ 'RAILS_ENV' => 'test' }, 'bin/rails', *, chdir: Rails.root.to_s)
        assert status.success?, out
        out
      end

      def test_zeitwerk_loads_every_file
        assert_includes rails('zeitwerk:check'), 'All is good!'
      end

      def test_both_plugins_start
        script = 'print RedmineAws::VERSION, " ", RedmineAws::CostExplorer::VERSION, " ", ' \
                 'RedmineAws::CostExplorer::Fetcher.name, " ", RedmineAws::Admin.tabs.map(&:name).join(",")'

        assert_equal "#{RedmineAws::VERSION} #{VERSION} RedmineAws::CostExplorer::Fetcher status,costexplorer",
                     rails('runner', script).lines.last.to_s.strip
      end
    end
  end
end
