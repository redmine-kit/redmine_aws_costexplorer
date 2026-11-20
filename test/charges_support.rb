# frozen_string_literal: true

module RedmineKit
  module Aws
    module Costexplorer
      # Shared setup of the tests of Redmine Kit Charges' provider: a source
      # (anything with settings, errors, tag_split_scopes and statement_scopes, as
      # redmine_kit_charges' ChargeSource is), and a Cost Explorer client of SDK
      # stubs that answers by the request's grouping and records the requests.
      module ChargesSupport
        WINDOW = Date.new(2026, 10, 1)..TestHelper::TODAY
        VIEW = 'arn:aws:billing::111111111111:billingview/custom-1a2b3c4d'
        ROLE = 'arn:aws:iam::222222222222:role/redmine-kit-cost-reader'
        ACCOUNT_NAMES = [{ 'Value' => '111111111111', 'Attributes' => { 'description' => 'prod' } }].freeze

        # A source as redmine_kit_charges' ChargeSource answers the provider.
        class Source
          include ActiveModel::Validations

          attr_accessor :settings, :tag_split_scopes, :statement_scopes

          def initialize(settings, tag_split_scopes = [], statement_scopes = [])
            @settings = ChargesProvider.default_settings.merge(settings)
            @tag_split_scopes = tag_split_scopes
            @statement_scopes = statement_scopes
          end
        end

        def group(keys, amount)
          { 'Keys' => keys, 'Metrics' => { 'UnblendedCost' => { 'Amount' => amount, 'Unit' => 'USD' } } }
        end

        def day(date, groups, estimated: false)
          { 'TimePeriod' => { 'Start' => date.iso8601, 'End' => (date + 1).iso8601 }, 'Total' => {},
            'Groups' => groups, 'Estimated' => estimated }
        end

        def usage_results
          [day(Date.new(2026, 11, 9),
               [group(%w[111111111111 AmazonS3], '1.5'), group(%w[222222222222 AmazonEC2], '3')]),
           day(TestHelper::TODAY, [group(%w[111111111111 AmazonS3], '0.5')], estimated: true)]
        end

        def adjustment_results
          [{ 'TimePeriod' => { 'Start' => '2026-11-01', 'End' => '2026-11-11' }, 'Total' => {}, 'Estimated' => true,
             'Groups' => [group(%w[111111111111 Credit], '-2'), group(%w[111111111111 Tax], '0.3')] }]
        end

        def tag_results
          [day(Date.new(2026, 11, 9),
               [group(['project$blue', 'AmazonEC2'], '2'), group(['project$', 'AmazonEC2'], '1')])]
        end

        # A statement's line: the amount, and the quantity with its unit
        # (none when Cost Explorer gives none).
        def line(keys, amount, quantity = nil, unit = nil)
          group(keys, amount).tap do |line|
            line['Metrics']['UsageQuantity'] = { 'Amount' => quantity, 'Unit' => unit } if quantity
          end
        end

        # The statement in two pages: October, then this month so far.
        def statement_pages
          [[{ 'TimePeriod' => { 'Start' => '2026-10-01', 'End' => '2026-11-01' }, 'Total' => {}, 'Estimated' => false,
              'Groups' => [line(%w[AmazonEC2 APN1-BoxUsage:t4g.small], '12.5', '744', 'Hrs')] }],
           [{ 'TimePeriod' => { 'Start' => '2026-11-01', 'End' => '2026-11-11' }, 'Total' => {}, 'Estimated' => true,
              'Groups' => [line(%w[AmazonS3 APN1-Requests-Tier1], '0.25', '50000', 'N/A'),
                           line(%w[AmazonS3 APN1-TimedStorage-ByteHrs], '0.1')] }]]
        end

        # The answer of a GetCostAndUsage request, by its grouping.
        def answer(params)
          keys = params[:group_by].pluck(:key)
          return statement_answer(params) if keys == %w[SERVICE USAGE_TYPE]

          results = { %w[LINKED_ACCOUNT SERVICE] => usage_results,
                      %w[LINKED_ACCOUNT RECORD_TYPE] => adjustment_results }.fetch(keys) { tag_results }
          attributes = keys.first == 'LINKED_ACCOUNT' ? ACCOUNT_NAMES : []
          { 'ResultsByTime' => results, 'DimensionValueAttributes' => attributes }.to_json
        end

        def statement_answer(params)
          first, second = statement_pages
          answer = if params[:next_page_token]
                     { 'ResultsByTime' => second }
                   else
                     { 'ResultsByTime' => first, 'NextPageToken' => 'page-2' }
                   end
          answer.merge('DimensionValueAttributes' => []).to_json
        end

        # A client recording each request's parameters in requests; the first
        # `throttled` GetCostAndUsage requests answer LimitExceededException.
        def charges_client(requests, throttled: 0)
          client = ::Aws::CostExplorer::Client.new(stub_responses: true, region: 'us-east-1')
          client.stub_responses(:get_cost_and_usage, lambda { |context|
            requests << context.params
            next 'LimitExceededException' if (throttled -= 1) >= 0

            http_body(answer(context.params))
          })
          client.stub_responses(:get_cost_forecast, forecast_answer(requests))
          client
        end

        def forecast_answer(requests)
          lambda { |context|
            requests << context.params
            http_body(fixture('forecast'))
          }
        end

        # [result, requests] of a fetch of a source with the settings.
        def charges_fetch(settings = {}, split: [], statement: [], throttled: 0)
          fetch_source(Source.new(settings, split, statement), throttled: throttled)
        end

        def fetch_source(source, throttled: 0, window: WINDOW)
          requests = []
          provider = ChargesProvider.new(client: charges_client(requests, throttled: throttled), sleeper: ->(_s) {})
          [with_enabled { provider.fetch(source, window: window, today: TestHelper::TODAY) }, requests]
        end
      end
    end
  end
end
