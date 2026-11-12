# frozen_string_literal: true

require_relative '../test_helper'

module RedmineAws
  module CostExplorer
    # The plugin's locale files have the same keys in every language.
    class LocalesTest < ActiveSupport::TestCase
      LANGUAGES = %w[en ja].freeze

      def keys(language)
        path = File.join(Redmine::Plugin.find(:redmine_aws_costexplorer).directory, "config/locales/#{language}.yml")
        YAML.safe_load_file(path).fetch(language).keys.sort
      end

      def test_every_language_has_the_same_keys
        assert_equal keys('en'), keys('ja')
      end
    end
  end
end
