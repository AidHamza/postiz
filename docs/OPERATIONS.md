# Operations

Host layout (Frankfurt):

```
/opt/appsdoc/postiz/releases/<git-sha>   exact git archive of a commit
/opt/appsdoc/postiz/current              -> healthy release (switched after checks)
/opt/appsdoc/postiz/shared/  (0700)      infra.env, app.env, owner-login (0600)
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
| Smoke (public + authenticated) | `make smoke` |
| Backup now | `make backup` |
| Isolated restore test | `make restore-test` |
| Update | bump pins → `make check` → commit → `make deploy` |

On the host: `cd /opt/appsdoc/postiz/current && bash scripts/compose.sh ps`.

## Owner login

`ssh root@<host> cat /opt/appsdoc/postiz/shared/owner-login` shows the URL,
email and password of the bootstrap owner (`hamza@appsdoc.com`). Change the
password in Postiz settings after first login if you like; the file is not
updated automatically (the authenticated smoke test then needs the new value).

Registration is closed (`DISABLE_REGISTRATION=true` + one organisation). Add
colleagues with **Settings → Team → Invite** (email delivery via the SMTP relay
configured from OpenPanel's settings). Invitations were not sent during deployment.

## Backups

- Daily at 03:30 UTC (`appsdoc-postiz-backup.timer`), plus before each deploy of
  an existing installation. Online and consistent: `pg_dump -Fc` (Postiz DB),
  `pg_dumpall` (Temporal persistence), tar of uploads and `/config`, copies of
  `infra.env`/`app.env`/`owner-login`, `SHA256SUMS`. No service pause.
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
- No Access application, WAF rule or cache rule targets the hostname. Postiz
  native authentication protects the app. Optional staff-only Access would need
  route exceptions for `/uploads/*` (provider media pulls) and
  `/integrations/social/*` callbacks; not implemented.
- Terraform (`infra/terraform`, state `postiz/terraform.tfstate` in the R2 state
  bucket) currently manages **no resources**: the available API token cannot
  read DNS. Pending action: with a token that has Zone DNS Read/Edit, look up the
  record ID, set `social_record_id` and `origin_ipv4` in `terraform.tfvars`,
  `make tf-plan` (expect 1 import, 0 changes) and apply.

## Debug tooling (private)

```
bash scripts/compose.sh --profile debug up -d temporal-ui   # 127.0.0.1:18080 on the host
ssh -L 18080:127.0.0.1:18080 root@<host>
bash scripts/compose.sh --profile debug stop temporal-ui
bash scripts/compose.sh --profile admin run --rm temporal-admin-tools temporal workflow list --address temporal:7233
```
