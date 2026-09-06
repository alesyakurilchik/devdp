.RECIPEPREFIX := >

SHELL := /bin/bash

.PHONY: bootstrap check

bootstrap:
> ./scripts/bootstrap.sh

check:
> terraform -chdir=infra/terraform validate
> cd ansible && ansible-playbook playbooks/site.yml --syntax-check
> cd ansible && ansible-playbook playbooks/monitoring.yml --syntax-check
