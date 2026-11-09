# frozen_string_literal: true

namespace :redmine_serverless_cost do
  desc 'Fetches the costs from Cost Explorer for the "Costs" tab (daily; 3 requests, 4 with REDMINE_COST_TAG_KEY)'
  task refresh: :environment do
    unless RedmineServerlessCost.enabled?
      puts 'REDMINE_COST_ENABLED is not true; nothing fetched'
      next
    end

    snapshot = ServerlessCostSnapshot.request!(ServerlessCostSnapshot::SCHEDULE)
    ServerlessCostRefreshJob.perform_now(snapshot.id)
    snapshot.reload
    abort "Cost Explorer: #{snapshot.error} (#{snapshot.requests} request(s))" if snapshot.error

    pruned = ServerlessCostSnapshot.prune
    puts "fetched the costs with #{snapshot.requests} request(s); deleted #{pruned} old snapshot(s)"
  end
end
