# 導入

Redmine AWS Cost Explorer を使うために、Redmine に必要なものです。インストール、設定、スケジュール、IAM の権限、ネットワークです。[Serverless](https://redmine-kit.github.io/serverless/ja/) のイメージには、このプラグインは入っていません。プラグインを追加したイメージ(派生のイメージ)のために、Serverless は、デプロイの設定ファイル(`redmine.json` の `costExplorer.enabled` と `costExplorer.allocationTag`。デフォルトは無効)から、これらを CloudFormation ですべて用意します。このページは、手で用意するときや、Serverless が作るものを確認するときのためのものです。

<a id="requirements"></a>

## 動作環境

- Redmine 7.0 以降。
- [Redmine AWS](https://redmine-kit.github.io/redmine_aws/ja/) (`redmine_aws`) 0.1 以降。「AWS」の管理メニューがあります (gem の依存です。チェックアウトでは、これもクローンします)。
- AWS の gem `aws-sdk-costexplorer`(gem の依存です。チェックアウトでは、プラグインの `Gemfile` が追加します)。
- Cost Explorer が有効な AWS アカウント([README.md](README.md#notes))。AWS Organizations のメンバーアカウントでは、管理アカウントが、メンバーアカウントに Cost Explorer を許している必要があります。
- rake のタスクを 1 日に 1 回実行するもの。

<a id="installation"></a>

## インストール

1. プラグインを `plugins/redmine_aws_costexplorer` に、Redmine AWS を `plugins/redmine_aws` に置きます。gem をインストールするか([gem](#gem))、リポジトリをクローンします([gem を使わないとき](#without-the-gem))。
2. プラグインの migration を実行します。スナップショットの表(`aws_costexplorer_snapshots`)を作ります。

   ```sh
   bin/rake redmine:plugins:migrate
   ```

3. 環境変数(下記)とスケジュール([スケジュール](#schedule))を設定します。

<a id="gem"></a>

### gem

バージョンのタグ(`v*`)ごとに、プラグインを gem として GitHub Packages(`https://rubygems.pkg.github.com/redmine-kit`。`.github/workflows/gem.yml`)に公開します。最初のバージョンは 0.1.0 です。GitHub Packages からのインストールには、公開のパッケージでも、`read:packages` のある GitHub のトークンが要ります。gem には、プラグインの実行に使うファイル(`init.rb`、`lib/`、`app/`、`assets/`、`config/`、`db/`、`LICENSE`)が入っていて、プラグインの `Gemfile` は入っていません。gem は `redmine_aws` に依存し、Bundler が同じソースからインストールします。Redmine は `plugins/` からだけプラグインを読むので、インストールした 2 つの gem をそこにリンクします。

```ruby
# Redmine の Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_aws_costexplorer'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <user>:<token>   # または変数 BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
ln -s "$(bundle info --path redmine_aws)" plugins/redmine_aws
ln -s "$(bundle info --path redmine_aws_costexplorer)" plugins/redmine_aws_costexplorer
```

<a id="without-the-gem"></a>

### gem を使わないとき

リポジトリを `plugins/redmine_aws_costexplorer` に、Redmine AWS を `plugins/redmine_aws` にクローンし、gem をインストールします。Redmine の `Gemfile` がプラグインの `Gemfile` を読み、`aws-sdk-costexplorer` を追加します。

```sh
git clone https://github.com/redmine-kit/redmine_aws.git plugins/redmine_aws
git clone https://github.com/redmine-kit/redmine_aws_costexplorer.git plugins/redmine_aws_costexplorer
bundle install
```

<a id="configuration"></a>

## 設定

設定の画面はありません。設定は 2 つとも環境変数で、デプロイが設定します(Serverless では `redmine.json` から)。

| キー | 説明 | パラメーター |
| --- | --- | --- |
| `REDMINE_COSTEXPLORER_ENABLED` | プラグインを有効にする。無効のときは、rake のタスクは要求を送らず、「Cost Explorer」のタブは、プラグインが無効なことを表示する | 必須。`true` で有効。ほかの値やないときは無効。rake のタスクを実行するプロセス(取得のため)と、web のプロセス(タブが、プラグインが有効かを表示するため)に設定する |
| `REDMINE_COSTEXPLORER_TAG_KEY` | コスト配分タグのキー。その値ごとの費用も表示する([README.md](README.md#costs-by-tag-optional)) | 省略可。例: `redmine:instance`。空かないときは無効(デフォルト)で、タグの要求も送らない。rake のタスクを実行するプロセスにだけ設定する。タブは、保存したデータからタグを読む。Serverless では `redmine.json` の `costExplorer.allocationTag` が設定する |

| 項目 | 説明 | 変える場所 |
| --- | --- | --- |
| AWS の認証情報とリージョン | プラグインは、Redmine のリージョンにかかわらず、いつも `us-east-1` の Cost Explorer を呼ぶ | SDK のいつもの取得元(Lambda のロール、インスタンスプロファイル、`AWS_*` の変数) |

タグごとに費用を分ける(`REDMINE_COSTEXPLORER_TAG_KEY`)ときは、Billing and Cost Management のコンソール(コスト配分タグ)で、タグのキーをコスト配分タグとして有効にします。有効になるまで、最大で 24 時間かかります。

<a id="aws-resources"></a>

## AWS リソース

プラグインは AWS のリソースを作らず、専用のリソースも要りません。Cost Explorer の API は、アカウントのグローバルのサービスです。

<a id="schedule"></a>

### スケジュール

rake のタスク `redmine_aws_costexplorer:refresh` を 1 日に 1 回実行します。

```sh
bin/rake redmine_aws_costexplorer:refresh
```

実行する時刻はいつでもかまいません。Cost Explorer のデータはおよそ 1 日に 1 回更新され、1 回の実行で要求は 3 件か 4 件です([README.md](README.md#fetching-the-costs))。取得が失敗するとタスクも失敗し(0 以外の終了コード。エラーは標準エラー出力)、スケジューラーが失敗を記録できます。プラグインが無効なら、何も取得しなかったことを出力して成功します。

| 環境 | タスクを動かすもの |
| --- | --- |
| Serverless | EventBridge のルール(`<instance>-costexplorer-refresh`)が、毎日、関数 `redmine-task` を `{"command": "rake", "args": ["redmine_aws_costexplorer:refresh"]}` で呼ぶ([Serverless の tasks.md](https://redmine-kit.github.io/serverless/ja/tasks.html#scheduled-runs)) |
| ほかの環境 | cron、systemd のタイマー、スケジュールで動くコンテナのタスクなど。Redmine のディレクトリで、Redmine と同じ環境変数でコマンドを実行する |

<a id="iam-permissions"></a>

## IAM 権限

プラグインに必要な権限と、ポリシーの例は [iam.md](iam.md) にあります。

<a id="network"></a>

## ネットワーク

| 宛先 | API | インターネットにつながらない VPC では |
| --- | --- | --- |
| Cost Explorer(`ce.us-east-1.amazonaws.com`) | `GetCostAndUsage`、`GetCostForecast` | NAT などの、インターネットへの経路。Serverless では `network.mode` を `nat` にする |

Cost Explorer を呼ぶのは、rake のタスクを実行するプロセスだけで、web のプロセスは呼びません。経路がないと、要求はタイムアウトします(プラグインは接続のタイムアウトを 5 秒にし、2 回再試行します)。そのときは「Cost Explorer」のタブにエラーを表示し、経路が必要なことを示します。

インターフェイスエンドポイントでも届く可能性はありますが、確認していません。AWS PrivateLink のガイドは、「AWS Cost Explorer」のサービス名として `com.amazonaws.<region>.ce` を挙げています(「AWS services that integrate with AWS PrivateLink」。2026-11-10 に確認)。一方、Cost Explorer の API は `us-east-1` にあります。ほかのリージョンでこのエンドポイントを作れるか、ほかのリージョンの VPC に `ce.us-east-1.amazonaws.com` を提供できるかは、まだ確認していません。Serverless の `network.mode` `endpoints` は、このエンドポイントを作りません。

<a id="tests"></a>

## テスト

テストは `test/` にあり、Redmine の標準のしくみで、Docker の Redmine 7.0.3 と PostgreSQL 16 で動かします。Cost Explorer は、`LOCALSTACK_AUTH_TOKEN`(CI では組織のシークレット)があれば LocalStack、なければ moto です。

<a id="unit-and-functional-tests"></a>

### 単体テストと機能テスト

SDK の応答のスタブを使います。応答は `test/fixtures/cost_explorer/` の JSON の本文で、SDK が実際の応答と同じように解析します。API リファレンスの応答の構文に合わせたもので、アカウントから記録したものではありません。テストには AWS のアカウントがないためです。

<a id="integration-tests"></a>

### 結合テスト

`test/integration/cost_explorer_test.rb` が、プラグインの要求を、SDK と HTTP を通してバックエンドに送ります。取得、タグありの取得、rake のタスクです。トークンがあれば LocalStack で動かし、LocalStack が起動しないときは、`bin/services` がログを出して実行が失敗します。どちらで動いたかはログに出ます(`AWS backend: ...`)。

LocalStack の Cost Explorer は、Ultimate のプランのものです。対応状況のページには、`GetCostAndUsage` はあるが `GetCostForecast` はなく、費用のデータもないと書かれています(LocalStack の Cost Explorer のページ。2026-11-10 に確認)。LocalStack 2026.10.6 では(2026-11-10 に確認)、`GetCostAndUsage` はプラグインのすべての要求(サービスごとの月ごと、タグごとの月ごと、日ごと)に、実際の応答の形で結果なしを返し、`GetCostForecast` は `InternalFailure`(「The get_cost_forecast action has not been implemented」)を返しました。そのため LocalStack では費用が空なことを確認し、金額は moto とスタブで確認します。

トークンがないときは moto を使います。moto は、API で前もって渡した結果(`/moto-api/static/ce/cost-and-usage-results`)で `GetCostAndUsage` に答えるので、テストは金額を確認します。moto には `GetCostForecast` がありません(500 を返す)。

<a id="the-mocked-call"></a>

### モックする呼び出し

モックするのは `GetCostForecast` だけです。どちらのバックエンドも実装していないためです。結合テストは、クライアントのこの呼び出しだけを、`test/fixtures/cost_explorer/forecast.json`(合計 15.0。ドキュメントの形)を返す SDK のスタブに置き換え、ほかの呼び出しはバックエンドに送ります。LocalStack がまだ実装していないことをテストで確認しているので、実装されたらモックを外せます。

<a id="running-the-tests"></a>

### テストの実行

`bin/test` は、プラグインのテストと、管理画面とプラグインのまわりの Redmine のテストを動かします。`bin/test --redmine` は、CI と同じく、プラグインを入れた状態で Redmine のすべてのテストを動かします。テストの Redmine には、隣にチェックアウトした Redmine AWS (`../redmine_aws`) か、`REDMINE_AWS_DIR` のディレクトリのものを入れます。CI は `redmine-kit/redmine_aws` をチェックアウトします。プラグインのテストは、プラグインのファイルのカバレッジ(SimpleCov。Cobertura の XML を `coverage/coverage.xml` に)も書き、CI が [Codecov](https://codecov.io/gh/redmine-kit/redmine_aws_costexplorer) に送ります。

```sh
bin/test            # プラグインのテストと、管理画面のまわりの Redmine のテスト
bin/test --redmine  # Redmine のすべてのテストも
bin/lint            # RuboCop
bin/services --down # PostgreSQL と、moto か LocalStack を止める
```

<a id="to-verify"></a>

## 未確認の事項

- 実際のアカウントでの要求と応答(テストはスタブと moto)。サービスごとの `GetCostAndUsage` のページの数も
- 予測を、コンソールの月末の予測と比べる
- 「Linked account access」のないメンバーアカウントでのアクセスのエラー
- us-east-1 とほかのリージョンの VPC からの、インターフェイスエンドポイント `com.amazonaws.<region>.ce`
- [iam.md](iam.md) のポリシーを、実際のロールで
