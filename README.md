# Redmine Serverless Cost

[![CI](https://img.shields.io/github/actions/workflow/status/redmine-kit/redmine_serverless_cost/ci.yml?branch=main&label=CI)](https://github.com/redmine-kit/redmine_serverless_cost/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/codecov/c/github/redmine-kit/redmine_serverless_cost)](https://codecov.io/gh/redmine-kit/redmine_serverless_cost)
[![License](https://img.shields.io/github/license/redmine-kit/redmine_serverless_cost)](LICENSE)

A Redmine plugin that shows the costs of the AWS account in Redmine's administration, from AWS Cost Explorer: this month so far, the forecast for this month, the previous month, the costs by service, and the daily costs of the last 30 days. Optionally, it splits the costs by a cost allocation tag, for an account that holds several Redmine instances. The costs are fetched daily and on request, and kept in the database; viewing the page makes no requests to AWS. [Serverless](https://github.com/redmine-kit/serverless) installs it together with [Redmine Serverless](https://github.com/redmine-kit/redmine_serverless).

[日本語](README.ja.md)

> **Status:** early development. The "Costs" tab, the daily fetch and the "Refresh" button are implemented and tested on Redmine 7.0.3 with SDK response stubs and moto.

## Documentation

- Website: https://redmine-kit.github.io/redmine_serverless_cost/ (日本語: https://redmine-kit.github.io/redmine_serverless_cost/ja/)
- Markdown: [docs/README.md](docs/README.md) (日本語: [docs/ja/README.md](docs/ja/README.md)), with [setup](docs/setup.md) and [IAM permissions](docs/iam.md)

## License

Redmine Serverless Cost is released under the GNU General Public License, version 2 or (at your option) any later version. See [LICENSE](LICENSE). Not affiliated with the Redmine project.
