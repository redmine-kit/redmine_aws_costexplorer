# Cost Explorer

Redmine Kit AWS Cost Explorer shows the costs of the AWS account that Redmine runs in, from AWS Cost Explorer, on **Administration** › **AWS** › **Cost Explorer**. Only administrators can open the tab. The costs are fetched only when the environment variable `REDMINE_COSTEXPLORER_ENABLED` is `true`; otherwise the tab says so.

## The tab

All amounts are unblended costs, in the currency Cost Explorer returns. The top right shows when the costs were fetched (**Updated: … (daily)**).

- **Total**: **This month** (until today), **Month-end forecast** and **Last month**. A period that Cost Explorer has not finalized yet carries the badge **Estimated**.
- **By service**: each service's costs this month and last month. The arrow before a service shows its **Usage types**.
- **Daily (last 30 days)**: a chart and a table of each day's costs.
- **By cost allocation tag**: each value of the tag in `REDMINE_COSTEXPLORER_TAG_KEY`, with **(no tag)** for the costs without it. Shown only when the variable is set; the tag must be activated as a cost allocation tag in the Billing and Cost Management console.

When the last fetch failed, **Fetch error** shows its time and the class of the error above the last costs that were fetched; the message is in Redmine's log.

## Fetching the costs

Opening the tab never calls Cost Explorer, because AWS charges each Cost Explorer request. The rake task `redmine_kit:aws:costexplorer:refresh`, run once a day by a schedule, fetches the costs with 3 requests (4 with the tag) and keeps them. `redmine_kit:aws:costexplorer:prune` deletes the fetched costs older than 90 days (`DAYS` to change it), keeping the latest successful fetch.

## Project charges

With Redmine Kit Billing installed, the plugin also adds AWS as a source of charges: an administrator adds AWS sources in **Administration** › **Billing** and allocates their accounts to projects, and each project's **Billing** page shows what is allocated to it.
