# Working on AppsDoc Postiz infrastructure

- Keep it an infrastructure repo: Compose + scripts + Ansible + Terraform. No app
  source, no custom image build, no Kubernetes.
- Image references are tag+digest. Never use `latest`. Bump pins only after
  reading upstream release notes (docs/OPERATIONS.md "Update").
- Never print or commit runtime secrets: `/opt/appsdoc/postiz/shared/*.env`,
  `owner-login`, backups, Terraform state/plans, `backend.hcl`, `terraform.tfvars`,
  `inventory.ini`. Do not print `docker compose config` output or container
  environments. Validation uses `config -q`.
- `ENCRYPTION_KEY` must never change once channels exist (tokens become unreadable).
  `scripts/configure.sh` only appends missing keys.
- Keep `DISABLE_REGISTRATION=true`. Do not configure `POSTIZ_GENERIC_OAUTH`
  without re-reading `AuthService.canRegister` (GENERIC always may register).
- Only the `postiz` service joins `public-edge`; no service publishes a non-loopback
  host port. `scripts/check.sh` enforces this.
- The shared Caddy at `/opt/server-edge` serves other production sites. Only
  touch `sites/appsdoc-postiz.caddy`, always via `scripts/install-edge.sh`
  (validate before reload). Never stop/restart that edge.
- Other Compose projects on the host (OpenPanel, MedLink, PCGaming, RPCNode, ...)
  must not be touched. No global `docker prune`, no `down -v`, no reboot.
- Terraform uses state key `postiz/terraform.tfstate` only. Review every plan;
  stop on any delete/replace.
- Run `make check` before committing. Deploy only committed HEAD (`make deploy`).
- Never publish posts, send invitations or test messages as part of a deployment.
