# frozen_string_literal: true

namespace :redmine_serverless_costexplorer do
  desc 'Fetches the costs from Cost Explorer for the "Cost Explorer" tab (daily; 3 requests, 4 with the tag key)'
  task refresh: :environment do
    unless RedmineServerlessCostexplorer.enabled?
      puts 'REDMINE_COSTEXPLORER_ENABLED is not true; nothing fetched'
      next
    end

    snapshot = ServerlessCostexplorerSnapshot.request!(ServerlessCostexplorerSnapshot::SCHEDULE)
    ServerlessCostexplorerRefreshJob.perform_now(snapshot.id)
    snapshot.reload
    abort "Cost Explorer: #{snapshot.error} (#{snapshot.requests} request(s))" if snapshot.error

    pruned = ServerlessCostexplorerSnapshot.prune
    puts "fetched the costs with #{snapshot.requests} request(s); deleted #{pruned} old snapshot(s)"
  end
end
