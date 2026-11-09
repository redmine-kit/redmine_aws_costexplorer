# AGENTS.md

Guidelines for people and coding agents working in this repository. See [README.md](README.md) for an overview and [docs/](docs/README.md) for the design.

## What this project does

Redmine Serverless Cost (`redmine_serverless_cost`) is a Redmine plugin that shows the costs of the AWS account from AWS Cost Explorer on the "Costs" tab of the shared "Serverless" administration menu. It fetches the costs daily (rake task `redmine_serverless_cost:refresh`) and on request (the "Refresh" button, through a job), and keeps them in the database. [Serverless](https://github.com/redmine-kit/serverless) installs it together with [Redmine Serverless](https://github.com/redmine-kit/redmine_serverless). It is in early development.

## Rules

- **Redmine's extension points only:** do not edit Redmine's own files.
- **Off without its settings:** without `REDMINE_COST_ENABLED=true`, the plugin makes no requests to AWS. The tag split is off without `REDMINE_COST_TAG_KEY`. Both settings are environment variables only; there is no settings page.
- **No requests on view:** each Cost Explorer request is charged. Pages read the stored snapshots; only the rake task and the job call Cost Explorer. Keep the number of requests per fetch stated in the docs and on the page.
- **Tests:** added code has tests, run with Redmine's own mechanism (`bin/test` runs them in Docker with PostgreSQL and moto; [setup.md](docs/setup.md#tests)).
- **Code layout:** `lib/redmine_serverless_cost/` has the requests to Cost Explorer, `app/` the model, the job, the controller and the view, `db/` the migration, `lib/tasks/` the rake task. `init.rb` calls `RedmineServerlessCost.setup`.
- **Shared files:** `lib/redmine_serverless_admin.rb`, `app/controllers/serverless_admin_controller.rb` and `app/views/serverless_admin/_tabs.html.erb` are the same in every Redmine Serverless plugin. Change them in all plugins together and raise `SHARED_VERSION`.
- **No secrets in the repository.**

## Documentation

- **Two languages.** English is the source (`README.md`, `docs/`); the Japanese translation is `README.ja.md` and `docs/ja/`, with the same file names. Change both together.
- **Layout.** The READMEs stay short. The details go in `docs/`, published at https://redmine-kit.github.io/redmine_serverless_cost/ with [redmine-kit/docs-skeleton](https://github.com/redmine-kit/docs-skeleton). `docs/README.md` has the overview and the features, `docs/setup.md` the sections Requirements, Installation, Configuration, AWS resources, IAM permissions, Network, Tests and To verify, in this order (the same in every Redmine Serverless plugin; IAM permissions there is one line that points to `docs/iam.md`), `docs/iam.md` the sections Permissions, Example policy, Resource-based policies and Not checked yet. Links to the documentation of Serverless and the other plugins are absolute URLs.
- **Anchors in Japanese.** Put `<a id="..."></a>` with the English heading's anchor before each Japanese heading.
- **Facts.** State only what has been checked, with the date and the source. Mark what has not been checked yet.
- **Japanese wording.** Plain, precise Japanese. Keep established technical terms. Do not use "版" for a version, write "通知" rather than "知らせ", "確認" rather than "確かめ", "インストール" rather than "入れ方", "コピー" rather than "写す", "バージョンアップ" for upgrading, and "例外を発生させる" for raising an exception.

## Commits

- English, imperative mood, 72 characters or fewer in the first line, no trailing period.
- One purpose per commit.
- Do not rewrite pushed history.
