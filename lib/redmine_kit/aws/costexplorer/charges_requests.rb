# frozen_string_literal: true

module RedmineKit
  module Aws
    module Costexplorer
      # The Cost Explorer requests of one source of Redmine Kit Charges
      # (ChargesProvider): with the source's credentials (a role's, through
      # AssumeRole with its external ID, or the SDK's own), its billing view on
      # every request, each request counted (each is charged), and retried
      # after a wait while Cost Explorer throttles (LimitExceededException).
      class ChargesRequests
        # The seconds waited before each retry of a throttled request.
        BACKOFF = [2, 4, 8, 16].freeze
        # AssumeRole's session: the shortest STS allows.
        SESSION_SECONDS = 900
        SESSION_NAME = 'redmine-kit-charges'

        attr_reader :count

        def initialize(settings, client: nil, sts_client: nil, sleeper: ->(seconds) { sleep(seconds) })
          @settings = settings
          @client = client
          @sts_client = sts_client
          @sleeper = sleeper
          @count = 0
        end

        def billing_view
          @settings['billing_view_arn'] if @settings['method'] == 'billing_view'
        end

        # Every page of a GetCostAndUsage request, as [result, dimension values].
        def each_result(**params)
          token = nil
          results = []
          loop do
            response = send_request(:get_cost_and_usage, **params, next_page_token: token)
            attributes = response.dimension_value_attributes.to_a
            response.results_by_time.each { |result| results << [result, attributes] }
            break if (token = response.next_page_token).blank?
          end
          results
        end

        def send_request(operation, **params)
          attempt = 0
          begin
            @count += 1
            client.public_send(operation, params.merge(billing_view_arn: billing_view).compact)
          rescue ::Aws::CostExplorer::Errors::LimitExceededException
            raise if attempt >= BACKOFF.size

            @sleeper.call(BACKOFF[attempt])
            attempt += 1
            retry
          end
        end

        # The role's temporary credentials for a role source (renewed by the
        # SDK if a fetch outlasts the session), else nil: the SDK's own chain.
        def credentials
          return unless @settings['method'] == 'role'

          ::Aws::AssumeRoleCredentials.new(
            client: @sts_client || Aws.client(::Aws::STS::Client, http_open_timeout: 5, http_read_timeout: 30),
            role_arn: @settings['role_arn'], external_id: @settings['external_id'],
            role_session_name: SESSION_NAME, duration_seconds: SESSION_SECONDS
          )
        end

        private

        def client
          @client ||= Aws.client(::Aws::CostExplorer::Client, region: Fetcher::REGION, credentials: credentials,
                                                              http_open_timeout: 5, http_read_timeout: 30,
                                                              retry_limit: 2)
        end
      end
    end
  end
end
