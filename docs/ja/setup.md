# 準備

Redmine Serverless Cost を使うために、Redmine に必要なものです。インストール、設定、スケジュール、IAM の権限、ネットワークです。[Serverless](https://redmine-kit.github.io/serverless/ja/) は、デプロイの設定ファイル(`redmine.json` の `cost.enabled` と `cost.allocationTag`)から、これらを CloudFormation ですべて用意します。このページは、手で用意するときや、Serverless が作るものを確認するときのためのものです。

<a id="requirements"></a>

## 必要なもの

- Redmine 7.0 以降。
- AWS の gem `aws-sdk-costexplorer`(gem の依存です。チェックアウトでは、プラグインの `Gemfile` が足します)。
- Cost Explorer が有効な AWS アカウント([README.md](README.md#notes))。AWS Organizations のメンバーアカウントでは、管理アカウントが、メンバーアカウントに Cost Explorer を許している必要があります。
- rake のタスクを毎日実行するものと、Redmine のジョブを実行するもの(「更新」のボタンのため)。

<a id="installation"></a>

## インストール

**プラグインの入手:** バージョンのタグ(`v*`)ごとに、プラグインを gem として GitHub Packages(`https://rubygems.pkg.github.com/redmine-kit`。`.github/workflows/gem.yml`)に公開します。最初のバージョンは 0.1.0 です。GitHub Packages からのインストールには、公開のパッケージでも、`read:packages` のある GitHub のトークンが要ります。gem には、プラグインの実行に使うファイル(`init.rb`、`lib/`、`app/`、`config/`、`db/`、`LICENSE`)が入っていて、プラグインの `Gemfile` は入っていません。Redmine は `plugins/` からだけプラグインを読むので、インストールした gem をそこにリンクします。

```ruby
# Redmine の Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_serverless_cost'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <user>:<token>   # または変数 BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
ln -s "$(bundle info --path redmine_serverless_cost)" plugins/redmine_serverless_cost
```

gem を使わないときは、リポジトリを `plugins/redmine_serverless_cost` にクローンし(`git clone https://github.com/redmine-kit/redmine_serverless_cost.git plugins/redmine_serverless_cost`)、`bundle install` を実行します(Redmine の `Gemfile` がプラグインの `Gemfile` を読み、`aws-sdk-costexplorer` を足します)。

1. 上のとおり、プラグインを `plugins/redmine_serverless_cost` に置きます。
2. `bin/rake redmine:plugins:migrate` を実行します。スナップショットの表(`serverless_cost_snapshots`)を作ります。
3. 環境変数(下記)とスケジュール([スケジュール](#schedule))を設定します。

<a id="configuration"></a>

## 設定

設定の画面はありません。設定は 2 つとも環境変数で、デプロイが設定します(Serverless では `redmine.json` から)。

| 設定 | 場所 | 内容 |
| --- | --- | --- |
| `REDMINE_COST_ENABLED` | すべてのプロセス(web、ジョブ、rake)の環境変数 | `true` でプラグインが有効になる。ほかの値や、ないときは無効のまま。rake のタスクとジョブは要求を送らず、「費用」のタブは、プラグインが無効なことを表示する |
| `REDMINE_COST_TAG_KEY` | 同じ | オプション。コスト配分タグのキー(ふつうは `redmine:instance`)。その値ごとの費用も表示する([README.md](README.md#costs-by-tag-optional))。空かないとき: 無効(既定)で、タグの要求も送らない。Serverless では、`redmine.json` の `cost.allocationTag` が設定する |
| AWS の認証情報とリージョン | SDK のいつもの取得元(Lambda のロール、インスタンスプロファイル、`AWS_*` の変数) | プラグインは、Redmine のリージョンにかかわらず、いつも `us-east-1` の Cost Explorer を呼ぶ |

- **タグを有効にする:** Billing and Cost Management のコンソール(コスト配分タグ)で、タグのキーをコスト配分タグとして有効にします。`REDMINE_COST_TAG_KEY` を使うときだけ必要です。有効になるまで、最大で 24 時間かかります。

<a id="aws-resources"></a>

## AWS のリソース

プラグインは AWS のリソースを作らず、専用のリソースも要りません。Cost Explorer の API は、アカウントのグローバルのサービスです。

<a id="schedule"></a>

### スケジュール

rake のタスク `redmine_serverless_cost:refresh` を 1 日に 1 回実行します。

```sh
bin/rake redmine_serverless_cost:refresh
```

- **時刻:** 何時でもかまいません。Cost Explorer のデータは、およそ 1 日に 1 回更新されます。1 日 1 回で、要求は 3 件か 4 件です([README.md](README.md#fetching-the-costs))。
- **終了コード:** 取得が失敗すると、タスクも失敗します(0 以外の終了コード。エラーは標準エラー出力)。スケジューラーに失敗を記録させるためです。プラグインが無効なら、何も取得しなかったことを出力して、成功します。
- **Serverless では:** EventBridge のルール(`<instance>-cost-refresh`)が、毎日、関数 `redmine-task` を `{"command": "rake", "args": ["redmine_serverless_cost:refresh"]}` で呼びます([Serverless の tasks.md](https://redmine-kit.github.io/serverless/ja/tasks.html#scheduled-runs))。
- **ほかの環境では:** cron、systemd のタイマー、スケジュールで動くコンテナのタスクなどで、Redmine のディレクトリで、Redmine と同じ環境変数でコマンドを実行します。

<a id="iam-permissions"></a>

## IAM の権限

プラグインに必要な権限と、ポリシーの例は [iam.md](iam.md) にあります。

<a id="network"></a>

## ネットワーク

| 宛先 | API | インターネットにつながらない VPC では |
| --- | --- | --- |
| Cost Explorer(`ce.us-east-1.amazonaws.com`) | `GetCostAndUsage`、`GetCostForecast` | NAT などの、インターネットへの経路。Serverless では `network.mode` を `nat` にする |

- **どのプロセスか:** 取得するプロセスだけです。rake のタスクを実行するプロセスと、Redmine のジョブを実行するプロセスです。ジョブを別の場所で実行するなら、web のプロセスは Cost Explorer を呼びません(Rails の既定のアダプターでは、ジョブは web のプロセスの中で動くので、web のプロセスが呼びます)。
- **インターフェイスエンドポイント:** AWS PrivateLink のガイドは、「AWS Cost Explorer」のサービス名として `com.amazonaws.<region>.ce` を挙げています(「AWS services that integrate with AWS PrivateLink」。2026-11-10 に確認)。Cost Explorer の API は `us-east-1` にあります。ほかのリージョンでこのエンドポイントを作れるか、ほかのリージョンの VPC に `ce.us-east-1.amazonaws.com` を提供できるかは、まだ確認していません。Serverless の `network.mode` `endpoints` は、このエンドポイントを作りません。
- **つながらないとき:** 経路がないと、要求はタイムアウトします(プラグインは、接続のタイムアウトを 5 秒にし、2 回再試行します)。「費用」のタブにエラーを表示し、経路が必要なことを示します。

<a id="tests"></a>

## テスト

テストは `test/` にあり、Redmine の標準のしくみで、Docker の Redmine 7.0.3、PostgreSQL 16、moto で動かします。

- **単体テストと機能テスト:** SDK の応答のスタブを使います。応答は `test/fixtures/cost_explorer/` の JSON の本文で、SDK が、実際の応答と同じように解析します。API リファレンスの応答の構文に合わせたもので、アカウントから記録したものではありません。テストには AWS のアカウントがないためです。
- **moto での結合テスト:** moto は、API で前もって渡した結果(`/moto-api/static/ce/cost-and-usage-results`)で `GetCostAndUsage` に答えます。要求と解析は、SDK と HTTP を通ります。moto には `GetCostForecast` がない(500 を返す)ので、予測のない取得のテストにもなります。rake のタスクも moto に対して動かします。
- **LocalStack は使わない:** LocalStack は、`GetCostAndUsage` を Ultimate のプランでだけ実装し、費用のデータはなく、`GetCostForecast` はありません(LocalStack の Cost Explorer のページ。2026-11-10 に確認)。そのため、テストでは使いません。

`bin/test` は、プラグインのテストと、管理画面とプラグインのまわりの Redmine のテストを動かします。`bin/test --redmine` は、CI と同じく、プラグインを入れた状態で Redmine のすべてのテストを動かします。プラグインのテストは、プラグインのファイルのカバレッジ(SimpleCov。Cobertura の XML を `coverage/coverage.xml` に)も書き、CI が [Codecov](https://codecov.io/gh/redmine-kit/redmine_serverless_cost) に送ります。

```sh
bin/test            # プラグインのテストと、管理画面のまわりの Redmine のテスト
bin/test --redmine  # Redmine のすべてのテストも
bin/lint            # RuboCop
bin/services --down # PostgreSQL と moto を止める
```

<a id="to-verify"></a>

## 確認すること

- 実際のアカウントでの要求と応答(テストはスタブと moto)。サービスごとの `GetCostAndUsage` のページの数も
- 予測を、コンソールの月末の予測と比べる
- 「Linked account access」のないメンバーアカウントでのアクセスのエラー
- us-east-1 とほかのリージョンの VPC からの、インターフェイスエンドポイント `com.amazonaws.<region>.ce`
- [iam.md](iam.md) のポリシーを、実際のロールで
