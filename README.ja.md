# Redmine Serverless Cost

[![CI](https://img.shields.io/github/actions/workflow/status/redmine-kit/redmine_serverless_cost/ci.yml?branch=main&label=CI)](https://github.com/redmine-kit/redmine_serverless_cost/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/codecov/c/github/redmine-kit/redmine_serverless_cost)](https://codecov.io/gh/redmine-kit/redmine_serverless_cost)
[![License](https://img.shields.io/github/license/redmine-kit/redmine_serverless_cost)](LICENSE)

AWS アカウントの費用を、AWS Cost Explorer から Redmine の管理画面に表示する Redmine のプラグインです。今月これまでの費用、今月の予測、先月の費用、サービスごとの費用、過去 30 日の日ごとの費用を表示します。オプションで、複数の Redmine を置くアカウントのために、コスト配分タグごとにも分けます。費用は毎日と依頼のときに取得してデータベースに保存するので、画面を表示しても AWS に要求を送りません。[Serverless](https://github.com/redmine-kit/serverless) は、[Redmine Serverless](https://github.com/redmine-kit/redmine_serverless) といっしょにインストールします。

[English](README.md)

> **状態:** 開発の初期です。「費用」のタブ、毎日の取得、「更新」のボタンを実装し、Redmine 7.0.3 で、SDK の応答のスタブと moto でテストしています。

<a id="documentation"></a>

## ドキュメント

- Web サイト: https://redmine-kit.github.io/redmine_serverless_cost/ja/ (English: https://redmine-kit.github.io/redmine_serverless_cost/)
- Markdown: [docs/ja/README.md](docs/ja/README.md) (English: [docs/README.md](docs/README.md))。[準備](docs/ja/setup.md)と [IAM の権限](docs/ja/iam.md)があります。

<a id="license"></a>

## ライセンス

Redmine Serverless Cost は、GNU General Public License バージョン 2 またはそれ以降のバージョンで公開しています。[LICENSE](LICENSE) を参照してください。Redmine project とは関係ありません。
