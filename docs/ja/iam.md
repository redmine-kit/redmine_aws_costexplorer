# IAM の権限

プロセスの役割ごとの、プラグインが自分で呼ぶ AWS の操作です。Lambda そのものの権限(ログ、VPC の中での実行)は入れていません。ロールの全体は [Serverless の iam.md](https://redmine-kit.github.io/serverless/ja/iam.html) にあります。

<a id="permissions"></a>

## 権限

| 操作 | 対象 | 理由 |
| --- | --- | --- |
| `ce:GetCostAndUsage` | `*` | サービスごと、日ごと、`REDMINE_COSTEXPLORER_TAG_KEY` があればタグごとの費用 |
| `ce:GetCostForecast` | `*` | 今月の予測 |

- **どのロールか:** rake のタスク `redmine_serverless_costexplorer:refresh` を実行するプロセスのロール(Serverless では `redmine-task`)と、タブを開いたときと「更新」のボタンの取得のために、Redmine のジョブを実行するプロセスのロール(Serverless では `redmine-worker`)です。タブとボタンはジョブをキューに入れるだけなので、web の要求のロールには要りません。ただし、ジョブを web のプロセスの中で実行するときは別です。
- **対象:** サービス認可リファレンスは、どちらの操作にも、リソースの種類 `billingview`(`arn:${Partition}:billing::${Account}:billingview/${ResourceId}`)と、条件キー `aws:ResourceTag/${TagKey}` を挙げています(Cost Explorer のサービスリファレンス `ce.json`。2026-11-10 に確認)。プラグインは請求ビュー(`BillingViewArn`)を指定しないので、Cost Explorer はアカウントのプライマリの請求ビューを使います。プライマリの請求ビューの ARN(`billing:ListBillingViews` で分かる)に絞ったポリシーで、これらの要求が通るかは、まだ確認していません。例では `*` にしています。
- **読むだけ:** どちらの操作も読むだけです。費用はアカウント全体のもの(メンバーアカウントでは、そのアカウントのもの)で、タグは画面の表示を分けるだけです。

<a id="example-policy"></a>

## ポリシーの例

rake のタスクを実行するロールと、Redmine のジョブを実行するロールに付けます。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadCosts",
      "Effect": "Allow",
      "Action": ["ce:GetCostAndUsage", "ce:GetCostForecast"],
      "Resource": "*"
    }
  ]
}
```

<a id="resource-based-policies"></a>

## リソースベースのポリシー

ありません。

<a id="not-checked-yet"></a>

## まだ確認していないこと

- 上のポリシーを、実際のロールで(テストはスタブと moto で、IAM を確認しない)
- `*` の代わりに、プライマリの請求ビューの ARN に絞ったポリシー
- AWS Organizations のメンバーアカウントで、管理アカウントが Cost Explorer を許していないときのエラー
