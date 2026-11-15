# Operations

Host layout (Frankfurt):

```
/opt/appsdoc/postiz/releases/<git-sha>   exact git archive of a commit
/opt/appsdoc/postiz/current              -> healthy release (switched after checks)
/opt/appsdoc/postiz/shared/  (0700)      infra.env, app.env (0600)
/opt/appsdoc/postiz/backups/ (0700)      postiz-<UTC timestamp>/
/opt/server-edge/sites/appsdoc-postiz.caddy   Postiz route in the shared Caddy
```

Compose project `appsdoc_postiz` (constant): volumes `appsdoc_postiz_*` survive
release changes. Always use `scripts/compose.sh` on the host.

## Everyday commands (from a workstation checkout)

| Task | Command |
| --- | --- |
| Static checks | `make check` |
| Deploy committed HEAD | `make deploy` |
| Status / readiness / registration state | `make status` |
| Logs | `make logs` · `make logs SVC=temporal LINES=500` |
| Smoke (public + server-side) | `make smoke` |
| Backup now | `make backup` |
| Isolated restore test | `make restore-test` |
| Update | bump pins → `make check` → commit → `make deploy` |

On the host: `cd /opt/appsdoc/postiz/current && bash scripts/compose.sh ps`.

## Login

**Google Workspace only.** Use the "AppsDoc Google Workspace" button on
`https://social.appsdoc.com/auth/login` or the **Social Media** tile on
`hub.appsdoc.com`. Postiz generic OIDC → Cloudflare Access SaaS application
(Terraform `access.tf`) → existing Google Workspace IdP. Access policy: members
of `team@appsdoc.com` only.

Email/password is off. Postiz v2.26.0 has no setting for this, so the Caddy
site (`deploy/edge/appsdoc-postiz.caddy`) answers 403 on `/api/auth/login`,
`/forgot`, `/forgot-return`, `/activate`, `/resend-activation` and redirects the
forgot/activate pages. The login page still draws the email/password form;
submitting it returns the 403 message. LOCAL registration is refused by the
app. The bootstrap password owner was deleted on 2026-11-15 through Postiz's
own delete-account API (soft delete, identifying fields hashed).

How OIDC accounts relate to the organisation (v2.26.0 behaviour):

- Users are matched by OIDC subject + provider.
- GENERIC users may always register (`AuthService.canRegister`), so the Access
  policy is the only gate. A team member who logs in **without an invitation**
  gets a new, empty organisation of their own.
- To put people in the AppsDoc organisation: as owner, **Settings → Team →
  Invite** their Workspace address, and they open the invitation link and pick
  the Google Workspace button.
- Removing someone from `team@appsdoc.com` stops new OIDC logins; existing
  Postiz sessions last until they expire or you remove the user in Postiz.

Owner organisation: the one created by hamza@appsdoc.com's first Google
login (2026-11-15). The deleted password owner's organisation is soft-deleted.

OIDC settings live in `app.env` (`POSTIZ_GENERIC_OAUTH`, `POSTIZ_OAUTH_*`). To
rotate/refresh them after a Terraform change:

```bash
terraform -chdir=infra/terraform output -json postiz_oidc_env |
  ssh root@<host> 'bash /opt/appsdoc/postiz/current/scripts/set-env.sh /opt/appsdoc/postiz/shared/app.env'
make deploy
```

## Backups

- Daily at 03:30 UTC (`appsdoc-postiz-backup.timer`), plus before each deploy of
  an existing installation. Online and consistent: `pg_dump -Fc` (Postiz DB),
  `pg_dumpall` (Temporal persistence), tar of uploads and `/config`, copies of
  `infra.env`/`app.env`, `SHA256SUMS`. No service pause.
- Retention: newest 14 (`RETAIN`). Files are secrets (0700/0600).
- **Local only.** They do not protect against host loss. No existing encrypted
  off-host destination was found for this host. Next step: sync
  `/opt/appsdoc/postiz/backups` encrypted (e.g. restic/age) to a private R2
  bucket dedicated to backups (never the Terraform state bucket).
- Not included: Redis (cache/queue state; rebuilt) and the Elasticsearch
  visibility index. After a full restore Temporal history is present but
  workflow list/search may be incomplete until visibility is rebuilt; Postiz
  re-creates scheduling workflows for posts it manages, verify upcoming posts.

## Restore (schema-aware)

1. `make restore-test` first (isolated containers, `--network none`).
2. Stop only Postiz: `bash scripts/compose.sh stop postiz`.
3. Restore the Postiz DB into the running `postiz-postgres`:
   `bash scripts/compose.sh exec -T postiz-postgres pg_restore -U postiz -d postiz --clean --if-exists < backup/postiz.dump`
4. Temporal (only if its DB is lost): stop `temporal`, recreate DB from `temporal.sql`.
5. Uploads: `bash scripts/compose.sh run --rm --no-deps -T postiz tar -C /uploads -xzf - < backup/uploads.tgz`
6. Restore `app.env` with the **same** `ENCRYPTION_KEY` or stored channel tokens
   are unreadable.
7. The image runs `prisma db push` on start. Restore a dump only into the same
   or newer Postiz version than the one that wrote it. Never downgrade the
   image below the version the database was migrated to, and never below
   v2.26.0 once tokens are encrypted.

## Update

1. Read the release notes between the current and target versions (breaking
   env/schema changes, encryption changes).
2. Resolve digests: `docker buildx imagetools inspect ghcr.io/gitroomhq/postiz-app:vX.Y.Z`.
3. Update `compose.yaml` + `docs/UPSTREAM.md`; compare with the canonical
   postiz-docker-compose repo for new required services/env.
4. `make check`, commit, `make deploy` (takes a pre-deploy backup), `make smoke`.

## Uploads and size limits

- Storage: local volume `appsdoc_postiz_postiz-uploads`, served publicly at
  `https://social.appsdoc.com/uploads/...` by the image's nginx.
- Zone plan Free: Cloudflare limits proxied request bodies to 100 MB; Caddy is
  set to the same 100 MB. The app's nginx allows 2 GB, but uploads still pass
  through Cloudflare, so 100 MB is the effective limit. Larger videos need
  `STORAGE_PROVIDER=cloudflare` (R2, dedicated bucket) — not enabled; verify the
  release's upload flow before relying on it.

## Cloudflare

- `social.appsdoc.com`: proxied A record to the Frankfurt host, created manually,
  unchanged. Zone SSL mode Full (strict); origin certificate is Let's Encrypt via
  HTTP-01 through Cloudflare, issued by the shared Caddy.
- No WAF or cache rule targets the hostname, and no Access application gates
  `social.appsdoc.com` itself: Postiz native auth protects private routes, while
  `/uploads/*` (provider media pulls) and `/integrations/social/*` callbacks stay
  reachable. Access is used only as the OIDC provider + hub tile (SaaS app).
- Terraform (`infra/terraform`, state `postiz/terraform.tfstate` in the R2 state
  bucket) manages the Access policy `AppsDoc Postiz team` and the SaaS app
  `Social Media`. It does **not** manage the DNS record yet: the available API
  token cannot read DNS. Pending action: with a token that has Zone DNS Read/Edit, look up the
  record ID, set `social_record_id` and `origin_ipv4` in `terraform.tfvars`,
  `make tf-plan` (expect 1 import, 0 changes) and apply.

## Debug tooling (private)

```
bash scripts/compose.sh --profile debug up -d temporal-ui   # 127.0.0.1:18080 on the host
ssh -L 18080:127.0.0.1:18080 root@<host>
bash scripts/compose.sh --profile debug stop temporal-ui
bash scripts/compose.sh --profile admin run --rm temporal-admin-tools temporal workflow list --address temporal:7233
```
