# Setup

What a Redmine needs to use Redmine Serverless Cost Explorer: installation, configuration, the schedule, IAM permissions and network access. [Serverless](https://redmine-kit.github.io/serverless/)'s image does not include the plugin. For an image that adds it (a derived image), Serverless sets all of this up with CloudFormation from its deployment configuration file (`costExplorer.enabled` and `costExplorer.allocationTag` in `redmine.json`, off by default); this page is for setting it up by hand, or for checking what Serverless creates.

## Requirements

- Redmine 7.0 or later.
- AWS's gem `aws-sdk-costexplorer` (a dependency of the gem; with a checkout, the plugin's `Gemfile` adds it).
- An AWS account where Cost Explorer is enabled ([README.md](README.md#notes)). In a member account of AWS Organizations, the management account must allow member accounts to use Cost Explorer.
- Something that runs the rake task once a day.

## Installation

1. Put the plugin in `plugins/redmine_serverless_costexplorer`: install the gem ([Gem](#gem)) or clone the repository ([Without the gem](#without-the-gem)).
2. Run the plugin's migrations. They create the table of snapshots (`serverless_costexplorer_snapshots`).

   ```sh
   bin/rake redmine:plugins:migrate
   ```

3. Set the environment variables (below) and the schedule ([Schedule](#schedule)).

### Gem

Each version tag (`v*`) publishes the plugin as a gem to GitHub Packages (`https://rubygems.pkg.github.com/redmine-kit`; `.github/workflows/gem.yml`). The first version is 0.1.0. Installing from GitHub Packages needs a GitHub token with `read:packages`, even for a public package. The gem holds the plugin's run-time files (`init.rb`, `lib/`, `app/`, `config/`, `db/`, `LICENSE`); the plugin's `Gemfile` is not in it. Redmine loads plugins only from `plugins/`, so the installed gem is linked there:

```ruby
# Redmine's Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_serverless_costexplorer'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <user>:<token>   # or the variable BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
ln -s "$(bundle info --path redmine_serverless_costexplorer)" plugins/redmine_serverless_costexplorer
```

### Without the gem

Clone the repository into `plugins/redmine_serverless_costexplorer` and install the gems. Redmine's `Gemfile` loads the plugin's, which adds `aws-sdk-costexplorer`.

```sh
git clone https://github.com/redmine-kit/redmine_serverless_costexplorer.git plugins/redmine_serverless_costexplorer
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

- **Turning on the tag:** Activate the tag key as a cost allocation tag in the Billing and Cost Management console (Cost allocation tags). This is needed only with `REDMINE_COSTEXPLORER_TAG_KEY`. AWS takes up to 24 hours to activate it.

## AWS resources

The plugin creates no AWS resources and needs none of its own. Cost Explorer's API is a global service of the account.

### Schedule

Run the rake task `redmine_serverless_costexplorer:refresh` once a day:

```sh
bin/rake redmine_serverless_costexplorer:refresh
```

- **Time:** Any time of day; Cost Explorer updates its data about once a day. Once a day costs 3 or 4 requests ([README.md](README.md#fetching-the-costs)).
- **Exit status:** The task fails (non-zero exit, with the error on standard error) when the fetch fails, so that the scheduler records the failure. With the plugin off, it prints that nothing was fetched and succeeds.
- **In Serverless:** An EventBridge rule (`<instance>-costexplorer-refresh`) invokes the function `redmine-task` daily with `{"command": "rake", "args": ["redmine_serverless_costexplorer:refresh"]}` ([Serverless tasks.md](https://redmine-kit.github.io/serverless/tasks.html#scheduled-runs)).
- **Elsewhere:** cron, a systemd timer or a scheduled container task that runs the command in Redmine's directory with the environment of Redmine.

## IAM permissions

The permissions the plugin needs, with an example policy, are in [iam.md](iam.md).

## Network

| Destination | API | In a VPC without internet access |
| --- | --- | --- |
| Cost Explorer (`ce.us-east-1.amazonaws.com`) | `GetCostAndUsage`, `GetCostForecast` | A route to the internet, such as a NAT. In Serverless, `network.mode` `nat` |

- **Which processes:** Only the process that runs the rake task. The web process never calls Cost Explorer.
- **Interface endpoint:** The AWS PrivateLink Guide lists "AWS Cost Explorer" with the service name `com.amazonaws.<region>.ce` ("AWS services that integrate with AWS PrivateLink", checked on 2026-11-10). Cost Explorer's API is in `us-east-1`. Whether the endpoint is offered in other regions, and whether it serves `ce.us-east-1.amazonaws.com` to a VPC in another region, has not been checked; Serverless's `network.mode` `endpoints` does not create it.
- **Unreachable:** With no route, the requests time out (the plugin opens connections with a 5-second timeout and retries twice). The "Cost Explorer" tab shows the error and says that a route is needed.

## Tests

The tests are in `test/` and run with Redmine's standard mechanism, in Redmine 7.0.3 on PostgreSQL 16 in Docker. Cost Explorer is LocalStack when `LOCALSTACK_AUTH_TOKEN` is set (in CI, the organization's secret), and moto otherwise.

- **Unit and functional tests:** SDK response stubs. The answers are JSON bodies in `test/fixtures/cost_explorer/`, which the SDK parses as real answers. They follow the response syntax of the API reference; they are not recorded from an account, because the tests have no AWS account.
- **Integration tests:** `test/integration/cost_explorer_test.rb` makes the plugin's requests through the SDK and HTTP to the backend: a fetch, a fetch with the tag, and the rake task. With the token they run on LocalStack, and when LocalStack does not start, `bin/services` shows its logs and the run fails. The log names the backend (`AWS backend: ...`).
- **LocalStack:** Its Cost Explorer is in the Ultimate plan. Its coverage page lists `GetCostAndUsage` and not `GetCostForecast`, and says it has no cost data (LocalStack's Cost Explorer page, checked on 2026-11-10). On LocalStack 2026.10.6 (checked on 2026-11-10), `GetCostAndUsage` answered every request of the plugin (monthly by service, monthly by the tag, daily) in the real response shape with no results, and `GetCostForecast` answered `InternalFailure` ("The get_cost_forecast action has not been implemented"). The tests check the empty costs there; the amounts are checked with moto and the stubs.
- **moto:** Without the token. moto answers `GetCostAndUsage` with results given in advance through its API (`/moto-api/static/ce/cost-and-usage-results`), so the tests check the amounts. It has no `GetCostForecast` (it answers 500).
- **Mocked call:** `GetCostForecast` only, because neither backend implements it. The integration tests replace that one call of the client with an SDK stub that answers `test/fixtures/cost_explorer/forecast.json` (a total of 15.0, in the documented shape); the other calls go to the backend. A LocalStack test checks that LocalStack still does not implement it, so that the mock can be removed when it does.

`bin/test` runs the plugin's tests, then Redmine's tests around administration and plugins; `bin/test --redmine` runs every Redmine test with the plugin installed, as the CI does. The plugin's tests also write the coverage of the plugin's own files (SimpleCov, Cobertura XML in `coverage/coverage.xml`), which CI uploads to [Codecov](https://codecov.io/gh/redmine-kit/redmine_serverless_costexplorer).

```sh
bin/test            # the plugin's tests and Redmine's tests around administration
bin/test --redmine  # with every Redmine test
bin/lint            # RuboCop
bin/services --down # stops PostgreSQL and moto or LocalStack
```

## To verify

- The requests and the answers in a real account (the tests use stubs and moto), including the number of pages of `GetCostAndUsage` by service
- The forecast against the console's month-end forecast
- The access error in a member account without "Linked account access"
- The interface endpoint `com.amazonaws.<region>.ce` from a VPC in us-east-1 and in another region
- The policies in [iam.md](iam.md) on a real role
