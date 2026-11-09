# frozen_string_literal: true

# One daily fetch of the costs from Cost Explorer (the rake task
# redmine_serverless_costexplorer:refresh), filled with the data or the
# error. The "Cost Explorer" tab shows the latest successful one.
class ServerlessCostexplorerSnapshot < ApplicationRecord
  SCHEDULE = 'schedule'

  serialize :data, coder: JSON

  scope :fetched, -> { where.not(fetched_at: nil).where(error: nil) }

  class << self
    def latest
      fetched.order(fetched_at: :desc).first
    end

    def last_request
      order(requested_at: :desc, id: :desc).first
    end

    def request!(by)
      create!(requested_at: Time.current, requested_by: by)
    end

    # Deletes the snapshots older than the given days, keeping the latest
    # successful one.
    def prune(days = RedmineServerlessCostexplorer::KEEP_DAYS)
      keep = latest&.id
      where(requested_at: ...days.to_i.days.ago).where.not(id: keep).delete_all
    end
  end

  def pending?
    fetched_at.nil? && error.nil?
  end

  # Fetches the costs and keeps them, or the error. Never raises; the rake
  # task reports the error.
  def fetch!(fetcher = RedmineServerlessCostexplorer::Fetcher.new)
    update!(data: fetcher.fetch, fetched_at: Time.current, requests: fetcher.requests)
  rescue StandardError => e
    update!(error: "#{e.class}: #{e.message}", requests: fetcher.requests)
    false
  end

  # Whether the error says that Cost Explorer could not be reached (no route
  # from the network, DNS or a timeout).
  def unreachable?
    error.to_s.start_with?('Seahorse::Client::NetworkingError', 'Net::OpenTimeout', 'Net::ReadTimeout',
                           'Errno::', 'SocketError')
  end
end
