# frozen_string_literal: true

# One fetch of the costs from Cost Explorer: requested by the schedule (rake)
# or by an administrator ("Refresh"), then filled with the data or the error.
# The "Costs" tab shows the latest successful one.
class ServerlessCostSnapshot < ApplicationRecord
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

    # The "Refresh" button may start a fetch when there was no request of any
    # kind within the interval.
    def refresh_allowed_at
      last = maximum(:requested_at)
      last && (last + RedmineServerlessCost::REFRESH_INTERVAL)
    end

    def refresh_allowed?
      allowed_at = refresh_allowed_at
      allowed_at.nil? || allowed_at <= Time.current
    end

    # Deletes the snapshots older than the given days, keeping the latest
    # successful one.
    def prune(days = RedmineServerlessCost::KEEP_DAYS)
      keep = latest&.id
      where(requested_at: ...days.to_i.days.ago).where.not(id: keep).delete_all
    end
  end

  def pending?
    fetched_at.nil? && error.nil?
  end

  # Fetches the costs and keeps them, or the error. Never raises, so that a
  # failed fetch is not retried (each request is charged).
  def fetch!(fetcher = RedmineServerlessCost::Fetcher.new)
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
