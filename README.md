# AppsDoc Postiz infrastructure

Self-hosted [Postiz](https://github.com/gitroomhq/postiz-app) v2.26.0 for AppsDoc at
**https://social.appsdoc.com**, on the existing Frankfurt dedicated server.
This repository holds infrastructure only: Docker Compose, deployment scripts,
Ansible and Terraform. No application source.

```
Browser ── Cloudflare (orange-cloud A record, Full strict)
              │
        Frankfurt host :443 ── shared server-edge Caddy (/opt/server-edge, Let's Encrypt)
              │ public-edge network, alias appsdoc-postiz:5000
        ┌─────┴──────── appsdoc_postiz (Compose project) ─────────────────────┐
        │ postiz  (nginx → frontend :4200, backend :3000, orchestrator/worker) │
        │   ├─ postiz-data (internal): postiz-postgres 17, postiz-redis 7.2     │
        │   └─ temporal   (internal): temporal 1.28.1, temporal-postgresql 16,  │
        │                              temporal-elasticsearch 7.17 (visibility) │
        └────────────────────────────────────────────────────────────────────────┘
```

| Path | Purpose |
| --- | --- |
| `compose.yaml` | Production stack, images pinned by tag + digest, no host ports |
| `compose.local.yaml` | Local/testing override (127.0.0.1:4007) |
| `config/temporal/dynamicconfig/` | Upstream Temporal dynamic config (provenance in docs/UPSTREAM.md) |
| `deploy/edge/appsdoc-postiz.caddy` | Site block installed into the shared Caddy |
| `scripts/` | configure (one-time secrets), deploy, bootstrap-owner, install-edge, backup, restore-test, smoke, status |
| `infra/ansible/deploy.yml` | Ships an exact commit to `/opt/appsdoc/postiz/releases/<sha>` and runs `scripts/deploy.sh` |
| `infra/terraform/` | Postiz-owned Cloudflare resources (state key `postiz/terraform.tfstate`) |
| `docs/` | OPERATIONS, PROVIDERS, UPSTREAM, DEPLOYMENT (validation record) |

## Quick start (operator workstation)

```bash
cp infra/ansible/inventory.ini.example infra/ansible/inventory.ini   # set host
python3 -m venv .venv && .venv/bin/pip install ansible-core==2.19.3
make check      # static validation
make deploy     # deploy committed HEAD
make smoke      # public + authenticated checks
make status | make logs | make backup | make restore-test
```

First login: see `docs/OPERATIONS.md` → *Owner login*. Provider setup:
`docs/PROVIDERS.md`. Deployment and validation record: `docs/DEPLOYMENT.md`.

Runtime secrets exist only on the server in `/opt/appsdoc/postiz/shared`
(generated once, never rotated) and in its backups.
