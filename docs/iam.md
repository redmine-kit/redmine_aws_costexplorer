# IAM permissions

The plugin's own calls to AWS, by the role of the process. Lambda's own permissions (logs, running in a VPC) are not included; [Serverless iam.md](https://redmine-kit.github.io/serverless/iam.html) has the full roles.

## Permissions

| Action | Resource | Why |
| --- | --- | --- |
| `ce:GetCostAndUsage` | `*` | The costs by service, by day and, with `REDMINE_COSTEXPLORER_TAG_KEY`, by the tag |
| `ce:GetCostForecast` | `*` | The month-end forecast |
| `billing:GetBillingViewData` | The shared billing views' ARNs | Only for Redmine Kit Charges' sources of a shared billing view ([below](#a-shared-custom-billing-view-recommended)) |
| `sts:AssumeRole` | The roles' ARNs | Only for Redmine Kit Charges' sources of a role in another account ([below](#a-role-in-another-account-assumerole)) |

Only the role of the process that runs the rake tasks `redmine_kit:aws:costexplorer:refresh` and `redmine_kit:charges:refresh` needs these permissions (in Serverless, `redmine-task`). Web requests and Redmine's jobs never call Cost Explorer. Both actions only read. The costs are those of the whole account (or, in a member account, of that account); the tag only splits what the page shows.

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

### Project charges (Redmine Kit Charges)

With [Redmine Kit Charges](README.md#project-charges-redmine-kit-charges), each AWS source a system administrator adds
is read with the same two actions, by the same role (the one that runs `redmine_kit:charges:refresh`). A source of this
Redmine server's account needs nothing more. To read other accounts, add one of the two policies below to that role,
listing only the billing views or roles the deployment allows: **the IAM policy is the real allowlist**; Redmine's
system administrators can only use what it allows.

#### A shared custom billing view (recommended)

The organization's management account creates a custom billing view (filtered by account or by cost allocation tag)
and shares it with the Redmine server's account through AWS RAM; the Redmine server's role reads it by its ARN
(`BillingViewArn` on every request). No credentials and no role in another account.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadSharedBillingViews",
      "Effect": "Allow",
      "Action": ["ce:GetCostAndUsage", "ce:GetCostForecast", "billing:GetBillingViewData"],
      "Resource": ["arn:aws:billing::111111111111:billingview/custom-1a2b3c4d"]
    }
  ]
}
```

- `111111111111` is the account that created the view (the management account), and the ARN is the one
  `billing:ListBillingViews` returns there. Which account ID the ARN has in the receiving account has not been checked.
- `billing:GetBillingViewData` is a permission-only action ("get cost and usage data for a specified billing view",
  the Service Authorization Reference of AWS Billing, 2026-11-19). Whether `GetCostAndUsage` with a billing view needs
  it has not been checked; it is in the example so that the policy works either way, limited to the view.
- Only the sharing management account needs AWS RAM permissions; the receiving account needs none ("Permissions are not
  required for member accounts who receive a shared custom billing view", Sharing custom billing views). Outside the
  organization, an administrator of the receiving account accepts the invitation; the Redmine server's role is not
  given that permission.

#### A role in another account (AssumeRole)

For a standalone account (which can't create custom billing views) or an organization that can't share one: a read-only
role in that account trusts the Redmine server's role, with the source's external ID (shown on the source's page in
「管理」›「料金」). Assuming a role in an organization's management account works but is not recommended: AWS advises
using the management account only for tasks that need it.

The Redmine server's role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AssumeCostReaders",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": ["arn:aws:iam::222222222222:role/redmine-kit-cost-reader"]
    }
  ]
}
```

The trust policy of `redmine-kit-cost-reader` in account `222222222222`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::333333333333:role/redmine-kit/<instance>-task" },
      "Action": "sts:AssumeRole",
      "Condition": { "StringEquals": { "sts:ExternalId": "<the source's external ID>" } }
    }
  ]
}
```

Its permissions policy:

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

- The external ID is generated by Redmine for each source (`redmine-kit-<UUID>`). It is not a secret, but it keeps
  another Redmine server (for example, another customer of a shared hosting) that registers the same role from reading
  these charges (the confused deputy).
- The session lasts 15 minutes (the shortest STS allows); the SDK renews it if a fetch takes longer.

#### Permissions boundary

A role with a permissions boundary (Serverless's task role has `redmine-kit-boundary`) gets only what both its policies
and the boundary allow. The boundary must allow `ce:GetCostAndUsage` and `ce:GetCostForecast`, plus
`billing:GetBillingViewData` for billing views and `sts:AssumeRole` for roles. The boundary may allow them on `*`: the
role's own policy limits the resources.

```json
{
  "Sid": "Charges",
  "Effect": "Allow",
  "Action": ["ce:GetCostAndUsage", "ce:GetCostForecast", "billing:GetBillingViewData", "sts:AssumeRole"],
  "Resource": "*"
}
```

[Serverless](https://redmine-kit.github.io/serverless/iam.html) writes these policies from `charges.aws.billingViewArns`
and `charges.aws.roleArns` in `redmine.json`.

## Resource-based policies

None of the plugin's own. A shared custom billing view has the resource-based policy that AWS RAM's managed permission
creates in the sharing account; a role to assume has its trust policy (above).

## Not checked yet

- The policy above on a real role (the tests use stubs and moto, which do not check IAM).
- A shared custom billing view on a real organization: `GetCostAndUsage` with `BillingViewArn` grouped by
  `LINKED_ACCOUNT` and `TAG` in the receiving account, the account names in `DimensionValueAttributes`, the account ID
  of the view's ARN there, whether `billing:GetBillingViewData` is needed, and which actions AWS RAM's default managed
  permission for billing views allows (`aws ram get-permission`).
- AssumeRole with the external ID on real accounts.
- A policy limited to the primary billing view's ARN instead of `*`.
- In a member account of AWS Organizations, the error when the management account does not allow Cost Explorer.
