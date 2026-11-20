# AGENTS.md

Guidelines for people and coding agents working in this repository. See [README.md](README.md) for an overview and [docs/](docs/README.md) for the design.

## What this project does

Redmine Kit AWS Cost Explorer (`redmine_kit_aws_costexplorer`) is a Redmine plugin that shows the costs of the AWS account from AWS Cost Explorer on the "Cost Explorer" tab of the "AWS" administration menu of redmine_kit_aws. It fetches the costs once a day (rake task `redmine_kit:aws:costexplorer:refresh`) and keeps them in the database. [Serverless](https://github.com/redmine-kit/serverless)'s image does not include it; its templates can set it up, off by default, for an image that adds the plugin (a derived image). It is in early development.

## Rules

- **Redmine's extension points only:** do not edit Redmine's own files.
- **Off without its settings:** without `REDMINE_COSTEXPLORER_ENABLED=true`, the plugin makes no requests to AWS. The tag split is off without `REDMINE_COSTEXPLORER_TAG_KEY`. Both settings are environment variables only; there is no settings page.
- **No requests from the web process:** each Cost Explorer request is charged. Pages only read the stored snapshots; only the daily rake task calls Cost Explorer. Keep the number of requests per fetch stated in the docs and on the page.
- **Tests:** added code has tests, run with Redmine's own mechanism (`bin/test` runs them in a container (Apple container, else Docker) with PostgreSQL and moto, or LocalStack with its token; [setup.md](docs/setup.md#tests)).
- **Redmine Kit Charges' provider (optional):** `ChargesProvider` reads a source of Redmine Kit Charges (this account, a shared billing view, a role with an external ID); `setup` registers it only when `RedmineKit::Charges` exists. It answers the provider's methods without subclassing, so that nothing here needs redmine_kit_charges to load. Its fetch also needs `REDMINE_COSTEXPLORER_ENABLED=true`.
- **Code layout:** `lib/redmine_kit/aws/costexplorer/` has the requests to Cost Explorer, `app/` the model, the controller and the view, `db/` the migration, `lib/tasks/` the rake task. `init.rb` calls `RedmineKit::Aws::Costexplorer.setup`.
- **Shared parts:** the administration menu, its tabs, the settings of the AWS clients and the test support come from [redmine_kit_aws](https://github.com/redmine-kit/redmine_aws), which the plugin requires. The tests load it from a checkout next to this one (`../redmine_kit_aws`, or `REDMINE_KIT_AWS_DIR`).
- **No secrets in the repository.**

## Documentation

- **Two languages.** English is the source (`README.md`, `docs/`); the Japanese translation is `README.ja.md` and `docs/ja/`, with the same file names. Change both together.
- **Layout.** The READMEs stay short. The details go in `docs/`, published at https://redmine-kit.github.io/redmine_aws_costexplorer/ with [redmine-kit/docs-skeleton](https://github.com/redmine-kit/docs-skeleton). `docs/README.md` has the overview and the features, `docs/setup.md` the sections Requirements, Installation, Configuration, AWS resources, IAM permissions, Network, Tests and To verify, in this order (the same in every Redmine Kit AWS plugin; IAM permissions there is one line that points to `docs/iam.md`), `docs/iam.md` the sections Permissions, Example policy, Resource-based policies and Not checked yet. Links to the documentation of Serverless and the other plugins are absolute URLs.
- **Anchors in Japanese.** Put `<a id="..."></a>` with the English heading's anchor before each Japanese heading.
- **Facts.** State only what has been checked, with the date and the source. Mark what has not been checked yet.
- **Japanese wording.** Plain, precise Japanese. Keep established technical terms. Do not use "版" for a version, write "通知" rather than "知らせ", "確認" rather than "確かめ", "インストール" rather than "入れ方", "コピー" rather than "写す", "バージョンアップ" for upgrading, and "例外を発生させる" for raising an exception.

## Commits

- English, imperative mood, 72 characters or fewer in the first line, no trailing period.
- One purpose per commit.
- Do not rewrite pushed history.

## Development environment

- **Apple container first, Docker too** (a public repository). Scripts (`bin/test`, databases, emulators) use Apple container (`container`) when it is installed and running, else Docker (other machines, CI); `CONTAINER_CLI=docker|container` chooses. Docs give both, Apple container first. Images are built from the `Dockerfile` with either tool. In Apple container, the test containers run on the networks that every repository shares, `redmine-kit-test` and `redmine-kit-test-internal` (no way out), each with an anchor container that runs all the time (`ensure_shared_network` in `bin/container_cli`; apple/container#2051, until macOS 27.3; the organization's `../AGENTS.md`). Docker keeps a Compose network per repository.
- **Libraries at their latest versions.** Dependencies are kept at their latest stable releases, pinned exactly in the lockfiles; a version held back has its reason next to the pin.
- Both are the organization's rules (`../AGENTS.md`, "Development environment").
