# frozen_string_literal: true

# The "Costs" tab (docs/README.md#what-the-tab-shows). It shows the latest
# snapshot and never calls Cost Explorer; "Refresh" enqueues a fetch, at most
# once per RedmineServerlessCost::REFRESH_INTERVAL.
class ServerlessCostsController < ApplicationController
  layout 'admin'
  self.main_menu = false
  menu_item :serverless

  before_action :require_admin

  helper :serverless_costs

  def index
    @enabled = RedmineServerlessCost.enabled?
    @snapshot = ServerlessCostSnapshot.latest
    @last_request = ServerlessCostSnapshot.last_request
    @tag_key = RedmineServerlessCost.tag_key
  end

  def refresh
    if !RedmineServerlessCost.enabled?
      render_403
      return
    elsif !ServerlessCostSnapshot.refresh_allowed?
      flash[:error] = l(:error_serverless_costs_refresh_too_soon,
                        time: format_time(ServerlessCostSnapshot.refresh_allowed_at))
    else
      enqueue
    end
    redirect_to action: 'index'
  end

  private

  def enqueue
    snapshot = ServerlessCostSnapshot.request!(User.current.login)
    ServerlessCostRefreshJob.perform_later(snapshot.id)
    logger&.info "[redmine_serverless_cost] #{User.current.login} requested a refresh of the costs"
    flash[:notice] = l(:notice_serverless_costs_refresh_started)
  rescue StandardError => e
    snapshot&.update!(error: "#{e.class}: #{e.message}")
    flash[:error] = "#{e.class}: #{e.message}"
  end
end
