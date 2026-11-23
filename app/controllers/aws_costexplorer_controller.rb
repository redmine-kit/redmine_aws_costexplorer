# frozen_string_literal: true

# The "Cost Explorer" tab (docs/README.md#what-the-tab-shows). It shows the
# latest snapshot of the daily fetch and never calls Cost Explorer. Redmine's
# page, and the same values as JSON for the new UI's tab (AwsCostexplorer of
# frontend/; AwsCostexplorerHelper#aws_costexplorer_json).
class AwsCostexplorerController < ApplicationController
  include RedmineKit::Aws::AdminTab

  helper :aws_costexplorer
  helper :aws_costexplorer_json

  def index
    @enabled = RedmineKit::Aws::Costexplorer.enabled?
    @snapshot = AwsCostexplorerSnapshot.latest
    @last_request = AwsCostexplorerSnapshot.last_request
    respond_to do |format|
      format.html
      format.json { render json: view_context.aws_costexplorer_json }
    end
  end
end
