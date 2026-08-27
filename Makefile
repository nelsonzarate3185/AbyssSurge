# AbyssSurge — comandos de desarrollo
# Requiere: supabase CLI, docker, deno (via supabase), unity (opcional)

SHELL := /bin/bash
# El CLI de Supabase busca `supabase/config.toml`. Esta carpeta se llama
# `Supabase/` (mayúscula), que resuelve igual en Windows y macOS.
# En Linux hace falta un symlink: ln -s Supabase supabase
SUPA  := supabase --workdir .
FN    := $(SUPA) functions

.DEFAULT_GOAL := help

## ─── Ayuda ─────────────────────────────────────────────────

.PHONY: help
help: ## Muestra esta ayuda
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

## ─── Base de datos ─────────────────────────────────────────

.PHONY: db-link
db-link: ## Vincula el repo al proyecto Supabase de AbyssSurge
	$(SUPA) link --project-ref ocmroiupftpbsukuqvyu

.PHONY: db-start
db-start: ## Levanta Supabase local (requiere Docker)
	$(SUPA) start

.PHONY: db-stop
db-stop: ## Detiene Supabase local
	$(SUPA) stop

.PHONY: db-reset
db-reset: ## Recrea la DB local aplicando migrations + seeds
	$(SUPA) db reset

.PHONY: db-diff
db-diff: ## Genera una migration desde cambios locales. Uso: make db-diff NAME=add_wrecks
	@test -n "$(NAME)" || (echo "Falta NAME. Ej: make db-diff NAME=add_wrecks"; exit 1)
	$(SUPA) db diff -f $(NAME)

.PHONY: db-push
db-push: ## Aplica migrations pendientes al proyecto remoto
	$(SUPA) db push

.PHONY: db-lint
db-lint: ## Linter de SQL sobre la DB local
	$(SUPA) db lint

## ─── Edge Functions ────────────────────────────────────────

.PHONY: fn-serve
fn-serve: ## Sirve las Edge Functions en local con hot reload
	$(FN) serve --env-file .env

.PHONY: fn-deploy
fn-deploy: ## Deploy de todas las funciones. Uso: make fn-deploy NAME=submit-run (opcional)
	if [ -n "$(NAME)" ]; then $(FN) deploy $(NAME); else $(FN) deploy; fi

.PHONY: fn-check
fn-check: ## Typecheck de las Edge Functions
	deno check Supabase/functions/*/index.ts

## ─── Calidad ───────────────────────────────────────────────

.PHONY: check
check: db-lint fn-check ## Corre todas las verificaciones

## ─── Unity ─────────────────────────────────────────────────

.PHONY: unity-open
unity-open: ## Recuerda cómo abrir el proyecto Unity
	@echo "Abrí Unity Hub → Add project → seleccioná la carpeta ./Unity"

## ─── Utilidades ────────────────────────────────────────────

.PHONY: env
env: ## Crea .env a partir de .env.example si no existe
	@test -f .env && echo ".env ya existe, no toco nada" || (cp .env.example .env && echo ".env creado — completá las claves")

.PHONY: tree
tree: ## Muestra la estructura del workspace
	@find . -type d \( -name .git -o -name node_modules -o -name Library \) -prune -o -type d -print | sort
