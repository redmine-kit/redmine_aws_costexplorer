# frozen_string_literal: true

# Fetches the costs for a requested snapshot: from the "Refresh" button
# (enqueued) or from the rake task redmine_serverless_costexplorer:refresh (run in
# the task's process).
class ServerlessCostexplorerRefreshJob < ApplicationJob
  def perform(snapshot_id)
    return unless RedmineServerlessCostexplorer.enabled?

    ServerlessCostexplorerSnapshot.find_by(id: snapshot_id)&.fetch!
  end
end
