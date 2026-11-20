# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../charges_support'

module RedmineKit
  module Aws
    module Costexplorer
      # The settings of an AWS source that Redmine Kit Charges' form may save:
      # their shape only (no request to AWS), and a new external ID per source.
      class ChargesProviderSettingsTest < ActiveSupport::TestCase
        include ChargesSupport

        VIEW = ChargesSupport::VIEW

        def errors(settings)
          source = Source.new(settings)
          ChargesProvider.new.validate(source)
          source.errors
        end

        test "the charges' vendor (請求元) is AWS" do
          assert_equal 'AWS', ChargesProvider.vendor
        end

        test 'each new source has its own external ID' do
          ids = Array.new(2) { ChargesProvider.default_settings['external_id'] }

          assert_equal ids.uniq, ids
          assert_match(/\Aredmine-kit-\h{8}-\h{4}-/, ids.first)
        end

        [
          ['an unknown method', { 'method' => 'keys' }],
          ['a billing view without its ARN', { 'method' => 'billing_view' }],
          ['a billing view ARN of another service', { 'method' => 'billing_view',
                                                      'billing_view_arn' => 'arn:aws:s3:::b' }],
          ['a billing view ARN with a newline', { 'method' => 'billing_view', 'billing_view_arn' => "#{VIEW}\nx" }],
          ['a role without its ARN', { 'method' => 'role' }],
          ['a role ARN of a user', { 'method' => 'role', 'role_arn' => 'arn:aws:iam::222222222222:user/me' }],
          ['a role ARN with a short account', { 'method' => 'role', 'role_arn' => 'arn:aws:iam::2222:role/x' }],
          ['an unknown metric', { 'metric' => 'BlendedCost' }],
          ['a tag key with $', { 'tag_key' => 'project$x' }]
        ].each do |name, settings|
          test("#{name} is refused") { assert_predicate errors(settings), :any? }
        end

        [
          ['this account', {}],
          ['a billing view', { 'method' => 'billing_view', 'billing_view_arn' => VIEW }],
          ['a billing view in another partition', { 'method' => 'billing_view',
                                                    'billing_view_arn' => VIEW.sub('aws:', 'aws-cn:') }],
          ['a role with a path', { 'method' => 'role', 'role_arn' => 'arn:aws:iam::222222222222:role/kit/reader' }],
          ['the amortized cost and a tag key', { 'metric' => 'AmortizedCost', 'tag_key' => 'redmine-kit:instance' }]
        ].each do |name, settings|
          test("#{name} is accepted") { assert_empty errors(settings) }
        end
      end
    end
  end
end
