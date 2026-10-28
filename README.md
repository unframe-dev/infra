# Unframe Cloudflare Infrastructure

Cloudflare の既存 Zone に対する DNS、Workers Route、Workers Custom Domain をTerraform で宣言的に管理します。  

## 管理対象

| Terraform resource | 対象 | 用途 |
| --- | --- | --- |
| `cloudflare_dns_record.apex_worker` | `un-fra.me` の `AAAA @ = 100::` | Route 方式の LP / Editor の入口 |
| `cloudflare_dns_record.realtime[0]` | `realtime.un-fra.me` の A レコード（IPv4 設定時のみ） | 自宅 Caddy の Realtime 入口、DNS only |
| `cloudflare_dns_record.realtime_ipv6[0]` | `realtime.un-fra.me` の AAAA レコード（IPv6 設定時のみ） | 同じ自宅 Caddy への IPv6 経路、DNS only |
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

## Realtime の自宅 origin

`terraform.tfvars` の `realtime_origin_ipv4` と `realtime_origin_ipv6` に、自宅 Caddy へ到達する公開アドレスを設定します。既定値はそれぞれ `null` で、設定した family のレコードだけを作成します。IPv4 のみ・IPv6 のみ・両方の構成に対応します。両方を指定すると同じ `realtime.<zone_name>` に A / AAAA を `proxied = false`（DNS only）で公開し、TLS は Caddy で終端します。

Quest と Audience は IP アドレスを固定せず、bootstrap の HTTPS hostname へ接続します。A / AAAA から接続可能な経路を選ぶ処理は、ブラウザや Quest の HTTP / gRPC 通信スタックに任せます（[Happy Eyeballs](https://www.rfc-editor.org/rfc/rfc8305.html)）。DNS 自体が到達性を判定するわけではありません。端末での切り替え動作は別途確認が必要です。

apply 前に、登録する各アドレスへの TCP 443 の到達性と公開証明書の取得・更新方法を準備します。IPv6 はルーターの WAN アドレスではなく Caddy ホストのグローバル IPv6 を指定し、ルーターとホストの IPv6 firewall を通します。Caddy の公開 listener は IPv4 / IPv6 を受けられる状態にします。Caddy から Runtime への内部転送は `127.0.0.1:9090` のまま使えます。

DNS 反映後に Caddy の証明書発行と端末からの gRPC / WebSocket 接続を確認します。両レコードを公開する場合は IPv4 のみ・IPv6 のみ・片方が不通の環境で、同じ hostname に接続できることを Quest と Audience それぞれで確認してください。これらの実機検証は未実施です。

公開アドレスが変わった場合は対応する変数を更新して plan / apply します。自動 DDNS 更新は行いません。適用済みの値を `null` に戻すと、その family の管理中レコードは削除対象になります。

既に同名の A / AAAA レコードが存在する場合は、対応する変数を設定したうえで、apply 前に存在するレコードを取り込みます。

```bash
terraform import 'cloudflare_dns_record.realtime[0]' '<zone-id>/<dns-record-id>'
terraform import 'cloudflare_dns_record.realtime_ipv6[0]' '<zone-id>/<ipv6-dns-record-id>'
terraform plan
```

## Realtime DNS のローカル検証

Terraform 1.7 以降の provider mock を使い、Cloudflare API や実リソースへアクセスせずに Realtime の plan を検証します。IPv4 / IPv6 の片方・両方・未指定、不正なアドレスの拒否を確認します。端末の経路選択やネットワークの疎通はこのテストの対象外です。

```bash
terraform init -backend=false -input=false
terraform test -filter=tests/realtime.tftest.hcl
```

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
