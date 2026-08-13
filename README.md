# Unframe Cloudflare Infrastructure

Cloudflare の既存 Zone に対する DNS、Workers Route、Workers Custom Domain を
Terraform で宣言的に管理します。

## 管理対象

| Terraform resource | 対象 | 用途 |
| --- | --- | --- |
| `cloudflare_dns_record.apex_worker` | `un-fra.me` の `AAAA @ = 100::` | Route 方式の LP / Editor の入口 |
| `cloudflare_workers_route.lp` | `un-fra.me/*` | LP Worker |
| `cloudflare_workers_route.editor_root` | `un-fra.me/editor` | Editor の裸パス |
| `cloudflare_workers_route.editor_subpath` | `un-fra.me/editor/*` | Editor の配下パス |
| `cloudflare_workers_custom_domain.control_plane` | `api.un-fra.me` | Control Plane Worker の全パス |

> `un-fra.me` の LP と Editor は同じホストをパスで分割するため Route を使います。
> 一方、`api.un-fra.me` は hostname 全体を Control Plane に渡すため Custom Domain を使います。Custom Domain の DNS / TLS レコードは Cloudflare が作成するため、`api` のDNS レコードは別途宣言しません。

ドメインの購入、レジストラ、ネームサーバー変更そのものはこの構成の対象外です。

## Nix で起動

```bash
nix develop
cp terraform.tfvars.example terraform.tfvars
```

```bash
export CLOUDFLARE_API_TOKEN='...'
terraform init
terraform fmt -check
terraform validate
```

```bash
nix run .#fmt
nix run .#validate
nix flake check
```

Required API Token Permissions

- Zone: Read
- DNS: Read / Edit
- Workers Routes: Read / Edit
- Workers Scripts: Read / Edit（Custom Domain の確認・管理用）

## 既存リソースの取り込み

この構成は、Dashboard または Wrangler で作成済みの5リソースを引き継ぐことを前提とします。
いずれかを import せずに apply すると、重複作成や既存ルートとの競合が起きる可能性があります。
Cloudflare Dashboard で各 ID と Worker 名を確認し、最初の apply より前に5件すべてを
state へ import してください。

```bash
terraform import cloudflare_dns_record.apex_worker '<zone-id>/<dns-record-id>'
terraform import cloudflare_workers_route.lp '<zone-id>/<route-id>'
terraform import cloudflare_workers_route.editor_root '<zone-id>/<route-id>'
terraform import cloudflare_workers_route.editor_subpath '<zone-id>/<route-id>'
terraform import cloudflare_workers_custom_domain.control_plane '<account-id>/<domain-id>'
```

取り込み後は state に5件が揃っていることを確認します。

```bash
terraform state list
terraform plan
```

`terraform state list` に上記5アドレスがすべて存在し、plan に意図しない create、replace、
destroy がないことを確認してください。`pattern`、Worker 名、`proxied`、TTL、Custom Domain の
hostname に差分がある場合は、remote の実値と構成のどちらが正しいかを確認するまで apply
しないでください。既存リソースが見つからず import できない場合も同様に作業を止め、
新規作成してよいことを確認してから進めます。

確認済みの差分だけを反映する場合に限り、次を実行します。

```bash
terraform apply
```

## State の運用制約

現在は remote backend を構成していないため、Terraform はこのディレクトリの local state を
使用します。state は Git 管理せず、安全な場所にバックアップし、同時に複数の端末や担当者から
操作しないでください。state を失うと既存リソースとの対応関係も失われるため、削除や再生成では
なく復元を優先します。複数人や CI から運用する段階では、locking を備えた remote backend への
移行を別途設計してください。

## 既存の Wrangler 設定との境界

- Terraform: Zone lookup、DNS、Routes、Custom Domain
- Wrangler: Worker の build / deploy、D1 migration、local dev、secret 管理

> 同じ Route や Custom Domain を Wrangler と Terraform の両方で管理しないでください。
