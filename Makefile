# Makefile for Database Helm Charts
# Usage: make <target>

.PHONY: help install-cnpg-operator install-postgres uninstall-postgres install-oracle uninstall-oracle \
        install-all uninstall-all lint template-postgres template-oracle status-postgres status-oracle \
        logs-postgres logs-oracle port-forward-postgres port-forward-oracle clean \
        package package-postgres package-oracle repo-index repo-update \
        git-push git-commit

# Default target
help:
	@echo "Database Helm Charts - Makefile"
	@echo ""
	@echo "Prerequisites:"
	@echo "  make install-cnpg-operator  Install CNPG operator (required for PostgreSQL)"
	@echo ""
	@echo "Installation:"
	@echo "  make install-postgres       Install CNPG PostgreSQL cluster"
	@echo "  make install-oracle         Install Oracle XE database"
	@echo "  make install-all            Install both databases"
	@echo ""
	@echo "Uninstallation:"
	@echo "  make uninstall-postgres     Uninstall PostgreSQL cluster"
	@echo "  make uninstall-oracle       Uninstall Oracle XE database"
	@echo "  make uninstall-all          Uninstall both databases"
	@echo "  make clean                  Uninstall all and delete namespaces"
	@echo ""
	@echo "Development:"
	@echo "  make lint                   Lint all Helm charts"
	@echo "  make template-postgres      Render PostgreSQL templates"
	@echo "  make template-oracle        Render Oracle XE templates"
	@echo ""
	@echo "Helm Repository:"
	@echo "  make package                Package all Helm charts"
	@echo "  make repo-index             Generate Helm repo index"
	@echo "  make repo-update            Package charts and update index"
	@echo ""
	@echo "Operations:"
	@echo "  make status-postgres        Show PostgreSQL cluster status"
	@echo "  make status-oracle          Show Oracle XE status"
	@echo "  make logs-postgres          Show PostgreSQL logs"
	@echo "  make logs-oracle            Show Oracle XE logs"
	@echo "  make port-forward-postgres  Port forward PostgreSQL (5432)"
	@echo "  make port-forward-oracle    Port forward Oracle XE (1521)"

# Variables
POSTGRES_RELEASE ?= postgres
POSTGRES_NAMESPACE ?= postgres
POSTGRES_VALUES ?= 

ORACLE_RELEASE ?= oracle
ORACLE_NAMESPACE ?= oracle
ORACLE_VALUES ?= 

# CNPG Operator
CNPG_VERSION ?= 1.22.0
CNPG_MANIFEST := https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.22/releases/cnpg-$(CNPG_VERSION).yaml

#------------------------------------------------------------------------------
# Prerequisites
#------------------------------------------------------------------------------

install-cnpg-operator:
	@echo "Installing CNPG Operator v$(CNPG_VERSION)..."
	kubectl apply -f $(CNPG_MANIFEST)
	@echo "Waiting for CNPG operator to be ready..."
	kubectl wait --for=condition=available --timeout=120s deployment/cnpg-controller-manager -n cnpg-system
	@echo "CNPG Operator installed successfully!"

uninstall-cnpg-operator:
	@echo "Uninstalling CNPG Operator..."
	kubectl delete -f $(CNPG_MANIFEST) --ignore-not-found=true

#------------------------------------------------------------------------------
# PostgreSQL
#------------------------------------------------------------------------------

install-postgres: install-cnpg-operator
	@echo "Installing CNPG PostgreSQL cluster..."
	helm upgrade --install $(POSTGRES_RELEASE) ./cnpg-postgres \
		--namespace $(POSTGRES_NAMESPACE) \
		--create-namespace \
		$(if $(POSTGRES_VALUES),-f $(POSTGRES_VALUES),)
	@echo "PostgreSQL cluster installation initiated!"

uninstall-postgres:
	@echo "Uninstalling PostgreSQL cluster..."
	helm uninstall $(POSTGRES_RELEASE) --namespace $(POSTGRES_NAMESPACE) --ignore-not-found
	@echo "PostgreSQL cluster uninstalled!"

status-postgres:
	@echo "=== PostgreSQL Cluster Status ==="
	kubectl get clusters -n $(POSTGRES_NAMESPACE) 2>/dev/null || echo "No CNPG clusters found"
	@echo ""
	@echo "=== Pods ==="
	kubectl get pods -n $(POSTGRES_NAMESPACE) -l cnpg.io/cluster=$(POSTGRES_RELEASE)-cluster 2>/dev/null || kubectl get pods -n $(POSTGRES_NAMESPACE)
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -n $(POSTGRES_NAMESPACE)

logs-postgres:
	kubectl logs -f -l cnpg.io/cluster=$(POSTGRES_RELEASE)-cluster -n $(POSTGRES_NAMESPACE) --tail=100

port-forward-postgres:
	@echo "Port forwarding PostgreSQL on localhost:5432..."
	@echo "Connection: psql -h localhost -U appuser -d appdb"
	kubectl port-forward -n $(POSTGRES_NAMESPACE) svc/$(POSTGRES_RELEASE)-cluster-rw 5432:5432

template-postgres:
	helm template $(POSTGRES_RELEASE) ./cnpg-postgres $(if $(POSTGRES_VALUES),-f $(POSTGRES_VALUES),)

#------------------------------------------------------------------------------
# Oracle XE
#------------------------------------------------------------------------------

install-oracle:
	@echo "Installing Oracle XE database..."
	helm upgrade --install $(ORACLE_RELEASE) ./oracle-xe \
		--namespace $(ORACLE_NAMESPACE) \
		--create-namespace \
		$(if $(ORACLE_VALUES),-f $(ORACLE_VALUES),)
	@echo "Oracle XE installation initiated!"
	@echo "Note: Oracle XE can take 5-10 minutes to fully start."

uninstall-oracle:
	@echo "Uninstalling Oracle XE..."
	helm uninstall $(ORACLE_RELEASE) --namespace $(ORACLE_NAMESPACE) --ignore-not-found
	@echo "Oracle XE uninstalled!"

status-oracle:
	@echo "=== Oracle XE Status ==="
	kubectl get pods -n $(ORACLE_NAMESPACE) -l app.kubernetes.io/name=oracle-xe
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -n $(ORACLE_NAMESPACE)

logs-oracle:
	kubectl logs -f -l app.kubernetes.io/name=oracle-xe -n $(ORACLE_NAMESPACE) --tail=100

port-forward-oracle:
	@echo "Port forwarding Oracle XE on localhost:1521..."
	@echo "Connection: sqlplus sys/OraclePassword123@localhost:1521/XE as sysdba"
	kubectl port-forward -n $(ORACLE_NAMESPACE) svc/$(ORACLE_RELEASE)-oracle-xe 1521:1521

template-oracle:
	helm template $(ORACLE_RELEASE) ./oracle-xe $(if $(ORACLE_VALUES),-f $(ORACLE_VALUES),)

#------------------------------------------------------------------------------
# Combined Operations
#------------------------------------------------------------------------------

install-all: install-postgres install-oracle
	@echo "All databases installed!"

uninstall-all: uninstall-postgres uninstall-oracle
	@echo "All databases uninstalled!"

lint:
	@echo "Linting Helm charts..."
	helm lint ./cnpg-postgres
	helm lint ./oracle-xe
	@echo "All charts passed linting!"

clean: uninstall-all
	@echo "Deleting namespaces..."
	kubectl delete namespace $(POSTGRES_NAMESPACE) --ignore-not-found=true
	kubectl delete namespace $(ORACLE_NAMESPACE) --ignore-not-found=true
	@echo "Cleanup complete!"

#------------------------------------------------------------------------------
# Helm Repository
#------------------------------------------------------------------------------

# Directory for packaged charts
CHARTS_DIR ?= packages
REPO_URL ?= 

package-postgres: lint
	@echo "Packaging cnpg-postgres chart..."
	@mkdir -p $(CHARTS_DIR)
	helm package ./cnpg-postgres -d $(CHARTS_DIR)

package-oracle: lint
	@echo "Packaging oracle-xe chart..."
	@mkdir -p $(CHARTS_DIR)
	helm package ./oracle-xe -d $(CHARTS_DIR)

package: package-postgres package-oracle
	@echo "All charts packaged in $(CHARTS_DIR)/"

repo-index:
	@echo "Generating Helm repository index..."
	@mkdir -p $(CHARTS_DIR)
	helm repo index $(CHARTS_DIR) $(if $(REPO_URL),--url $(REPO_URL),)
	@echo "Index generated: $(CHARTS_DIR)/index.yaml"

repo-update: package repo-index
	@echo "Helm repository updated!"
	@echo "Charts available in $(CHARTS_DIR)/"
	@ls -la $(CHARTS_DIR)/

#------------------------------------------------------------------------------
# Custom Values Examples
#------------------------------------------------------------------------------

# Install with custom values file:
#   make install-postgres POSTGRES_VALUES=custom-postgres.yaml
#   make install-oracle ORACLE_VALUES=custom-oracle.yaml
#
# Install with custom release name and namespace:
#   make install-postgres POSTGRES_RELEASE=mydb POSTGRES_NAMESPACE=production
#   make install-oracle ORACLE_RELEASE=myoracle ORACLE_NAMESPACE=production

#------------------------------------------------------------------------------
# Git Operations
#------------------------------------------------------------------------------

COMMIT_MSG ?= Update Helm charts

git-commit:
	@echo "Committing changes..."
	git add -A
	git commit -m "$(COMMIT_MSG)" || echo "Nothing to commit"

git-push: git-commit
	@echo "Pushing to GitHub..."
	git push origin master
	@echo "Pushed to GitHub successfully!"
