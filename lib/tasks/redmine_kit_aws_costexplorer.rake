# frozen_string_literal: true

namespace :redmine_kit do
  namespace :aws do
    namespace :costexplorer do
      desc 'Fetches the costs from Cost Explorer for the "Cost Explorer" tab ' \
           '(once a day; 3 requests, 4 with the tag key)'
      task refresh: :environment do
        unless RedmineKit::Aws::Costexplorer.enabled?
          puts 'REDMINE_COSTEXPLORER_ENABLED is not true; nothing fetched'
          next
        end

        snapshot = AwsCostexplorerSnapshot.request!
        snapshot.fetch!
        abort "Cost Explorer: #{snapshot.error} (#{snapshot.requests} request(s))" if snapshot.error

        puts "fetched the costs with #{snapshot.requests} request(s)"
      end

      desc 'Deletes the snapshots of the costs older than a number of days, keeping the latest successful one. ' \
           'Use DAYS to set the number of days (default 90).'
      task prune: :environment do
        line, ok = RedmineKit::Aws::Costexplorer::Tasks.prune(ENV)
        ok ? puts(line) : abort(line)
      end
    end
  end
end
