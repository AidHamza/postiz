# Operator targets. Remote targets run over SSH against $(HOST), which must be
# in ~/.ssh/known_hosts (host key checking stays on). Defaults come from
# infra/ansible/inventory.ini (gitignored).
HOST ?= $(shell awk '/ansible_host=/{for(i=1;i<=NF;i++) if($$i ~ /^ansible_host=/){split($$i,a,"=");print a[2]}}' infra/ansible/inventory.ini 2>/dev/null | head -1)
USER_AT_HOST = root@$(HOST)
ROOT = /opt/appsdoc/postiz
REMOTE = ssh -o BatchMode=yes $(USER_AT_HOST)
ANSIBLE_PLAYBOOK ?= $(shell test -x .venv/bin/ansible-playbook && echo .venv/bin/ansible-playbook || echo ansible-playbook)
SHA = $(shell git rev-parse HEAD)

.PHONY: check deploy status logs smoke backup restore-test update tf-plan

check:            ## static validation (compose, pins, ports, shell, terraform, ansible)
	bash scripts/check.sh

deploy:           ## deploy the committed HEAD (clean tree required)
	@git diff --quiet && git diff --cached --quiet || { echo "commit first: only committed artifacts are deployed"; exit 1; }
	mkdir -p dist
	git archive --format=tar.gz --output=dist/release-$(SHA).tar.gz HEAD
	cd infra/ansible && POSTIZ_RELEASE_ID=$(SHA) POSTIZ_RELEASE_ARCHIVE=$(CURDIR)/dist/release-$(SHA).tar.gz \
	  ../../$(ANSIBLE_PLAYBOOK) deploy.yml

update: deploy    ## same as deploy after bumping pins in compose.yaml (see docs/OPERATIONS.md)

status:
	$(REMOTE) 'cd $(ROOT)/current && bash scripts/status.sh'

logs:             ## SVC=postiz (default) LINES=200
	$(REMOTE) 'cd $(ROOT)/current && bash scripts/compose.sh logs --no-color --tail $(or $(LINES),200) $(or $(SVC),postiz)'

smoke:            ## public + server-side checks
	bash scripts/smoke-public.sh
	$(REMOTE) 'cd $(ROOT)/current && bash scripts/smoke-auth.sh'

backup:
	$(REMOTE) 'cd $(ROOT)/current && bash scripts/backup.sh $(ROOT)/backups'

restore-test:
	$(REMOTE) 'cd $(ROOT)/current && bash scripts/restore-test.sh'

tf-plan:          ## needs CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, backend.hcl, terraform.tfvars
	. scripts/r2-backend-env.sh && terraform -chdir=infra/terraform init -input=false -backend-config=backend.hcl && \
	  terraform -chdir=infra/terraform plan -input=false
