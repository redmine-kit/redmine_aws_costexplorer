# IAM 権限

プロセスの役割ごとの、プラグインが自分で呼ぶ AWS の操作です。Lambda そのものの権限 (ログ、VPC の中での実行) は入れていません。ロールの全体は [Serverless の iam.md](https://redmine-kit.github.io/serverless/ja/iam.html) にあります。

<a id="permissions"></a>

## 権限

| アクション | リソース | 理由 |
| --- | --- | --- |
| `ce:GetCostAndUsage` | `*` | サービス別、日別、`REDMINE_COSTEXPLORER_TAG_KEY` があればタグ別のコスト |
| `ce:GetCostForecast` | `*` | 月末の予測 |
| `billing:GetBillingViewData` | 共有された請求ビューの ARN | Redmine Kit Charges の、共有された請求ビューのソースだけ ([下記](#a-shared-custom-billing-view-recommended)) |
| `sts:AssumeRole` | ロールの ARN | Redmine Kit Charges の、別のアカウントのロールのソースだけ ([下記](#a-role-in-another-account-assumerole)) |

この権限が要るのは、rake タスク `redmine_kit:aws:costexplorer:refresh` と `redmine_kit:charges:refresh` を実行するプロセスのロールだけです (Serverless では `redmine-task`)。Web リクエストと Redmine のジョブは Cost Explorer を呼びません。どちらの操作も読むだけです。コストはアカウント全体のもの (メンバーアカウントでは、そのアカウントのもの) で、タグは画面の表示を分けるだけです。

サービス認可リファレンスは、どちらの操作にも、リソースタイプ `billingview` (`arn:${Partition}:billing::${Account}:billingview/${ResourceId}`) と、条件キー `aws:ResourceTag/${TagKey}` を挙げています (Cost Explorer のサービスリファレンス `ce.json`。2026-11-10 に確認)。プラグインは請求ビュー (`BillingViewArn`) を指定しないので、Cost Explorer はアカウントのプライマリの請求ビューを使います。プライマリの請求ビューの ARN (`billing:ListBillingViews` で分かる) に絞ったポリシーでこれらのリクエストが通るかは、まだ確認していないので、例では `*` にしています。

<a id="example-policy"></a>

## ポリシーの例

rake タスクを実行するロールに付けます。

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

<a id="project-charges-redmine-kit-charges"></a>

### プロジェクトの料金 (Redmine Kit Charges)

[Redmine Kit Charges](README.md#project-charges-redmine-kit-charges) では、システム管理者が追加した AWS のソースを、同じ 2 つのアクションで、同じロール (`redmine_kit:charges:refresh` を実行するロール) が読みます。この Redmine サーバーのアカウントのソースには、追加の権限は要りません。ほかのアカウントを読むには、次のどちらかのポリシーをそのロールに追加し、デプロイで許す請求ビューやロールだけを書きます。**IAM のポリシーが、本当の許可リストです。** Redmine のシステム管理者は、ポリシーが許すものしか使えません。

<a id="a-shared-custom-billing-view-recommended"></a>

#### 共有されたカスタム請求ビュー (推奨)

組織の管理アカウントが、カスタム請求ビュー (アカウントまたはコスト配分タグで絞る) を作り、AWS RAM で Redmine サーバーのアカウントに共有します。Redmine サーバーのロールは、その ARN で読みます (すべてのリクエストに `BillingViewArn` を付ける)。認証情報も、ほかのアカウントのロールも要りません。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadSharedBillingViews",
      "Effect": "Allow",
      "Action": ["ce:GetCostAndUsage", "ce:GetCostForecast", "billing:GetBillingViewData"],
      "Resource": ["arn:aws:billing::111111111111:billingview/custom-1a2b3c4d"]
    }
  ]
}
```

- `111111111111` はビューを作ったアカウント (管理アカウント) で、ARN はそこで `billing:ListBillingViews` が返すものです。受け取る側のアカウントで ARN のアカウント ID がどうなるかは、まだ確認していません。
- `billing:GetBillingViewData` は、アクセス許可のみのアクションです (「get cost and usage data for a specified billing view」、AWS Billing のサービス認可リファレンス、2026-11-19)。請求ビューを付けた `GetCostAndUsage` に必要かはまだ確認していないので、どちらでも動くよう、ビューに絞って例に入れています。
- AWS RAM の権限が要るのは、共有する管理アカウントだけです。受け取る側には要りません (「Permissions are not required for member accounts who receive a shared custom billing view」、Sharing custom billing views)。組織の外では、受け取る側のアカウントの管理者が招待を承諾します。Redmine サーバーのロールには、その権限を付けません。

<a id="a-role-in-another-account-assumerole"></a>

#### 別のアカウントのロール (AssumeRole)

カスタム請求ビューを作れないスタンドアロンのアカウントや、ビューを共有できない組織では、そのアカウントに読み取り専用のロールを作り、ソースの外部 ID (「管理」›「料金」のソースの画面に表示) 付きで Redmine サーバーのロールを信頼させます。組織の管理アカウントのロールを引き受ける方法も動きますが、推奨しません。AWS は、管理アカウントを、管理アカウントが必要な作業にだけ使うよう勧めています。

Redmine サーバーのロール:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AssumeCostReaders",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": ["arn:aws:iam::222222222222:role/redmine-kit-cost-reader"]
    }
  ]
}
```

アカウント `222222222222` の `redmine-kit-cost-reader` の信頼ポリシー:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::333333333333:role/redmine-kit/<instance>-task" },
      "Action": "sts:AssumeRole",
      "Condition": { "StringEquals": { "sts:ExternalId": "<ソースの外部 ID>" } }
    }
  ]
}
```

アクセス許可ポリシー:

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

- 外部 ID は、ソースごとに Redmine が生成します (`redmine-kit-<UUID>`)。秘密ではありませんが、同じロールを登録した別の Redmine サーバー (たとえば共用のホスティングの別の顧客) が、この料金を読むこと (混乱した代理) を防ぎます。
- セッションは 15 分 (STS の最短) です。取得がそれより長くかかれば、SDK が更新します。

<a id="permissions-boundary"></a>

#### アクセス許可の境界

アクセス許可の境界があるロール (Serverless の task ロールには `redmine-kit-boundary` がある) は、ポリシーと境界の両方が許すものだけを使えます。境界は `ce:GetCostAndUsage` と `ce:GetCostForecast` に加えて、請求ビューには `billing:GetBillingViewData`、ロールには `sts:AssumeRole` を許す必要があります。境界では `*` でかまいません。リソースはロール自身のポリシーが絞ります。

```json
{
  "Sid": "Charges",
  "Effect": "Allow",
  "Action": ["ce:GetCostAndUsage", "ce:GetCostForecast", "billing:GetBillingViewData", "sts:AssumeRole"],
  "Resource": "*"
}
```

[Serverless](https://redmine-kit.github.io/serverless/ja/iam.html) は、`redmine.json` の `charges.aws.billingViewArns` と `charges.aws.roleArns` から、これらのポリシーを作ります。

<a id="resource-based-policies"></a>

## リソースベースのポリシー

プラグイン自身のものはありません。共有されたカスタム請求ビューには、共有するアカウントで AWS RAM の管理アクセス許可が作るリソースベースのポリシーがあり、引き受けるロールには信頼ポリシー (上記) があります。

<a id="not-checked-yet"></a>

## 未確認の事項

- 上のポリシーを、実際のロールで (テストはスタブと moto で、IAM を確認しない)
- `*` の代わりに、プライマリの請求ビューの ARN に絞ったポリシー
- AWS Organizations のメンバーアカウントで、管理アカウントが Cost Explorer を許していないときのエラー
- 実際の組織での、共有されたカスタム請求ビュー: 受け取る側のアカウントで、`BillingViewArn` 付きの `GetCostAndUsage` を `LINKED_ACCOUNT` と `TAG` でグループ化できるか、`DimensionValueAttributes` のアカウント名、そこでのビューの ARN のアカウント ID、`billing:GetBillingViewData` が要るか、請求ビューの AWS RAM のデフォルトの管理アクセス許可が許すアクション (`aws ram get-permission`)
- 実際のアカウントでの、外部 ID 付きの AssumeRole
