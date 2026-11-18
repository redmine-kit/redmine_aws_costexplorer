# frozen_string_literal: true

# The "Cost Explorer" tab (docs/README.md#what-the-tab-shows). It shows the
# latest snapshot of the daily fetch and never calls Cost Explorer.
class AwsCostexplorerController < ApplicationController
  include RedmineKit::Aws::AdminTab

  helper :aws_costexplorer

  def index
    @enabled = RedmineKit::Aws::Costexplorer.enabled?
    @snapshot = AwsCostexplorerSnapshot.latest
    @last_request = AwsCostexplorerSnapshot.last_request
  end
end
