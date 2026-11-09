# Setup

What a Redmine needs to use Redmine Serverless Cost: installation, configuration, the schedule, IAM permissions and network access. [Serverless](https://redmine-kit.github.io/serverless/) sets all of this up with CloudFormation from its deployment configuration file (`cost.enabled` and `cost.allocationTag` in `redmine.json`); this page is for setting it up by hand, or for checking what Serverless creates.

## Requirements

- Redmine 7.0 or later.
- AWS's gem `aws-sdk-costexplorer` (a dependency of the gem; with a checkout, the plugin's `Gemfile` adds it).
- An AWS account where Cost Explorer is enabled ([README.md](README.md#notes)). In a member account of AWS Organizations, the management account must allow member accounts to use Cost Explorer.
- Something that runs the rake task daily, and something that runs Redmine's jobs (for the "Refresh" button).

## Installation

**Getting the plugin:** Each version tag (`v*`) publishes the plugin as a gem to GitHub Packages (`https://rubygems.pkg.github.com/redmine-kit`; `.github/workflows/gem.yml`). The first version is 0.1.0. Installing from GitHub Packages needs a GitHub token with `read:packages`, even for a public package. The gem holds the plugin's run-time files (`init.rb`, `lib/`, `app/`, `config/`, `db/`, `LICENSE`); the plugin's `Gemfile` is not in it. Redmine loads plugins only from `plugins/`, so the installed gem is linked there:

```ruby
# Redmine's Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_serverless_cost'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <user>:<token>   # or the variable BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
ln -s "$(bundle info --path redmine_serverless_cost)" plugins/redmine_serverless_cost
```

Without the gem, clone the repository into `plugins/redmine_serverless_cost` (`git clone https://github.com/redmine-kit/redmine_serverless_cost.git plugins/redmine_serverless_cost`) and run `bundle install` (Redmine's `Gemfile` loads the plugin's, which adds `aws-sdk-costexplorer`).

1. Put the plugin in `plugins/redmine_serverless_cost` as above.
2. Run `bin/rake redmine:plugins:migrate`. It creates the table of snapshots (`serverless_cost_snapshots`).
3. Set the environment variables (below) and the schedule ([Schedule](#schedule)).

## Configuration

The plugin has no settings page; both settings are environment variables, which the deployment sets (in Serverless, from `redmine.json`).

| Setting | Where | Contents |
| --- | --- | --- |
| `REDMINE_COST_ENABLED` | Environment variable of every process (web, jobs, rake) | `true` turns the plugin on. Any other value, or none, leaves it off: the rake task and the job make no requests, and the "Costs" tab says that the plugin is off |
| `REDMINE_COST_TAG_KEY` | Same | Optional. The key of a cost allocation tag, normally `redmine:instance`, to also show the costs by its values ([README.md](README.md#costs-by-tag-optional)). Empty or unset: off (the default), and no tag request is made. In Serverless, `cost.allocationTag` in `redmine.json` sets it |
| AWS credentials and region | The SDK's usual sources (the Lambda role, an instance profile, `AWS_*` variables) | The plugin always calls Cost Explorer in `us-east-1`, whatever the region of Redmine |

- **Turning on the tag:** Activate the tag key as a cost allocation tag in the Billing and Cost Management console (Cost allocation tags). This is needed only with `REDMINE_COST_TAG_KEY`. AWS takes up to 24 hours to activate it.

## AWS resources

The plugin creates no AWS resources and needs none of its own. Cost Explorer's API is a global service of the account.

### Schedule

Run the rake task `redmine_serverless_cost:refresh` once a day:

```sh
bin/rake redmine_serverless_cost:refresh
```

- **Time:** Any time of day; Cost Explorer updates its data about once a day. Once a day costs 3 or 4 requests ([README.md](README.md#fetching-the-costs)).
- **Exit status:** The task fails (non-zero exit, with the error on standard error) when the fetch fails, so that the scheduler records the failure. With the plugin off, it prints that nothing was fetched and succeeds.
- **In Serverless:** An EventBridge rule (`<instance>-cost-refresh`) invokes the function `redmine-task` daily with `{"command": "rake", "args": ["redmine_serverless_cost:refresh"]}` ([Serverless tasks.md](https://redmine-kit.github.io/serverless/tasks.html#scheduled-runs)).
- **Elsewhere:** cron, a systemd timer or a scheduled container task that runs the command in Redmine's directory with the environment of Redmine.

## IAM permissions

The permissions the plugin needs, with an example policy, are in [iam.md](iam.md).

## Network

| Destination | API | In a VPC without internet access |
| --- | --- | --- |
| Cost Explorer (`ce.us-east-1.amazonaws.com`) | `GetCostAndUsage`, `GetCostForecast` | A route to the internet, such as a NAT. In Serverless, `network.mode` `nat` |

- **Which processes:** Only the processes that fetch: the one running the rake task, and the one running Redmine's jobs. The web process does not call Cost Explorer when jobs run elsewhere (with Rails's default adapter, jobs run inside the web process, which then calls it).
- **Interface endpoint:** The AWS PrivateLink Guide lists "AWS Cost Explorer" with the service name `com.amazonaws.<region>.ce` ("AWS services that integrate with AWS PrivateLink", checked on 2026-11-10). Cost Explorer's API is in `us-east-1`. Whether the endpoint is offered in other regions, and whether it serves `ce.us-east-1.amazonaws.com` to a VPC in another region, has not been checked; Serverless's `network.mode` `endpoints` does not create it.
- **Unreachable:** With no route, the requests time out (the plugin opens connections with a 5-second timeout and retries twice). The "Costs" tab shows the error and says that a route is needed.

## Tests

The tests are in `test/` and run with Redmine's standard mechanism, in Redmine 7.0.3 on PostgreSQL 16 and moto in Docker.

- **Unit and functional tests:** SDK response stubs. The answers are JSON bodies in `test/fixtures/cost_explorer/`, which the SDK parses as real answers. They follow the response syntax of the API reference; they are not recorded from an account, because the tests have no AWS account.
- **Integration tests on moto:** moto answers `GetCostAndUsage` with results given in advance through its API (`/moto-api/static/ce/cost-and-usage-results`), so the requests and the parsing run through the SDK and HTTP. moto has no `GetCostForecast` (it answers 500), which also tests a fetch without a forecast. The rake task runs against moto too.
- **No LocalStack:** LocalStack implements `GetCostAndUsage` only in its Ultimate plan and without cost data, and has no `GetCostForecast` (LocalStack's Cost Explorer page, checked on 2026-11-10), so the tests do not use it.

`bin/test` runs the plugin's tests, then Redmine's tests around administration and plugins; `bin/test --redmine` runs every Redmine test with the plugin installed, as the CI does. The plugin's tests also write the coverage of the plugin's own files (SimpleCov, Cobertura XML in `coverage/coverage.xml`), which CI uploads to [Codecov](https://codecov.io/gh/redmine-kit/redmine_serverless_cost).

```sh
bin/test            # the plugin's tests and Redmine's tests around administration
bin/test --redmine  # with every Redmine test
bin/lint            # RuboCop
bin/services --down # stops PostgreSQL and moto
```

## To verify

- The requests and the answers in a real account (the tests use stubs and moto), including the number of pages of `GetCostAndUsage` by service
- The forecast against the console's month-end forecast
- The access error in a member account without "Linked account access"
- The interface endpoint `com.amazonaws.<region>.ce` from a VPC in us-east-1 and in another region
- The policies in [iam.md](iam.md) on a real role
