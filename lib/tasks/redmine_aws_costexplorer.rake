# frozen_string_literal: true

namespace :redmine_aws_costexplorer do
  desc 'Fetches the costs from Cost Explorer for the "Cost Explorer" tab (once a day; 3 requests, 4 with the tag key)'
  task refresh: :environment do
    unless RedmineAwsCostexplorer.enabled?
      puts 'REDMINE_COSTEXPLORER_ENABLED is not true; nothing fetched'
      next
    end

    snapshot = AwsCostexplorerSnapshot.request!(AwsCostexplorerSnapshot::SCHEDULE)
    snapshot.fetch!
    abort "Cost Explorer: #{snapshot.error} (#{snapshot.requests} request(s))" if snapshot.error

    pruned = AwsCostexplorerSnapshot.prune
    puts "fetched the costs with #{snapshot.requests} request(s); deleted #{pruned} old snapshot(s)"
  end
end
