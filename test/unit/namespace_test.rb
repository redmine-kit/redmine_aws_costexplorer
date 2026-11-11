# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'

module RedmineAws
  module CostExplorer
    # The plugin's code is under the RedmineAws namespace of redmine_aws
    # (lib/redmine_aws/costexplorer.rb is RedmineAws::CostExplorer, by the
    # inflection that redmine_aws adds). Checked in a new process, as at
    # start-up.
    class NamespaceTest < ActiveSupport::TestCase
      def test_zeitwerk_loads_every_file
        out, status = Open3.capture2e({ 'RAILS_ENV' => 'test' }, 'bin/rails', 'zeitwerk:check',
                                      chdir: Rails.root.to_s)

        assert status.success?, out
        assert_includes out, 'All is good!'
      end
    end
  end
end
