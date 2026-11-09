# Redmine Serverless Cost Explorer

Redmine Serverless Cost Explorer (`redmine_serverless_costexplorer`) is a Redmine plugin that shows the costs of the AWS account in Redmine's administration, from AWS Cost Explorer. It adds the "Cost Explorer" tab to the shared "Serverless" administration menu. It does not modify Redmine's own files. The plugin is in early development (version 0.1.0).

- [Setup](setup.md): requirements, installation, configuration, AWS resources, network, tests
- [IAM permissions](iam.md): permissions, example policy, resource-based policies

The plugin assumes that the AWS account is used only for the Redmine, so the account's costs are the Redmine's costs. For an account that holds several Redmine instances, the costs can also be split by a cost allocation tag (an option, off by default).

## Features

Each feature has a condition that enables it. Without `REDMINE_COSTEXPLORER_ENABLED=true`, the plugin makes no requests to AWS.

| Feature | Contents | Enabled when | Page |
| --- | --- | --- | --- |
| The "Cost Explorer" tab | The costs of the AWS account: this month so far, the forecast for this month, the previous month, by service, and daily for the last 30 days | `REDMINE_COSTEXPLORER_ENABLED=true`; administrators | [What the tab shows](#what-the-tab-shows) |
| Daily fetch | The rake task `redmine_serverless_costexplorer:refresh` fetches the costs and keeps them in the database, so that data is ready on the first view | Same as above; run daily by a schedule | [setup.md](setup.md#schedule) |
| Fetch on view, "Refresh" button | Opening the tab when the data is older than an hour, or the button, queues a fetch, at most once per hour | Same as above | [Fetching the costs](#fetching-the-costs) |
| Costs by tag | The costs of this month and the previous month by the values of a cost allocation tag (normally `redmine:instance`) | `REDMINE_COSTEXPLORER_TAG_KEY` is set (off by default) | [Costs by tag](#costs-by-tag-optional) |

## What the tab shows

The main view is the whole account, titled "Costs of this AWS account".

| Section | Contents | Cost Explorer request |
| --- | --- | --- |
| This month so far | The month's costs until today, including today's costs so far | `GetCostAndUsage`, monthly, by service, from the first day of the previous month to tomorrow (the sum of the services) |
| Forecast for this month | The costs until yesterday plus Cost Explorer's forecast from today to the end of the month. When Cost Explorer has no forecast (for example, in an account with too little history), the page says so | `GetCostForecast`, from today to the first day of next month |
| Previous month | The previous month's costs | Same request as "This month so far" |
| By service | Each service's costs this month and in the previous month, the largest this month first | Same request |
| Daily, last 30 days | Each day's costs, with a bar of the share of the largest day. The bars are Redmine's own progress bars (HTML and CSS, no JavaScript) | `GetCostAndUsage`, daily, from 29 days ago (or the first day of the month, if earlier) to tomorrow |
| By the cost allocation tag | Only with `REDMINE_COSTEXPLORER_TAG_KEY`: each tag value's costs this month and in the previous month, with "(no tag)" for the costs without it | `GetCostAndUsage`, monthly, by the tag |

- **Amounts:** Unblended costs (`UnblendedCost`), in the currency that Cost Explorer returns (USD), with two decimals.
- **Estimated:** Cost Explorer marks recent periods as estimated; the page shows "estimated" next to them.
- **Dates:** Cost Explorer's dates are in UTC, so "today" is today in UTC.
- **The fetch time:** The page shows when the data was fetched. Cost Explorer updates its data about once a day, so data a day old is normal.
- **Errors:** When the last fetch failed, the page shows its error above the last successful data. When Cost Explorer could not be reached (no route from the network, DNS or a timeout), it also says that a network without internet access needs a route to it ([setup.md](setup.md#network)).

## Fetching the costs

The page never calls Cost Explorer itself. AWS charges each Cost Explorer API request (USD 0.01 per request, AWS Cost Explorer pricing page, checked on 2026-11-10), so the plugin fetches the costs in the background, keeps them, and fetches again at most once per hour.

| How | When | Runs in |
| --- | --- | --- |
| Rake task `redmine_serverless_costexplorer:refresh` | Daily, from a schedule ([setup.md](setup.md#schedule)) | The process that runs the task. It fetches at once and fails (non-zero exit) when the fetch fails |
| Opening the tab | When an administrator opens the tab and the latest data is older than an hour. The page shows the stored data at once, with a note that newer data is being fetched; reloading the page shows it | The job `ServerlessCostexplorerRefreshJob`, as below |
| "Refresh" button | When an administrator asks | The job `ServerlessCostexplorerRefreshJob`, wherever Redmine runs its jobs (with [Redmine Serverless SQS](https://redmine-kit.github.io/redmine_serverless_sqs/), from the job queue; the plugin adds the job to the allowed classes) |

- **At most once per hour:** A fetch from the tab or the button starts only when there was no fetch request of any kind (scheduled, from the tab or from the button) within the last hour. So a request that is still queued or running is not repeated, a failed fetch is not retried within the hour, and a request that never finished stops blocking after an hour. The web process only queues the job; it never calls Cost Explorer.
- **Requests per fetch:** 3 (`GetCostAndUsage` twice, `GetCostForecast` once), or 4 with the tag. A long answer of `GetCostAndUsage` comes in pages, and each further page is one more request. The page states the count next to the button.
- **Requests in a month:** The schedule makes 3 or 4 requests a day: about 90 to 120 a month, about USD 0.9 to 1.2. Opening the tab adds at most one fetch per hour. In the worst case, with the tab opened every hour of every business day (8 hours, 22 days) and the tag on: 8 × 22 × 4 = 704 requests, about USD 7 a month (3 requests a fetch without the tag: 528, about USD 5.3). Typical use, a few views a week, makes far fewer.
- **No retries of a failed fetch:** A failed fetch is recorded with its error and not retried by the job, so that errors do not multiply the requests. The next scheduled run, or a view after the hour, fetches again.
- **Snapshots:** Each fetch is a row in `serverless_costexplorer_snapshots`: when it was requested and by whom (`schedule`, `view` for the tab, or the administrator's login for the button), when it was fetched, the data (JSON), the error, and the number of requests. The rake task deletes rows older than 90 days after each successful fetch, keeping the latest successful one.

## Costs by tag (optional)

For an AWS account that holds several Redmine instances, the costs can be split by a cost allocation tag. It is off by default: without `REDMINE_COSTEXPLORER_TAG_KEY`, the plugin does not request the tag grouping and the page has no tag section.

- **Turning it on:** Set `REDMINE_COSTEXPLORER_TAG_KEY` to the tag key, normally `redmine:instance` (the tag that [Serverless](https://redmine-kit.github.io/serverless/) puts on each instance's resources). In Serverless, the deployment configuration file sets it.
- **Activating the tag:** In the Billing and Cost Management console, activate the tag key as a cost allocation tag (Cost allocation tags). AWS takes up to 24 hours to activate it. Until costs carry the tag, the page says so and shows how to activate it.
- **One more request:** A fetch makes 4 requests instead of 3.
- **Untagged costs:** Costs without the tag (for example, shared resources or costs from before the activation) are shown as "(no tag)".

## Notes

- **AWS Organizations:** In a member account, the management account decides whether member accounts may use Cost Explorer (Cost Management preferences › "Linked account access"; AWS Cost Management User Guide, "Controlling access to Cost Explorer", checked on 2026-11-10). Without it, the requests fail with an access error. A member account sees only its own costs.
- **Enabling Cost Explorer:** Cost Explorer is enabled for an account by opening it once in the console; AWS then prepares the data, which can take up to 24 hours (AWS Cost Management User Guide, "Enabling Cost Explorer", checked on 2026-11-10).
- **No connection check:** The plugin does not add a check to Redmine Serverless's "Status and connections": each check would be a charged request. The "Cost Explorer" tab shows the result of the last fetch.
- **Code structure:** `lib/redmine_serverless_costexplorer/fetcher.rb` makes the requests, `app/models/serverless_costexplorer_snapshot.rb` keeps the fetches, `app/jobs/serverless_costexplorer_refresh_job.rb` and `lib/tasks/redmine_serverless_costexplorer.rake` run them, and `app/controllers/serverless_costexplorer_controller.rb` shows the tab. `init.rb` registers the tab.
- **Migrations:** A table for the snapshots (`serverless_costexplorer_snapshots`). Run `redmine:plugins:migrate`.
