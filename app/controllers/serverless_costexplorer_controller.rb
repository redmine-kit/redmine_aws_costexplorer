# frozen_string_literal: true

# The "Cost Explorer" tab (docs/README.md#what-the-tab-shows). It shows the
# latest snapshot of the daily fetch and never calls Cost Explorer.
class ServerlessCostexplorerController < ApplicationController
  layout 'admin'
  self.main_menu = false
  menu_item :serverless

  before_action :require_admin

  helper :serverless_costexplorer

  def index
    @enabled = RedmineServerlessCostexplorer.enabled?
    @snapshot = ServerlessCostexplorerSnapshot.latest
    @last_request = ServerlessCostexplorerSnapshot.last_request
  end
end
