# Redmine Serverless Cost Explorer

[![CI](https://img.shields.io/github/actions/workflow/status/redmine-kit/redmine_serverless_costexplorer/ci.yml?branch=main&label=CI)](https://github.com/redmine-kit/redmine_serverless_costexplorer/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/codecov/c/github/redmine-kit/redmine_serverless_costexplorer)](https://codecov.io/gh/redmine-kit/redmine_serverless_costexplorer)
[![License](https://img.shields.io/github/license/redmine-kit/redmine_serverless_costexplorer)](LICENSE)

AWS アカウントの費用を、AWS Cost Explorer から Redmine の管理画面に表示する Redmine のプラグインです。今月これまでの費用、今月の予測、先月の費用、サービスごとの費用、過去 30 日の日ごとの費用を表示します。オプションで、複数の Redmine を置くアカウントのために、コスト配分タグごとにも分けます。費用は毎日取得してデータベースに保存し、ページを開いたときにデータが 1 時間より古ければ、裏で取得し直します(1 時間に 1 回まで)。web のプロセスは AWS に要求を送りません。[Serverless](https://github.com/redmine-kit/serverless) のイメージには入っていません。Serverless のテンプレートは、プラグインを足したイメージ(派生のイメージ)のために、このプラグインの設定を用意できます(既定は無効)。

[English](README.md)

> **状態:** 開発の初期です。「Cost Explorer」のタブ、毎日の取得、開いたときの取得、「更新」のボタンを実装し、Redmine 7.0.3 で、SDK の応答のスタブと moto でテストしています。

<a id="documentation"></a>

## ドキュメント

- Web サイト: https://redmine-kit.github.io/redmine_serverless_costexplorer/ja/ (English: https://redmine-kit.github.io/redmine_serverless_costexplorer/)
- Markdown: [docs/ja/README.md](docs/ja/README.md) (English: [docs/README.md](docs/README.md))。[準備](docs/ja/setup.md)と [IAM の権限](docs/ja/iam.md)があります。

<a id="license"></a>

## ライセンス

Redmine Serverless Cost Explorer は、GNU General Public License バージョン 2 またはそれ以降のバージョンで公開しています。[LICENSE](LICENSE) を参照してください。Redmine project とは関係ありません。
