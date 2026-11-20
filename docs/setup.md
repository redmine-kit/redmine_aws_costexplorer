# Setup

What a Redmine server needs to use Redmine Kit AWS Cost Explorer: installation, configuration, the schedule, IAM permissions and network access. [Serverless](https://redmine-kit.github.io/serverless/)'s image does not include the plugin. For an image that adds it (a derived image), Serverless sets all of this up with CloudFormation from its deployment configuration file (`costExplorer.enabled` and `costExplorer.allocationTag` in `redmine.json`, off by default); this page is for setting it up by hand, or for checking what Serverless creates.

## Requirements

- Redmine 7.0 or later.
- [Redmine Kit AWS](https://redmine-kit.github.io/redmine_aws/) (`redmine_kit_aws`) 0.1 or later, which has the "AWS" administration menu (a dependency of the gem; with a checkout, it is cloned too).
- AWS's gem `aws-sdk-costexplorer` (a dependency of the gem; with a checkout, the plugin's `Gemfile` adds it).
- An AWS account where Cost Explorer is enabled ([README.md](README.md#notes)). In a member account of AWS Organizations, the management account must allow member accounts to use Cost Explorer.
- Something that runs the rake task once a day.

## Installation

1. Put the plugin in `plugins/redmine_kit_aws_costexplorer` and Redmine Kit AWS in `plugins/redmine_kit_aws`: install the gems ([Gem](#gem)) or clone the repositories ([Without the gem](#without-the-gem)).
2. Run the plugin's migrations. They create the table of snapshots (`aws_costexplorer_snapshots`).

   ```sh
   bin/rake redmine:plugins:migrate
   ```

3. Set the environment variables (below) and the schedule ([Schedule](#schedule)).

### Gem

Each version tag (`v*`) publishes the plugin as a gem to GitHub Packages (`https://rubygems.pkg.github.com/redmine-kit`; `.github/workflows/gem.yml`). The first version is 0.1.0. Installing from GitHub Packages needs a GitHub token with `read:packages`, even for a public package. The gem holds the plugin's run-time files (`init.rb`, `lib/`, `app/`, `assets/`, `config/`, `db/`, `help/`, `LICENSE`); the plugin's `Gemfile` is not in it. The gem depends on `redmine_kit_aws`, which Bundler installs from the same source, so `Gemfile.local` names only this plugin's gem. Redmine loads plugins only from `plugins/`, so both installed gems are linked there:

```ruby
# Redmine's Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_kit_aws_costexplorer'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <user>:<token>   # or the variable BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
ln -s "$(bundle info --path redmine_kit_aws)" plugins/redmine_kit_aws
ln -s "$(bundle info --path redmine_kit_aws_costexplorer)" plugins/redmine_kit_aws_costexplorer
```

Bundler can also install the plugins from their repositories, which needs no token; link them into `plugins/` as above:

```ruby
# Redmine's Gemfile.local
gem 'redmine_kit_aws', git: 'https://github.com/redmine-kit/redmine_aws.git', tag: 'v0.1.0', require: false
gem 'redmine_kit_aws_costexplorer', git: 'https://github.com/redmine-kit/redmine_aws_costexplorer.git', tag: 'v0.1.0', require: false
```

### Without the gem

Clone the repository into `plugins/redmine_kit_aws_costexplorer` and Redmine Kit AWS into `plugins/redmine_kit_aws`, then install the gems. Redmine's `Gemfile` loads the plugin's, which adds `aws-sdk-costexplorer`. Nothing of the plugin has to load before Rails starts, so it needs no line in `Gemfile.local`.

```sh
git clone https://github.com/redmine-kit/redmine_aws.git plugins/redmine_kit_aws
git clone https://github.com/redmine-kit/redmine_aws_costexplorer.git plugins/redmine_kit_aws_costexplorer
bundle install
```

## Configuration

The plugin has no settings page; both settings are environment variables, which the deployment sets (in Serverless, from `redmine.json`).

| Key | Description | Parameter |
| --- | --- | --- |
| `REDMINE_COSTEXPLORER_ENABLED` | Turns the plugin on. When it is off, the rake task makes no requests, and the "Cost Explorer" tab says that the plugin is off | Required. `true` turns it on; any other value, or none, leaves it off. Set it in the process that runs the rake task (to fetch) and in the web process (the tab says whether the plugin is on) |
| `REDMINE_COSTEXPLORER_TAG_KEY` | The key of a cost allocation tag, to also show the costs by its values ([README.md](README.md#costs-by-tag-optional)) | Optional. Example: `redmine:instance`. Empty or unset: off (the default), and no tag request is made. Set it only in the process that runs the rake task; the tab takes the tag from the stored data. In Serverless, `costExplorer.allocationTag` in `redmine.json` sets it |

| Item | Description | Where to change |
| --- | --- | --- |
| AWS credentials and region | The plugin always calls Cost Explorer in `us-east-1`, whatever the region of Redmine | The SDK's usual sources (the Lambda role, an instance profile, `AWS_*` variables) |

To break the costs down by a tag (`REDMINE_COSTEXPLORER_TAG_KEY`), activate the tag key as a cost allocation tag in the Billing and Cost Management console (Cost allocation tags). AWS takes up to 24 hours to activate it.

## AWS resources

The plugin creates no AWS resources and needs none of its own. Cost Explorer's API is a global service of the account.

### Schedule

Run the rake task `redmine_kit:aws:costexplorer:refresh` once a day, and `redmine_kit:aws:costexplorer:prune` once a day to delete the old snapshots:

```sh
bin/rake redmine_kit:aws:costexplorer:refresh
bin/rake redmine_kit:aws:costexplorer:prune DAYS=90
```

`prune` deletes the snapshots older than `DAYS` days (default 90; a whole number from 1 to 99999), as Redmine's `redmine:users:prune` takes it, and always keeps the latest successful one. Another value deletes nothing and stops the task with a message. It makes no requests to AWS.

Any time of day works: Cost Explorer updates its data about once a day, and one run costs 3 or 4 requests ([README.md](README.md#fetching-the-costs)). When the fetch fails, the task fails too (a non-zero exit, with the error on standard error), so that the scheduler records the failure. With the plugin off, it prints that nothing was fetched and succeeds.

| Where | What runs the task |
| --- | --- |
| Serverless | EventBridge Scheduler invokes the function `redmine-task` daily with `{"command": "rake", "args": ["redmine_kit:aws:costexplorer:refresh"]}` (`<instance>-costexplorer-refresh`) and with `{"command": "rake", "args": ["redmine_kit:aws:costexplorer:prune"], "env": {"DAYS": "<retention.recordsDays>"}}` (`<instance>-costexplorer-prune`) ([Serverless tasks.md](https://redmine-kit.github.io/serverless/tasks.html#scheduled-runs)) |
| Elsewhere | cron, a systemd timer or a scheduled container task that runs the command in Redmine's directory, with Redmine's environment |

## IAM permissions

The permissions the plugin needs, with an example policy, are in [iam.md](iam.md).

## Network

| Destination | API | In a VPC without internet access |
| --- | --- | --- |
| Cost Explorer (`ce.us-east-1.amazonaws.com`) | `GetCostAndUsage`, `GetCostForecast` | A route to the internet, such as a NAT. In Serverless, `network.mode` `nat` |

Only the process that runs the rake task calls Cost Explorer; the web process never does. Without a route, the requests time out (the plugin opens connections with a 5-second timeout and retries twice), and the "Cost Explorer" tab shows the error and says that a route is needed.

An interface endpoint may also work, but it is not checked. The AWS PrivateLink Guide lists "AWS Cost Explorer" with the service name `com.amazonaws.<region>.ce` ("AWS services that integrate with AWS PrivateLink", checked on 2026-11-10), while Cost Explorer's API is in `us-east-1`. Whether the endpoint is offered in other regions, and whether it serves `ce.us-east-1.amazonaws.com` to a VPC in another region, has not been checked. Serverless's `network.mode` `endpoints` does not create it.

## Tests

The tests are in `test/` and run with Redmine's standard mechanism, in Redmine 7.0.3 on PostgreSQL 16, in Apple container when it is installed and running, else in Docker (`CONTAINER_CLI=container` or `docker` chooses; at most two test runs of the redmine-kit repositories at once on a machine, `TEST_SLOTS`). Cost Explorer is LocalStack when `LOCALSTACK_AUTH_TOKEN` is set (in CI, the organization's secret), and moto otherwise.

The tests stay on moto and LocalStack, not on [AWS Emulator](https://docs.aws.amazon.com/emulator/latest/userguide/), which the organization uses for tests against AWS: AWS Emulator 1.0.512 (checked on 2026-11-19) answers `NotImplemented` to `GetCostAndUsage`, `GetCostForecast` and `GetDimensionValues`, and only moto can load cost data for the tests. They move to the emulator once it supports them.

### Unit and functional tests

These use SDK response stubs. The answers are JSON bodies in `test/fixtures/cost_explorer/`, which the SDK parses as real answers. They follow the response syntax of the API reference; they are not recorded from an account, because the tests have no AWS account.

### Integration tests

`test/integration/cost_explorer_test.rb` sends the plugin's requests through the SDK and HTTP to the backend: a fetch, a fetch with the tag, and the rake task. With the token they run on LocalStack; if LocalStack does not start, `bin/services` shows its logs and the run fails. The log names the backend (`AWS backend: ...`).

LocalStack's Cost Explorer is in the Ultimate plan. Its coverage page lists `GetCostAndUsage` but not `GetCostForecast`, and says it has no cost data (LocalStack's Cost Explorer page, checked on 2026-11-10). On LocalStack 2026.10.6 (checked on 2026-11-10), `GetCostAndUsage` answered every request of the plugin (monthly by service, monthly by the tag, daily) in the real response shape with no results, and `GetCostForecast` answered `InternalFailure` ("The get_cost_forecast action has not been implemented"). So on LocalStack the tests check the empty costs, and the amounts are checked with moto and the stubs.

Without the token, moto answers `GetCostAndUsage` with results given in advance through its API (`/moto-api/static/ce/cost-and-usage-results`), so the tests check the amounts. moto has no `GetCostForecast` (it answers 500).

### Redmine Kit Billing

The provider of Redmine Kit Billing (`charges_provider_test.rb`) is tested with SDK response stubs: the requests of each kind of source (this account, a shared billing view's `BillingViewArn`, AssumeRole with the external ID through a stubbed STS), the rows, the account statement's requests, pages and lines (`charges_provider_statement_test.rb`), the retries on `LimitExceededException`, and the settings it refuses. `test/integration/charges_test.rb` runs one source through Redmine Kit Billing's daily fetch, and an account statement through the provider, on moto, the backend that can load Cost Explorer data (AWS Emulator answers `NotImplemented`; moto ignores `BillingViewArn`, so billing views are checked with the stubs only). It needs Redmine Kit Billing in the test image: `bin/test_image` adds a checkout next to this one (`../redmine_kit_billing`, or `REDMINE_KIT_BILLING_DIR`), and without it (CI, where that repository is private) the daily fetch's test is skipped.

### The mocked call

Only `GetCostForecast` is mocked, because neither backend implements it. The integration tests replace that one call of the client with an SDK stub that answers `test/fixtures/cost_explorer/forecast.json` (a total of 15.0, in the documented shape); the other calls go to the backend. A LocalStack test checks that LocalStack still does not implement it, so that the mock can be removed when it does.

### Running the tests

`bin/test` runs the plugin's tests, then Redmine's tests around administration and plugins; `bin/test --redmine` runs every Redmine test with the plugin installed, as the CI does. The tests build Redmine with Redmine Kit AWS from a checkout next to this one (`../redmine_kit_aws`), or from the directory in `REDMINE_KIT_AWS_DIR`; CI checks out `redmine-kit/redmine_aws`. With `COVERAGE=1`, the plugin's tests also write the coverage of the plugin's own files (SimpleCov, Cobertura XML in `coverage/coverage.xml`) and run in one process. CI sets it on Ruby 4.0 and uploads the report to [Codecov](https://codecov.io/gh/redmine-kit/redmine_aws_costexplorer) with the flag `plugin`. The upload authenticates with OIDC (`id-token: write`), so no token is stored as a secret. Codecov's statuses are informational and never fail a commit or a pull request (`codecov.yml`). CI runs the lint and the tests on Ruby 3.2 and 4.0; locally, `TEST_RUBY=3.2 bin/test` (or `bin/lint`) runs them on Ruby 3.2.

`bin/test-gem` checks the gems: it builds the gems of the plugin and of Redmine Kit AWS from the checkouts, installs them as [Gem](#gem) says, links them into `plugins/` and starts Redmine with every file loaded (`zeitwerk:check`, and the production environment, which loads them at start-up). CI runs it too, so a file missing from the gem fails before adapters install it.

```sh
bin/test            # the plugin's tests and Redmine's tests around administration
bin/test --redmine  # with every Redmine test
COVERAGE=1 bin/test # with the coverage in coverage/coverage.xml
bin/lint            # RuboCop
bin/test-gem        # the gems of the plugin and Redmine Kit AWS: built, installed, linked into plugins/, booted
bin/services --down # stops PostgreSQL and moto or LocalStack
```

## To verify

- The requests and the answers in a real account (the tests use stubs and moto), including the number of pages of `GetCostAndUsage` by service
- The forecast against the console's month-end forecast
- The access error in a member account without "Linked account access"
- The interface endpoint `com.amazonaws.<region>.ce` from a VPC in us-east-1 and in another region
- The policies in [iam.md](iam.md) on a real role
