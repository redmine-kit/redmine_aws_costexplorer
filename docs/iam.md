# IAM permissions

The plugin's own calls to AWS, by the role of the process. Lambda's own permissions (logs, running in a VPC) are not included; [Serverless iam.md](https://redmine-kit.github.io/serverless/iam.html) has the full roles.

## Permissions

| Action | Resource | Why |
| --- | --- | --- |
| `ce:GetCostAndUsage` | `*` | The costs by service, by day and, with `REDMINE_COSTEXPLORER_TAG_KEY`, by the tag |
| `ce:GetCostForecast` | `*` | The forecast for this month |

Only the role of the process that runs the rake task `redmine_serverless_costexplorer:refresh` needs these permissions (in Serverless, `redmine-task`). Web requests and Redmine's jobs never call Cost Explorer. Both actions only read. The costs are those of the whole account (or, in a member account, of that account); the tag only splits what the page shows.

The Service Authorization Reference lists one resource type for both actions, `billingview` (`arn:${Partition}:billing::${Account}:billingview/${ResourceId}`), with the condition key `aws:ResourceTag/${TagKey}` (the service reference of Cost Explorer, `ce.json`, checked on 2026-11-10). The plugin does not pass a billing view (`BillingViewArn`), so Cost Explorer uses the account's primary billing view. Whether a policy limited to the primary billing view's ARN (from `billing:ListBillingViews`) allows these requests has not been checked, so the example uses `*`.

## Example policy

For the role that runs the rake task:

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
