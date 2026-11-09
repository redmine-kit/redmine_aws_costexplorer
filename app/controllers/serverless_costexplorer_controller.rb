# frozen_string_literal: true

# The "Cost Explorer" tab (docs/README.md#what-the-tab-shows). It shows the
# latest snapshot and never calls Cost Explorer. Opening it when the data is
# older than an hour, or "Refresh", queues a fetch, at most once per
# RedmineServerlessCostexplorer::REFRESH_INTERVAL.
class ServerlessCostexplorerController < ApplicationController
  layout 'admin'
  self.main_menu = false
  menu_item :serverless

  before_action :require_admin

  helper :serverless_costexplorer

  def index
    @enabled = RedmineServerlessCostexplorer.enabled?
    refresh_on_view if @enabled && ServerlessCostexplorerSnapshot.stale?
    @snapshot = ServerlessCostexplorerSnapshot.latest
    @last_request = ServerlessCostexplorerSnapshot.last_request
    @tag_key = RedmineServerlessCostexplorer.tag_key
  end

  def refresh
    return render_403 unless RedmineServerlessCostexplorer.enabled?

    snapshot = ServerlessCostexplorerSnapshot.request_refresh!(User.current.login)
    if snapshot.nil?
      flash[:error] = l(:error_serverless_costexplorer_refresh_too_soon,
                        time: format_time(ServerlessCostexplorerSnapshot.refresh_allowed_at))
    elsif (error = enqueue(snapshot))
      flash[:error] = error
    else
      flash[:notice] = l(:notice_serverless_costexplorer_refresh_started)
    end
    redirect_to action: 'index'
  end

  private

  # The data is older than the interval: queue a fetch, unless one was
  # requested within the interval. The page shows the stored data meanwhile.
  def refresh_on_view
    snapshot = ServerlessCostexplorerSnapshot.request_refresh!(ServerlessCostexplorerSnapshot::VIEW)
    enqueue(snapshot) if snapshot
  end

  # Queues the job; returns the error text when it could not be queued.
  def enqueue(snapshot)
    ServerlessCostexplorerRefreshJob.perform_later(snapshot.id)
    logger&.info "[redmine_serverless_costexplorer] #{User.current.login} queued a refresh (#{snapshot.requested_by})"
    nil
  rescue StandardError => e
    snapshot.update!(error: "#{e.class}: #{e.message}")
    snapshot.error
  end
end
