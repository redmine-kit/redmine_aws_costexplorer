# Redmine Serverless Cost

Redmine Serverless Cost(`redmine_serverless_cost`)は、AWS アカウントの費用を、AWS Cost Explorer から Redmine の管理画面に表示する Redmine のプラグインです。共通の「Serverless」の管理メニューに、「費用」のタブを足します。Redmine そのもののファイルは変えません。開発の初期です(バージョン 0.1.0)。

- [準備](setup.md): 必要なもの、インストール、設定、AWS のリソース、ネットワーク、テスト
- [IAM の権限](iam.md): 権限、ポリシーの例、リソースベースのポリシー

このプラグインは、AWS アカウントを Redmine だけに使う前提です。アカウントの費用が、そのまま Redmine の費用です。複数の Redmine を置くアカウントのために、コスト配分タグごとにも分けられます(オプション。既定は無効)。

<a id="features"></a>

## 機能

機能ごとに、有効になる条件があります。`REDMINE_COST_ENABLED=true` がなければ、プラグインは AWS に要求を送りません。

| 機能 | 内容 | 有効になる条件 | ページ |
| --- | --- | --- | --- |
| 「費用」のタブ | AWS アカウントの費用。今月これまで、今月の予測、先月、サービスごと、過去 30 日の日ごと | `REDMINE_COST_ENABLED=true`。管理者 | [タブに表示するもの](#what-the-tab-shows) |
| 毎日の取得 | rake のタスク `redmine_serverless_cost:refresh` が費用を取得し、データベースに保存する | 同上。スケジュールで毎日実行する | [setup.md](setup.md#schedule) |
| 「更新」のボタン | 今すぐの取得をキューに入れる。1 時間に 1 回まで | 同上 | [費用の取得](#fetching-the-costs) |
| タグごとの費用 | コスト配分タグ(ふつうは `redmine:instance`)の値ごとの、今月と先月の費用 | `REDMINE_COST_TAG_KEY` がある(既定は無効) | [タグごとの費用](#costs-by-tag-optional) |

<a id="what-the-tab-shows"></a>

## タブに表示するもの

主な表示は、アカウント全体です。見出しは「この AWS アカウントの費用」です。

| 欄 | 内容 | Cost Explorer への要求 |
| --- | --- | --- |
| 今月これまで | 今月の、今日までの費用。今日のこれまでの費用を含む | `GetCostAndUsage`。月ごと、サービスごと。先月の 1 日から明日まで(サービスの合計) |
| 今月の予測 | 昨日までの費用と、Cost Explorer の今日から月末までの予測の合計。Cost Explorer に予測がないとき(たとえば、履歴の短いアカウント)は、そう表示する | `GetCostForecast`。今日から来月の 1 日まで |
| 先月 | 先月の費用 | 「今月これまで」と同じ要求 |
| サービスごと | サービスごとの今月と先月の費用。今月の多い順 | 同じ要求 |
| 日ごと(過去 30 日) | 日ごとの費用と、いちばん多い日に対する割合の棒。棒は Redmine の進捗のバー(HTML と CSS。JavaScript なし) | `GetCostAndUsage`。日ごと。29 日前(月の 1 日のほうが前なら、その日)から明日まで |
| コスト配分タグごと | `REDMINE_COST_TAG_KEY` があるときだけ。タグの値ごとの今月と先月の費用。タグのない費用は「(タグなし)」 | `GetCostAndUsage`。月ごと、タグごと |

- **金額:** 非ブレンドコスト(`UnblendedCost`)です。通貨は Cost Explorer が返すもの(USD)で、小数 2 桁で表示します。
- **見込み:** Cost Explorer は、最近の期間を見込み(estimated)とします。画面では、その横に「見込み」と表示します。
- **日付:** Cost Explorer の日付は UTC です。「今日」は UTC の今日です。
- **取得の日時:** 画面に、データを取得した日時を表示します。Cost Explorer のデータは、およそ 1 日に 1 回更新されるので、1 日前のデータはふつうです。
- **エラー:** 最後の取得が失敗したときは、最後に成功したデータの上に、そのエラーを表示します。Cost Explorer につながらなかったとき(ネットワークの経路がない、DNS、タイムアウト)は、インターネットにつながらないネットワークには経路が必要なことも表示します([setup.md](setup.md#network))。

<a id="fetching-the-costs"></a>

## 費用の取得

画面は Cost Explorer を呼びません。AWS は Cost Explorer の API の要求ごとに課金し(1 要求 0.01 USD。AWS Cost Explorer の料金のページ。2026-11-10 に確認)、Cost Explorer のデータの更新はおよそ 1 日に 1 回なので、プラグインはスケジュールで費用を取得して保存します。

| 方法 | タイミング | 動く場所 |
| --- | --- | --- |
| rake のタスク `redmine_serverless_cost:refresh` | 毎日、スケジュールから([setup.md](setup.md#schedule)) | タスクを実行するプロセス。その場で取得し、失敗すると、タスクも失敗する(0 以外の終了コード) |
| 「更新」のボタン | 管理者が依頼したとき。1 時間に 1 回まで。取得の依頼があると、定期のものでも、1 時間はボタンを使えない | ジョブ `ServerlessCostRefreshJob`。Redmine がジョブを実行する場所で動く([Redmine Serverless SQS](https://redmine-kit.github.io/redmine_serverless_sqs/ja/) があれば、ジョブのキューから。プラグインは、このジョブを実行してよいクラスに足す) |

- **1 回の取得の要求の数:** 3 件(`GetCostAndUsage` が 2 件、`GetCostForecast` が 1 件)、タグありで 4 件です。`GetCostAndUsage` の長い応答は複数のページに分かれ、次のページごとに 1 件増えます。画面のボタンの横に、件数を表示します。
- **スケジュールの要求の数:** 1 日 3 件か 4 件、1 か月でおよそ 90 件から 120 件です。
- **失敗した取得は再試行しない:** 失敗した取得は、エラーといっしょに記録し、ジョブは再試行しません。エラーで要求が増えないようにするためです。次の定期の実行で、また取得します。
- **スナップショット:** 取得ごとに、`serverless_cost_snapshots` に 1 行を作ります。依頼した日時と依頼した人(`schedule` か管理者のログイン)、取得した日時、データ(JSON)、エラー、要求の数です。rake のタスクは、取得が成功するたびに、90 日より古い行を消します。最後に成功した行は残します。

<a id="costs-by-tag-optional"></a>

## タグごとの費用(オプション)

複数の Redmine を置く AWS アカウントでは、コスト配分タグで費用を分けられます。既定は無効です。`REDMINE_COST_TAG_KEY` がなければ、タグごとの要求を送らず、画面にもタグの欄を出しません。

- **有効にする:** `REDMINE_COST_TAG_KEY` に、タグのキーを設定します。ふつうは `redmine:instance` です([Serverless](https://redmine-kit.github.io/serverless/ja/) が、Redmine ごとのリソースに付けるタグです)。Serverless では、デプロイの設定ファイルで設定します。
- **タグを有効にする:** Billing and Cost Management のコンソール(コスト配分タグ)で、タグのキーをコスト配分タグとして有効にします。有効になるまで、最大で 24 時間かかります。タグの付いた費用がまだないあいだは、画面にそう表示し、有効にする方法を示します。
- **要求が 1 件増える:** 1 回の取得が 3 件から 4 件になります。
- **タグのない費用:** タグのない費用(たとえば、共有のリソースや、有効にする前の費用)は「(タグなし)」として表示します。

<a id="notes"></a>

## 補足

- **AWS Organizations:** メンバーアカウントでは、管理アカウントが、メンバーアカウントに Cost Explorer を許すかを決めます(コスト管理の設定 ›「Linked account access」。AWS Cost Management ユーザーガイドの「Controlling access to Cost Explorer」。2026-11-10 に確認)。許していなければ、要求はアクセスのエラーで失敗します。メンバーアカウントで見えるのは、そのアカウントの費用だけです。
- **Cost Explorer を有効にする:** Cost Explorer は、コンソールで一度開くと、そのアカウントで有効になります。そのあと AWS がデータを準備し、最大で 24 時間かかります(AWS Cost Management ユーザーガイドの「Enabling Cost Explorer」。2026-11-10 に確認)。
- **接続の確認はない:** Redmine Serverless の「状態と接続」には、確認を足しません。確認のたびに、課金される要求になるためです。最後の取得の結果は、「費用」のタブに表示します。
- **コードの構成:** `lib/redmine_serverless_cost/fetcher.rb` が要求を送り、`app/models/serverless_cost_snapshot.rb` が取得を保存し、`app/jobs/serverless_cost_refresh_job.rb` と `lib/tasks/redmine_serverless_cost.rake` が取得を実行し、`app/controllers/serverless_costs_controller.rb` がタブを表示します。`init.rb` がタブを登録します。
- **マイグレーション:** スナップショットの表(`serverless_cost_snapshots`)を作ります。`redmine:plugins:migrate` を実行します。
