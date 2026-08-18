# Unframe Cloudflare Infrastructure

Cloudflare の既存 Zone に対する DNS、Workers Route、Workers Custom Domain をTerraform で宣言的に管理します。  

## 管理対象

| Terraform resource | 対象 | 用途 |
| --- | --- | --- |
| `cloudflare_dns_record.apex_worker` | `un-fra.me` の `AAAA @ = 100::` | Route 方式の LP / Editor の入口 |
| `cloudflare_dns_record.resend_dkim` | `resend._domainkey.un-fra.me` | Resend の DKIM 認証 |
| `cloudflare_dns_record.resend_mail_from_mx` | `send.un-fra.me` | Resend の MAIL FROM MX |
| `cloudflare_dns_record.resend_mail_from_spf` | `send.un-fra.me` | Resend の SPF 認証 |
| `cloudflare_dns_record.resend_dmarc` | `_dmarc.un-fra.me` | DMARC の監視ポリシー |
| `cloudflare_workers_route.lp_root` | `un-fra.me` | LP のトップページ |
| `cloudflare_workers_route.lp_news` | `un-fra.me/news` | LP の News トップ |
| `cloudflare_workers_route.lp_news_subpath` | `un-fra.me/news/*` | LP の News 記事 |
| `cloudflare_workers_route.lp_docs` | `un-fra.me/docs` | LP の Docs トップ |
| `cloudflare_workers_route.lp_docs_subpath` | `un-fra.me/docs/*` | LP の Docs 記事 |
| `cloudflare_workers_route.lp_app_assets` | `un-fra.me/_app/*` | SvelteKit の静的アセット |
| `cloudflare_workers_route.lp_brand_assets` | `un-fra.me/brand/*` | LP のブランドアセット |
| `cloudflare_workers_route.lp_favicon_assets` | `un-fra.me/favicon/*` | LP のfavicon |
| `cloudflare_workers_route.editor_fallback` | `un-fra.me/*` | 上記以外のEditor Worker |
| `cloudflare_workers_custom_domain.control_plane` | `api.un-fra.me` | Control Plane Worker の全パス |
| `cloudflare_workers_custom_domain.mitou_slide` | `mitoujr.un-fra.me` | Mitou Slide Worker の全パス |

> `un-fra.me` はLPの明示的なパスを先に確保し、それ以外をルート基準のEditor Workerへ渡します。Cloudflareはより具体的なrouteを優先するため、`un-fra.me/news/*`などがEditor fallbackに吸われることはありません。
> 一方、`api.un-fra.me` と `mitoujr.un-fra.me` は hostname 全体をそれぞれの Worker に渡すため Custom Domain を使います。Custom Domain の DNS / TLS レコードは Cloudflare が作成するため、これらのDNSレコードは別途宣言しません。  
> `lp_root` はapexの完全一致Routeです。クエリ付きのトップURLをLPで確実に受ける必要がある場合は、[CloudflareのRouteマッチング仕様](https://developers.cloudflare.com/workers/configuration/routing/routes/)を確認してからapplyしてください。

Resend は `un-fra.me` を送信ドメインとして検証し、`noreply@un-fra.me` から認証メールを送信します。DNS反映後、Resend Dashboardでドメイン検証を実行してください。

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

この構成は、Dashboard または Wrangler で作成済みの6リソース（DNS 1件、Route 3件、Custom Domain 2件）を引き継ぎます。
既存リソースを import せずに apply すると、重複作成や既存ルートとの競合が起きる可能性があります。  
既存stateがある場合は、`moved` blockが旧Routeアドレスを新しい役割へ移送します。新しいLPの静的パスRouteはplanでcreateとして表示されます。

```bash
terraform import cloudflare_dns_record.apex_worker '<zone-id>/<dns-record-id>'
# 現在のremoteが旧構成（LP broad / Editor /editor）なら、既存3 routeを新しい役割へ取り込む
terraform import cloudflare_workers_route.editor_fallback '<zone-id>/<old-lp-route-id>'
terraform import cloudflare_workers_route.lp_root '<zone-id>/<old-editor-root-route-id>'
terraform import cloudflare_workers_route.lp_news '<zone-id>/<old-editor-subpath-route-id>'
terraform import cloudflare_workers_custom_domain.control_plane '<account-id>/<domain-id>'
terraform import cloudflare_workers_custom_domain.mitou_slide '<account-id>/<domain-id>'
```

既存6件の取り込み後は state に6件が揃っていることを確認します。既存stateを使う場合は、Routeの移送と新規LP Routeのcreateが意図した差分になっていることを確認してください。

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
