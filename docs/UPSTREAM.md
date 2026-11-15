# Upstream provenance

| Item | Pinned |
| --- | --- |
| Postiz release | v2.26.0 (2026-11-13), `gitroomhq/postiz-app@132859f32d854830ce44b509da87409c3ec10a77` |
| Canonical Compose | `gitroomhq/postiz-docker-compose@dd4969e5e694cd009619a0d53cff14c21104580b` (docker-compose.yaml, dynamicconfig/development-sql.yaml) |
| Reviewed | 2026-11-15; v2.26.0 was the newest release (no newer stable release to evaluate) |

Image digests (multi-arch index digests, resolved from the registries on
2026-11-15; host is linux/amd64):

| Image | Index digest | linux/amd64 manifest |
| --- | --- | --- |
| ghcr.io/gitroomhq/postiz-app:v2.26.0 | sha256:875e61ac5d0ac43c3dec78a78a7032dfb03d9a8c6d4936ebb18adb606cc207c5 | sha256:2ddef321724f303f679f8610e4b09dd0fd77fbd5f4e5a77f012a36f9f8d43395 |
| postgres:17-alpine | sha256:a77aa70e641402a21411b92b721c58d10f23b50ae5fdd2333efd22d166e1e5f7 | sha256:005c5c37db96c1e6652a79ea31f9886402fba81ac95dc2db897739121dd7f8f2 |
| redis:7.2 | sha256:5b816bb37d9707a70f10ef5002ecf8ee431750d397010fc4314c93dca887962f | sha256:b690ae83413c6051e087c9fb92a420b002e820a9fe434ef6e266d612e3915306 |
| elasticsearch:7.17.27 | sha256:9a6443f55243f6acbfeb4a112d15eb3b9aac74bf25e0e39fa19b3ddd3a6879d0 | sha256:07e9262b856006959e384de7ca9587bc5c6da024ca7042216a9ea26efe4c69c1 |
| postgres:16 | sha256:dd2bf3ce2dc83a81674cf7f217fcfd8a5009a4b325dda5b843bfee82a06cff6f | sha256:2d5c77ae9b0e0944ffb92f8d8fc2fa2edb215cb0976da8bac34df917af417e87 |
| temporalio/auto-setup:1.28.1 | sha256:607d68caa111338d754771efb876c92dfcdae06d056e4530bb31cd0f37406e6a | sha256:e4c296d2b16d7607938e71182b9cc0936c90002ff63d97227f195625cf798ea3 |
| temporalio/admin-tools:1.28.1-tctl-1.18.4-cli-1.4.1 | sha256:01537b62d995f27a0f0d33a01ac4caa6779622f454fb2eb36fed0dccd45c6244 | sha256:00864ac86e79aec0d418582892d3435564c613b68b72fe2e41e9c50176794983 |
| temporalio/ui:2.34.0 | sha256:cb17ea423d76a8a19a269d0bcd81fc12eee1f6365acd2a56b590dafb35696a95 | sha256:ad58bbefd5919444041ed90ff0498393ee1d95dd9c3d85eb097080d73f6259c6 |

Resolve again with `docker buildx imagetools inspect <image:tag>` when updating.

## Differences from the canonical compose file

- Kept: Postiz, Postiz PostgreSQL 17, Redis 7.2, Temporal auto-setup 1.28.1,
  Temporal PostgreSQL 16, Elasticsearch 7.17 visibility, Temporal admin tools and
  UI (now opt-in profiles), the upstream dynamic config file unchanged.
- Project name `appsdoc_postiz`; all `container_name`s and the global
  `temporal-network` name removed; networks `postiz-data`/`temporal` are internal.
- No host ports: upstream `4007:5000`, `127.0.0.1:7233` and `127.0.0.1:8080` removed.
  Traffic enters via the shared Caddy (`public-edge`, alias `appsdoc-postiz`).
  Temporal UI (debug profile) binds `127.0.0.1:18080` only.
- Default passwords replaced by generated secrets; Redis requires a password.
- Postiz env moved to a private `app.env`; deployment-fixed URLs/flags are set
  in compose. `DISABLE_REGISTRATION=true` (upstream `false`). Token encryption on:
  `ENCRYPTION_PROVIDER=local` + `ENCRYPTION_KEY` (v2.26.0 `local.provider.ts`).
- Unused upstream placeholders (empty social keys, Stripe, Sentry/Spotlight) dropped;
  empty optional keys are not required for startup.
- `restart: unless-stopped`, bounded json-file logs, memory/CPU limits, ES heap 512 MB.

## Verified runtime facts (v2.26.0 source)

- `RUN_CRON` is not read anywhere in v2.26.0; kept only for canonical parity.
  Scheduling runs as Temporal workflows in the `orchestrator` process (pm2 starts
  backend, frontend and orchestrator in the one image; orchestrator health at
  `localhost:3002/health/status` checks the Temporal namespace).
- The container runs `prisma db push` on every start (schema sync, no separate
  migration step). Back up before every image change.
- `DISABLE_REGISTRATION=true`: `AuthService.canRegister` allows LOCAL/OAuth
  registration only while the organisation count is 0; GENERIC OIDC can always
  register (not configured here).
- Local accounts are auto-activated when no email provider is set; with one, an
  activation email is required.
- Cookies are `Secure; SameSite=None; HttpOnly` unless `NOT_SECURED` is set (not set).
