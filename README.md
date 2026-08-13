# Unframe Cloudflare Infrastructure

Cloudflare の既存 Zone に対する DNS、Workers Route、Workers Custom Domain をTerraform で宣言的に管理します。  

## 管理対象

| Terraform resource | 対象 | 用途 |
| --- | --- | --- |
| `cloudflare_dns_record.apex_worker` | `un-fra.me` の `AAAA @ = 100::` | Route 方式の LP / Editor の入口 |
| `cloudflare_workers_route.lp` | `un-fra.me/*` | LP Worker |
| `cloudflare_workers_route.editor_root` | `un-fra.me/editor` | Editor の裸パス |
| `cloudflare_workers_route.editor_subpath` | `un-fra.me/editor/*` | Editor の配下パス |
| `cloudflare_workers_custom_domain.control_plane` | `api.un-fra.me` | Control Plane Worker の全パス |
| `cloudflare_workers_custom_domain.mitou_slide` | `mitoujr.un-fra.me` | Mitou Slide Worker の全パス |

> `un-fra.me` の LP と Editor は同じホストをパスで分割するため Route を使います。  
> 一方、`api.un-fra.me` と `mitoujr.un-fra.me` は hostname 全体をそれぞれの Worker に渡すため Custom Domain を使います。Custom Domain の DNS / TLS レコードは Cloudflare が作成するため、これらのDNSレコードは別途宣言しません。  

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

この構成は、Dashboard または Wrangler で作成済みの5リソースを引き継ぎます。  
既存リソースを import せずに apply すると、重複作成や既存ルートとの競合が起きる可能性があります。  
Cloudflare Dashboard で各 ID と Worker 名を確認し、既存の5件を最初の apply より前にstate へ import してください。

```bash
terraform import cloudflare_dns_record.apex_worker '<zone-id>/<dns-record-id>'
terraform import cloudflare_workers_route.lp '<zone-id>/<route-id>'
terraform import cloudflare_workers_route.editor_root '<zone-id>/<route-id>'
terraform import cloudflare_workers_route.editor_subpath '<zone-id>/<route-id>'
terraform import cloudflare_workers_custom_domain.control_plane '<account-id>/<domain-id>'
terraform import cloudflare_workers_custom_domain.mitou_slide '<account-id>/<domain-id>'
```

既存5件の取り込み後は state に5件が揃っていることを確認します。新しいCustom Domainを
Terraformで作成する場合、planでは6件目のcreateとして表示されます。

```bash
terraform state list
terraform plan
```

確認済みの差分だけを反映する場合に限り、次を実行します。

```bash
terraform apply
```

## 既存の Wrangler 設定との境界

- Terraform: Zone lookup、DNS、Routes、Custom Domain
- Wrangler: Worker の build / deploy、D1 migration、local dev、secret 管理

> 同じ Route や Custom Domain を Wrangler と Terraform の両方で管理しないでください。
