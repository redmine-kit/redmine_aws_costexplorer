# frozen_string_literal: true

# One fetch of the costs from Cost Explorer: requested by the schedule (rake),
# by opening the tab when the data is old, or by an administrator
# ("Refresh"), then filled with the data or the error. The "Cost Explorer"
# tab shows the latest successful one.
class ServerlessCostexplorerSnapshot < ApplicationRecord
  SCHEDULE = 'schedule'
  VIEW = 'view'

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

    # A new request for the button or the tab, or nil when one was made within
    # the interval (RedmineServerlessCostexplorer::REFRESH_INTERVAL). Locking
    # the latest row keeps two pages opened at once from both requesting.
    def request_refresh!(by)
      transaction do
        order(requested_at: :desc, id: :desc).lock.first
        request!(by) if refresh_allowed?
      end
    end

    # Whether the latest successful data is older than the interval.
    def stale?
      fetched_at = latest&.fetched_at
      fetched_at.nil? || fetched_at + RedmineServerlessCostexplorer::REFRESH_INTERVAL <= Time.current
    end

    # A fetch may start when there was no request of any kind within the
    # interval. A request that never finished stops blocking after it.
    def refresh_allowed_at
      last = maximum(:requested_at)
      last && (last + RedmineServerlessCostexplorer::REFRESH_INTERVAL)
    end

    def refresh_allowed?
      allowed_at = refresh_allowed_at
      allowed_at.nil? || allowed_at <= Time.current
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

  # Fetches the costs and keeps them, or the error. Never raises, so that a
  # failed fetch is not retried (each request is charged).
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
