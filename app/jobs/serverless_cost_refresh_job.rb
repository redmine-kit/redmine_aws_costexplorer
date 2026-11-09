# frozen_string_literal: true

# Fetches the costs for a requested snapshot: from the "Refresh" button
# (enqueued) or from the rake task redmine_serverless_cost:refresh (run in
# the task's process).
class ServerlessCostRefreshJob < ApplicationJob
  def perform(snapshot_id)
    return unless RedmineServerlessCost.enabled?

    ServerlessCostSnapshot.find_by(id: snapshot_id)&.fetch!
  end
end
