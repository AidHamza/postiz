# Deployment and validation record

## 2026-11-15 — first production deployment (Frankfurt)

Target: existing Frankfurt dedicated server (Ubuntu 24.04.4, x86_64, 40 CPU,
125 GiB RAM, 3.5 TB disk, Docker 29.7.2, Compose 5.5.0), alongside OpenPanel,
MedLink preprod, PCGaming, RPCNode, The Innovation Guy and others.
SSH as root with the existing key; host key verified from `known_hosts`
(host key checking stays on).

### Preflight findings

- Ports 80/443 owned by the shared `server-edge` Caddy (`/opt/server-edge`,
  Let's Encrypt, `public-edge` network). UFW: 22/80/443 only.
- No alias collisions on `public-edge` for the Postiz service names.
- Cloudflare zone `appsdoc.com`: plan Free, SSL Full (strict), Always Use HTTPS on.
  No Access app, WAF custom rule or cache rule for `social.appsdoc.com`; only a
  dynamic-redirect ruleset with no matching rules.
- DNS: the API token has no DNS read permission (`10000 Authentication error`),
  so the record was verified through behaviour: before deployment the hostname
  returned Cloudflare 525 (origin reachable, no certificate); after adding the
  Caddy site it serves Postiz with a valid certificate. The record was not changed.
- No other Terraform state manages `social`; OpenPanel's state was not touched.
- SMTP relay settings found in OpenPanel's server-side env (values not read out).

### What changed

Host:
- `/opt/appsdoc/postiz/{releases,shared,backups,current}`; Compose project
  `appsdoc_postiz` (6 containers, named volumes `appsdoc_postiz_*`).
- `/opt/server-edge/sites/appsdoc-postiz.caddy` (validated with the edge's
  `make validate`, then `caddy reload`). Edge container not restarted.
- `appsdoc-postiz-backup.{service,timer}` (daily 03:30 UTC).
- No firewall change, no host port added, no reboot, no prune.

Cloudflare (Terraform, state `postiz/terraform.tfstate`):
- Access policy `AppsDoc Postiz team` (Google Workspace group team@appsdoc.com).
- Access SaaS OIDC application `Social Media` (launcher-visible → hub.appsdoc.com),
  redirect `https://social.appsdoc.com/settings`.
- DNS record: unchanged and **not yet in Terraform** (pending DNS-read token).

### Deployed

- Repository commits deployed via `make deploy` (Ansible, exact `git archive`).
- `ghcr.io/gitroomhq/postiz-app:v2.26.0@sha256:875e61ac5d0ac43c3dec78a78a7032dfb03d9a8c6d4936ebb18adb606cc207c5`
  (other pins in docs/UPSTREAM.md).

### Checks run

| Check | Result |
| --- | --- |
| `make check`: compose renders, tag+digest pins, no non-loopback ports, no container_name/docker.sock, internal data networks, shellcheck, terraform fmt/validate, ansible syntax | PASS |
| Terraform plan reviewed: first apply 0 resources; second 2 to add, 0 change, 0 destroy | PASS |
| All 6 containers healthy; DB init; Temporal namespace ready; orchestrator health | PASS |
| Temporal task queue `main`: workflow + activity pollers from the Postiz worker | PASS |
| Public: login 200, HTTP→HTTPS 301, `/`→`/auth`, static assets, valid edge cert | PASS |
| Registration closed (`can-register` false); outsider signup refused (400) | PASS |
| Private APIs unauthenticated → 401 | PASS |
| Owner email/password login, Secure HttpOnly cookie, session → owner + AppsDoc org | PASS |
| Media upload (1×1 PNG) and public retrieval via `/uploads` | PASS |
| OIDC link → Cloudflare Access authorize endpoint (302) with `/settings` callback | PASS |
| Live Google Workspace OIDC login by the owner (Workspace identity, via Access) | PASS (performed by Hamza, 19:41 UTC) |
| Scoped `restart postiz`: session cookie still valid, media count unchanged | PASS |
| Repeat deployments (×2): secrets/ENCRYPTION_KEY hash unchanged, DB container not recreated, owner bootstrap skipped, edge file unchanged | PASS |
| Backup (pg_dump, pg_dumpall, uploads, config, secrets, checksums; 0700/0600) | PASS |
| Isolated restore test (`--network none` containers): users/orgs/media, Temporal namespaces/executions, uploads, 32-byte key | PASS |
| Upload size through Cloudflare: 95 MB reaches the app (401 unauth); 105 MB → 413 | PASS (limit ≈100 MB) |
| Other sites before/after (17 hostnames incl. analytics/events.appsdoc.com): identical status codes | PASS |

### Not tested / pending

- No social channel connected; no provider credentials exist (docs/PROVIDERS.md).
  No post drafted/published; no scheduled-publish end-to-end test.
- Email delivery through the imported SMTP relay was not exercised (no
  invitations sent during deployment).
- Backups are local only (no off-host destination).
- DNS record adoption into Terraform (needs Zone DNS Read/Edit).
- Elasticsearch visibility and Redis are not in backups (see OPERATIONS.md).
- The first Ansible run stalled locally after the server-side deploy had
  finished (no remote process left); it was stopped and the deployment re-run
  successfully twice. Not reproduced since.

## 2026-11-15 — Google Workspace login only

- Requested by Hamza: keep only Google login.
- Backup taken, then the bootstrap email/password owner was deleted via
  `POST /api/user/delete-account` (supported soft delete); its login then failed.
  `owner-login` removed from the server (copies remain only in backups).
- Caddy site blocks password endpoints with 403; `scripts/bootstrap-owner.sh`
  no longer stores a password.
- Smoke: password login/reset → 403, OIDC link → Access, LOCAL registration
  closed, 1 active OIDC user, 0 active password users, worker pollers present.
