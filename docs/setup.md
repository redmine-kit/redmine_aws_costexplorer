# Setup

What a Redmine server needs to use Redmine Kit AWS Cost Explorer: installation, configuration, the schedule, IAM permissions and network access. [Serverless](https://redmine-kit.github.io/serverless/)'s image does not include the plugin. For an image that adds it (a derived image), Serverless sets all of this up with CloudFormation from its deployment configuration file (`costExplorer.enabled` and `costExplorer.allocationTag` in `redmine.json`, off by default); this page is for setting it up by hand, or for checking what Serverless creates.

## Requirements

- Redmine 7.0 or later.
- AWS's gem `aws-sdk-costexplorer` (a dependency of the gem; with a checkout, the plugin's `Gemfile` adds it).
- An AWS account where Cost Explorer is enabled ([README.md](README.md#notes)). In a member account of AWS Organizations, the management account must allow member accounts to use Cost Explorer.
- Something that runs the rake task once a day.

### Required plugins

| Plugin | Used for |
| --- | --- |
| [Redmine Kit AWS](https://github.com/redmine-kit/redmine_aws) | the AWS administration menu and the settings shared by the AWS plugins |

Without it, Redmine stops at boot and names it. Installed as a gem, this plugin installs it
([Installation](#installation)).

### Optional plugins

| Plugin | With it |
| --- | --- |
| [Redmine Kit Billing](https://github.com/redmine-kit/redmine_kit_billing) | the AWS charges as a source of Billing |
| [Redmine Kit Help](https://github.com/redmine-kit/redmine_help) | this plugin's help in the Help panel |
| [Redmine Kit UI](https://github.com/redmine-kit/redmine_kit_ui) | the new UI's screen of the Cost Explorer tab ([README.md](README.md#in-the-new-ui)) |

## Installation

1. Install the plugin as a gem ([Gem](#gem)), or put checkouts of it and of [Redmine Kit AWS](https://redmine-kit.github.io/redmine_aws/), which it requires, in Redmine's `plugins/` ([Without the gem](#without-the-gem)). The order doesn't matter: at boot, Redmine stops and names `redmine_kit_aws` when it is missing ([Required plugins](#required-plugins)).
2. Run `bundle install` in Redmine's folder.
3. Run the plugin's migrations. They create the table of snapshots (`aws_costexplorer_snapshots`).

   ```sh
   bin/rails redmine:plugins:migrate RAILS_ENV=production
   ```
4. Set the environment variables (below) and the schedule ([Schedule](#schedule)).
5. Restart Redmine.

### Gem

**As a gem** (first choice): add it to Redmine's `Gemfile.local`, in a block of Redmine Kit's registry on GitHub Packages (`https://rubygems.pkg.github.com/redmine-kit`, where `bin/release` publishes it: [Releasing](#releasing)). Bundler takes the plugins it requires from there too ([Required plugins](#required-plugins)), and never takes these gems from rubygems.org. The registry needs a GitHub token with `read:packages`, even for a public package, given to Bundler in the environment variable `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` (`<user>:<token>`), never in a file of a repository.

```ruby
# Redmine's Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_kit_aws_costexplorer'
end
```

**From the repositories** (for development), Bundler takes the gems from git instead; it doesn't take the plugins a gem requires from git, so their lines come too:

```ruby
# Redmine's Gemfile.local
gem 'redmine_kit_aws', git: 'https://github.com/redmine-kit/redmine_aws.git', branch: 'main'
gem 'redmine_kit_aws_costexplorer', git: 'https://github.com/redmine-kit/redmine_aws_costexplorer.git', branch: 'main'
```

Bundler requires `boot/redmine_kit_aws_costexplorer.rb`, which hands the gem's folder to Redmine's plugin loader (and, from the gems it depends on, Redmine Kit AWS's): Redmine runs the gem's `init.rb`, serves its assets, strings, views and migrations, adds its `lib/` and `app/` to Rails' code loader and draws its routes, as for a plugin in `plugins/`, so no link in `plugins/` is needed. A folder of the same id in `plugins/` wins over the gem. The gem holds the run-time files; the plugin's `Gemfile` is not in it.

### Without the gem

Clone the repositories into Redmine's `plugins/`, in folders named after the plugins' ids, which differ from the repositories' names:

```sh
git clone https://github.com/redmine-kit/redmine_aws.git plugins/redmine_kit_aws
git clone https://github.com/redmine-kit/redmine_aws_costexplorer.git plugins/redmine_kit_aws_costexplorer
```

Nothing of the plugin has to load before Rails starts, so it needs no line in `Gemfile.local`; Redmine's `Gemfile` loads the plugin's, which adds the gems it uses.

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

A run stops the service containers it started (it doesn't remove them) when it ends, whether the tests pass, fail or are interrupted. Containers that were running before the run, or that another run of this repository still uses, are left running. `KEEP_SERVICES=1` keeps them running after the run.

The tests stay on moto and LocalStack, not on [AWS Emulator](https://docs.aws.amazon.com/emulator/latest/userguide/), which the organization uses for tests against AWS: AWS Emulator 1.0.512 (checked on 2026-11-19) answers `NotImplemented` to `GetCostAndUsage`, `GetCostForecast` and `GetDimensionValues`, and only moto can load cost data for the tests. They move to the emulator once it supports them.

### Unit and functional tests

These use SDK response stubs. The answers are JSON bodies in `test/fixtures/cost_explorer/`, which the SDK parses as real answers. They follow the response syntax of the API reference; they are not recorded from an account, because the tests have no AWS account.

### Integration tests

`test/integration/cost_explorer_test.rb` sends the plugin's requests through the SDK and HTTP to the backend: a fetch, a fetch with the tag, and the rake task. With the token they run on LocalStack; if LocalStack does not start, `bin/services` shows its logs and the run fails. The log names the backend (`AWS backend: ...`).

LocalStack's Cost Explorer is in the Ultimate plan. Its coverage page lists `GetCostAndUsage` but not `GetCostForecast`, and says it has no cost data (LocalStack's Cost Explorer page, checked on 2026-11-10). On LocalStack 2026.10.6 (checked on 2026-11-10), `GetCostAndUsage` answered every request of the plugin (monthly by service, monthly by the tag, daily) in the real response shape with no results, and `GetCostForecast` answered `InternalFailure` ("The get_cost_forecast action has not been implemented"). So on LocalStack the tests check the empty costs, and the amounts are checked with moto and the stubs.

Without the token, moto answers `GetCostAndUsage` with results given in advance through its API (`/moto-api/static/ce/cost-and-usage-results`), so the tests check the amounts. moto has no `GetCostForecast` (it answers 500).

### Redmine Kit Billing

The provider of Redmine Kit Billing (`charges_provider_test.rb`) is tested with SDK response stubs: the requests of each kind of source (this account, a shared billing view's `BillingViewArn`, AssumeRole with the external ID through a stubbed STS), the rows, the account statement's requests, pages and lines (`charges_provider_statement_test.rb`), the retries on `LimitExceededException`, and the settings it refuses. `test/integration/charges_test.rb` runs one source through Redmine Kit Billing's daily fetch, and an account statement through the provider, on moto, the backend that can load Cost Explorer data (AWS Emulator answers `NotImplemented`; moto ignores `BillingViewArn`, so billing views are checked with the stubs only). It needs Redmine Kit Billing in the test image: `bin/test_image` adds a checkout next to this one (`../redmine_kit_billing`, or `REDMINE_KIT_BILLING_DIR`) with Redmine Kit Organizations, which Redmine Kit Billing requires (`../redmine_kit_organizations`, or `REDMINE_KIT_ORGANIZATIONS_DIR`), and without them (CI, where that repository is private) the daily fetch's test is skipped.

### The mocked call

Only `GetCostForecast` is mocked, because neither backend implements it. The integration tests replace that one call of the client with an SDK stub that answers `test/fixtures/cost_explorer/forecast.json` (a total of 15.0, in the documented shape); the other calls go to the backend. A LocalStack test checks that LocalStack still does not implement it, so that the mock can be removed when it does.

### Running the tests

`bin/test` runs the plugin's tests with [Redmine Kit UI](https://github.com/redmine-kit/redmine_kit_ui) installed (from the checkout next to this one, `../redmine_kit_ui` at `HEAD`; `REDMINE_KIT_UI` and `REDMINE_KIT_UI_REF` choose another), then without it, then Redmine's tests around administration and plugins; `bin/test --redmine` runs every Redmine test with the plugin installed, as the CI does. The tests build Redmine with Redmine Kit AWS from a checkout next to this one (`../redmine_kit_aws`), or from the directory in `REDMINE_KIT_AWS_DIR`; CI checks out `redmine-kit/redmine_aws`. With `COVERAGE=1`, the plugin's tests also write the coverage of the plugin's own files (SimpleCov, Cobertura XML in `coverage/coverage.xml`) and run in one process. CI sets it on Ruby 4.0 and uploads the report to [Codecov](https://codecov.io/gh/redmine-kit/redmine_aws_costexplorer) with the flag `plugin`. The upload authenticates with OIDC (`id-token: write`), so no token is stored as a secret. Codecov's statuses are informational and never fail a commit or a pull request (`codecov.yml`). CI runs the lint and the tests on Ruby 3.2 and 4.0; locally, `TEST_RUBY=3.2 bin/test` (or `bin/lint`) runs them on Ruby 3.2.

`bin/test-gem` checks the gem as the template of the organization's plugins does: it builds the gems of the plugin and of Redmine Kit AWS from the checkouts, takes the checkouts out of `plugins/`, installs the gems as [Gem](#gem) says and starts Redmine with every file loaded (`zeitwerk:check`, and the production environment, which loads them at start-up), checking that each plugin comes from its gem's folder with its boot file, code, routes, migrations and assets; then again with the checkouts back in `plugins/`, which win. CI runs it too, so a file missing from the gem fails before adapters install it.

```sh
bin/test            # the plugin's tests and Redmine's tests around administration
bin/test --redmine  # with every Redmine test
COVERAGE=1 bin/test # with the coverage in coverage/coverage.xml
bin/lint            # RuboCop
bin/test-gem        # the gems: built, installed, booted from the gems, then from plugins/
bin/services --down # stops PostgreSQL and moto or LocalStack
```

The new UI's module is checked in `frontend/` with Node.js (the version in `frontend/.nvmrc`); `.npmrc` has `ignore-scripts=true`, and `@redmine-kit/ui` and `@redmine-kit/plugin` come from the checkout of the ui repository next to this one (`../../ui/packages/…`):

```sh
cd frontend
npm install
npm run check       # type check, the components' tests (vitest), the build, kit-check-ui, the Storybook's build
npm run storybook   # the Storybook of the tab's states, on port 6008
```

## Releasing

`bin/release` publishes the gem of the gemspec's version to Redmine Kit's registry on GitHub Packages, from a clean
`main` only: the version must be newer than the last tag `v<version>`, the required plugins must resolve from the
registry at their ranges (`config/dependencies.yml`), and `bin/lint`, `bin/test` and `bin/test-gem` must pass. It
pushes with the key `github` of `~/.gem/credentials` (`:github: Bearer <token>`, a token with `write:packages`) and
reads the registry with `BUNDLE_RUBYGEMS__PKG__GITHUB__COM`; no token goes into the repository or the output. It makes
the signed tag `v<version>` and prints the command that pushes it. Versions are semantic: a change that breaks a plugin
using this one raises the major version (the minor one before 1.0), and the ranges in the plugins that require it.

## To verify

- The requests and the answers in a real account (the tests use stubs and moto), including the number of pages of `GetCostAndUsage` by service
- The forecast against the console's month-end forecast
- The access error in a member account without "Linked account access"
- The interface endpoint `com.amazonaws.<region>.ce` from a VPC in us-east-1 and in another region
- The policies in [iam.md](iam.md) on a real role
