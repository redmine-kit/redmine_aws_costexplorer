# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module CostExplorer
    # How init.rb registers the plugin.
    class PluginRegistrationTest < ActiveSupport::TestCase
      INIT = File.expand_path('../../init.rb', __dir__)

      # Without redmine_aws, Redmine must stop at the requirement with its
      # own message ("requires the redmine_aws plugin"), before any line
      # needs the RedmineAws namespace (a NameError otherwise).
      def test_the_requirement_on_redmine_aws_comes_first
        block = File.read(INIT)[/^Redmine::Plugin.register :redmine_aws_costexplorer do\n(.*?)^end/m, 1]
        statements = block.lines.map(&:strip).reject { |line| line.empty? || line.start_with?('#') }

        assert_match(/\Arequires_redmine_plugin :redmine_aws,/, statements.first)
      end

      # MySQL's TEXT holds 64 KB; the data column holds 16 MB there, as
      # Redmine's own text columns do.
      def test_the_data_column_holds_16_megabytes_on_mysql
        Redmine::Database.stubs(:mysql?).returns(true)

        assert_equal 16.megabytes, migration_columns[:data][:limit]
      end

      private

      # The options of each column that the migration creates.
      def migration_columns
        require File.expand_path('../../db/migrate/001_create_aws_costexplorer_snapshots', __dir__)
        columns = {}
        table = column_recorder(columns)
        migration = CreateAwsCostexplorerSnapshots.new
        migration.stubs(:create_table).yields(table)
        migration.stubs(:add_index)
        migration.change
        columns
      end

      # A table definition that keeps the options of each column in columns.
      def column_recorder(columns)
        Object.new.tap do |table|
          %i[datetime text integer].each do |type|
            table.define_singleton_method(type) { |name, **options| columns[name] = options }
          end
        end
      end
    end
  end
end
