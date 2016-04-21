
.PHONY: all help deps plan apply destroy show force_deploy

ENV ?= ${USER}

all: help

help:
	@echo "Usage:"
	@echo "  make plan"
	@echo "  make apply"
	@echo "  make show"
	@echo "  make force_deploy"
	@echo "  make destroy"

deps:
	@hash terraform > /dev/null 2>&1 || (echo "Install terraform to continue"; exit 1)
	@echo Environment: ${ENV}

plan: deps
	@cd tf; \
	terraform get; \
	TF_VAR_environ="${ENV}" terraform plan --state=${ENV}.tfstate

apply: deps
	@cd tf; \
	terraform get; \
	TF_VAR_environ="${ENV}" terraform apply --state=${ENV}.tfstate

destroy: deps
	@cd tf; \
	TF_VAR_environ="${ENV}" terraform destroy --state=${ENV}.tfstate

show: deps
	@cd tf; \
	TF_VAR_environ="${ENV}" terraform show ${ENV}.tfstate

# Force deploy of the code as it presently is
force_deploy: deps
	@cd tf; \
	terraform get; \
	terraform taint --state=${ENV}.tfstate null_resource.docker; \
	TF_VAR_environ="${ENV}" terraform apply --state=${ENV}.tfstate
