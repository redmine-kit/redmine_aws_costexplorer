# IAM permissions

The plugin's own calls to AWS, by the role of the process. Lambda's own permissions (logs, running in a VPC) are not included; [Serverless iam.md](https://redmine-kit.github.io/serverless/iam.html) has the full roles.

## Permissions

| Action | Resource | Why |
| --- | --- | --- |
| `ce:GetCostAndUsage` | `*` | The costs by service, by day and, with `REDMINE_COSTEXPLORER_TAG_KEY`, by the tag |
| `ce:GetCostForecast` | `*` | The forecast for this month |

- **Which roles:** The role of the process that runs the rake task `redmine_serverless_costexplorer:refresh` (in Serverless, `redmine-task`), and the role of the process that runs Redmine's jobs, for the fetches when the tab is opened and for the "Refresh" button (in Serverless, `redmine-worker`). The tab and the button only queue the job, so the role of web requests needs nothing, unless jobs run inside the web process.
- **Resources:** The Service Authorization Reference lists one resource type for both actions, `billingview` (`arn:${Partition}:billing::${Account}:billingview/${ResourceId}`), with the condition key `aws:ResourceTag/${TagKey}` (the service reference of Cost Explorer, `ce.json`, checked on 2026-11-10). The plugin does not pass a billing view (`BillingViewArn`), so Cost Explorer uses the account's primary billing view. Whether a policy limited to the primary billing view's ARN (from `billing:ListBillingViews`) allows these requests has not been checked; the example uses `*`.
- **Read-only:** Both actions only read. The costs are those of the whole account (or, in a member account, of that account); the tag splits only what the page shows.

## Example policy

For the role that runs the rake task, and for the role that runs Redmine's jobs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadCosts",
      "Effect": "Allow",
      "Action": ["ce:GetCostAndUsage", "ce:GetCostForecast"],
      "Resource": "*"
    }
  ]
}
```

## Resource-based policies

None.

## Not checked yet

- The policy above on a real role (the tests use stubs and moto, which do not check IAM).
- A policy limited to the primary billing view's ARN instead of `*`.
- In a member account of AWS Organizations, the error when the management account does not allow Cost Explorer.
