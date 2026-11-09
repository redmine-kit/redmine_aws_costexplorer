# Redmine Serverless Cost Explorer

[![CI](https://img.shields.io/github/actions/workflow/status/redmine-kit/redmine_serverless_costexplorer/ci.yml?branch=main&label=CI)](https://github.com/redmine-kit/redmine_serverless_costexplorer/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/codecov/c/github/redmine-kit/redmine_serverless_costexplorer)](https://codecov.io/gh/redmine-kit/redmine_serverless_costexplorer)
[![License](https://img.shields.io/github/license/redmine-kit/redmine_serverless_costexplorer)](LICENSE)

A Redmine plugin that shows the costs of the AWS account in Redmine's administration, from AWS Cost Explorer: this month so far, the forecast for this month, the previous month, the costs by service, and the daily costs of the last 30 days. Optionally, it splits the costs by a cost allocation tag, for an account that holds several Redmine instances. The costs are fetched daily, and again in the background when the page is opened and the data is older than an hour (at most once per hour); the web process itself makes no requests to AWS. [Serverless](https://github.com/redmine-kit/serverless)'s image does not include it; its templates can set it up, off by default, for an image that adds the plugin (a derived image).

[日本語](README.ja.md)

> **Status:** early development. The "Cost Explorer" tab, the daily fetch, the fetch on view and the "Refresh" button are implemented and tested on Redmine 7.0.3 with SDK response stubs and moto.

## Documentation

- Website: https://redmine-kit.github.io/redmine_serverless_costexplorer/ (日本語: https://redmine-kit.github.io/redmine_serverless_costexplorer/ja/)
- Markdown: [docs/README.md](docs/README.md) (日本語: [docs/ja/README.md](docs/ja/README.md)), with [setup](docs/setup.md) and [IAM permissions](docs/iam.md)

## License

Redmine Serverless Cost Explorer is released under the GNU General Public License, version 2 or (at your option) any later version. See [LICENSE](LICENSE). Not affiliated with the Redmine project.
