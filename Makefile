# Makefile for Database Helm Charts
# Usage: make <target>

# Load environment variables from .env file if it exists
-include .env
export

.PHONY: help install-cnpg-operator install-postgres install-postgres-connect uninstall-postgres install-oracle uninstall-oracle \
        install-all uninstall-all lint template-postgres template-oracle status-postgres status-oracle \
        logs-postgres logs-oracle port-forward-postgres port-forward-oracle clean \
        package package-postgres package-oracle repo-index repo-update \
        git-push git-commit git-set-remote \
        delete-postgres delete-oracle delete-cnpg-all delete-all

# Default target
help:
	@echo "Database Helm Charts - Makefile"
	@echo ""
	@echo "Installation:"
	@echo "  make install-postgres         Deploy PostgreSQL (operator + cluster)"
	@echo "  make install-postgres-connect Deploy PostgreSQL + auto port-forward"
	@echo "  make install-oracle         Install Oracle XE database"
	@echo "  make install-all            Install both databases"
	@echo ""
	@echo "Uninstallation:"
	@echo "  make uninstall-postgres     Uninstall PostgreSQL Helm release"
	@echo "  make uninstall-oracle       Uninstall Oracle XE Helm release"
	@echo "  make uninstall-all          Uninstall both Helm releases"
	@echo ""
	@echo "Deletion (Full Cleanup):"
	@echo "  make delete-postgres        Delete PostgreSQL + namespace + PVCs"
	@echo "  make delete-oracle          Delete Oracle XE + namespace + PVCs"
	@echo "  make delete-cnpg-all        Delete PostgreSQL + CNPG operator + CRDs"
	@echo "  make delete-all             Delete everything (both DBs + namespaces)"
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
	@echo "Git Operations:"
	@echo "  make git-push               Commit and push to GitHub"
	@echo "  make git-set-remote         Set git remote from .env"
	@echo ""
	@echo "Operations:"
	@echo "  make status-postgres        Show PostgreSQL cluster status"
	@echo "  make status-oracle          Show Oracle XE status"
	@echo "  make logs-postgres          Show PostgreSQL logs"
	@echo "  make logs-oracle            Show Oracle XE logs"
	@echo "  make port-forward-postgres  Port forward PostgreSQL (5432)"
	@echo "  make port-forward-oracle    Port forward Oracle XE (1521)"

# Variables (defaults can be overridden in .env file)
POSTGRES_RELEASE ?= postgres
POSTGRES_NAMESPACE ?= postgres
POSTGRES_VALUES ?= 

ORACLE_RELEASE ?= oracle
ORACLE_NAMESPACE ?= oracle
ORACLE_VALUES ?= 

# CNPG Operator
CNPG_VERSION ?= 0.22.1
CNPG_NAMESPACE ?= cnpg-system

# Git
GIT_REPO ?= https://github.com/vivekch0976/helm.git
GIT_BRANCH ?= master
COMMIT_MSG ?= Update Helm charts

# Helm Repository
CHARTS_DIR ?= packages
REPO_URL ?= 

#------------------------------------------------------------------------------
# Prerequisites
#------------------------------------------------------------------------------

install-cnpg-operator:
	@echo "Installing CNPG Operator v$(CNPG_VERSION) via Helm..."
	helm repo add cnpg https://cloudnative-pg.github.io/charts 2>/dev/null || true
	helm repo update cnpg
	kubectl create namespace $(CNPG_NAMESPACE) 2>/dev/null || true
	helm upgrade --install cnpg cnpg/cloudnative-pg \
		--namespace $(CNPG_NAMESPACE) \
		--version $(CNPG_VERSION) \
		--set resources.limits.memory=1Gi \
		--set resources.limits.cpu=1 \
		--wait --timeout 5m
	@echo "CNPG Operator installed successfully!"

uninstall-cnpg-operator:
	@echo "Uninstalling CNPG Operator..."
	helm uninstall cnpg -n $(CNPG_NAMESPACE) --ignore-not-found 2>/dev/null || true

#------------------------------------------------------------------------------
# PostgreSQL
#------------------------------------------------------------------------------

install-postgres: install-cnpg-operator
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║           🐘 CNPG PostgreSQL Installation                        ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Step 1/5: Creating namespace..."
	@kubectl create namespace $(POSTGRES_NAMESPACE) 2>/dev/null && echo "   ✓ Namespace '$(POSTGRES_NAMESPACE)' created" || echo "   ✓ Namespace '$(POSTGRES_NAMESPACE)' already exists"
	@echo ""
	@echo "📦 Step 2/5: Deploying Helm chart..."
	@helm upgrade --install $(POSTGRES_RELEASE) ./cnpg-postgres \
		--namespace $(POSTGRES_NAMESPACE) \
		$(if $(POSTGRES_VALUES),-f $(POSTGRES_VALUES),) 2>&1 | head -20
	@echo "   ✓ Helm chart deployed"
	@echo ""
	@echo "⏳ Step 3/5: Waiting for PostgreSQL cluster to initialize..."
	@echo "   (This may take 2-5 minutes for first installation)"
	@echo ""
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12; do \
		PHASE=$$(kubectl get cluster/$(POSTGRES_RELEASE)-cnpg-postgres -n $(POSTGRES_NAMESPACE) -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending"); \
		READY=$$(kubectl get cluster/$(POSTGRES_RELEASE)-cnpg-postgres -n $(POSTGRES_NAMESPACE) -o jsonpath='{.status.readyInstances}' 2>/dev/null || echo "0"); \
		TOTAL=$$(kubectl get cluster/$(POSTGRES_RELEASE)-cnpg-postgres -n $(POSTGRES_NAMESPACE) -o jsonpath='{.spec.instances}' 2>/dev/null || echo "?"); \
		PODS=$$(kubectl get pods -n $(POSTGRES_NAMESPACE) -l cnpg.io/cluster=$(POSTGRES_RELEASE)-cnpg-postgres --no-headers 2>/dev/null | wc -l); \
		echo "   [$$i/12] Phase: $$PHASE | Pods: $$PODS | Ready: $$READY/$$TOTAL"; \
		if [ "$$PHASE" = "Cluster in healthy state" ]; then \
			echo ""; \
			echo "   ✅ Cluster is healthy!"; \
			break; \
		fi; \
		sleep 15; \
	done
	@echo ""
	@echo "📊 Step 4/5: Cluster Status"
	@echo "   ┌─────────────────────────────────────────────────────────────────┐"
	@kubectl get cluster -n $(POSTGRES_NAMESPACE) 2>/dev/null | sed 's/^/   │ /'
	@echo "   └─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "   Pods:"
	@kubectl get pods -n $(POSTGRES_NAMESPACE) --no-headers 2>/dev/null | sed 's/^/   │ /'
	@echo ""
	@echo "   Services:"
	@kubectl get svc -n $(POSTGRES_NAMESPACE) --no-headers 2>/dev/null | sed 's/^/   │ /'
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║  ✅ Step 5/5: Installation Complete!                              ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🔗 CONNECTION STRINGS:"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "   📍 Internal (from apps in cluster):"
	@echo "      postgresql://appuser:appuser@$(POSTGRES_RELEASE)-cnpg-postgres-rw.$(POSTGRES_NAMESPACE).svc:5432/appdb"
	@echo ""
	@echo "   📍 Read-Only Replicas:"
	@echo "      postgresql://appuser:appuser@$(POSTGRES_RELEASE)-cnpg-postgres-ro.$(POSTGRES_NAMESPACE).svc:5432/appdb"
	@echo ""
	@echo "   📍 External (with port-forward):"
	@echo "      postgresql://appuser:appuser@localhost:5432/appdb"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "🚀 QUICK START:"
	@echo ""
	@echo "   Option 1 - Direct pod access:"
	@echo "      kubectl exec -it $(POSTGRES_RELEASE)-cnpg-postgres-1 -n $(POSTGRES_NAMESPACE) -- psql -U postgres -d appdb"
	@echo ""
	@echo "   Option 2 - Port forward (background):"
	@echo "      make port-forward-postgres"
	@echo "      psql 'postgresql://appuser:appuser@localhost:5432/appdb'"
	@echo ""
	@echo "   Option 3 - Install with port-forward:"
	@echo "      make install-postgres-connect"
	@echo ""

install-postgres-connect: install-postgres
	@echo "🔌 Starting port-forward on localhost:5432..."
	@echo "   Press Ctrl+C to stop"
	@echo ""
	@kubectl port-forward -n $(POSTGRES_NAMESPACE) svc/$(POSTGRES_RELEASE)-cnpg-postgres-rw 5432:5432

uninstall-postgres:
	@echo "Uninstalling PostgreSQL cluster..."
	helm uninstall $(POSTGRES_RELEASE) --namespace $(POSTGRES_NAMESPACE) --ignore-not-found
	@echo "PostgreSQL cluster uninstalled!"

delete-postgres: uninstall-postgres
	@echo "Deleting PostgreSQL namespace and PVCs..."
	kubectl delete pvc --all -n $(POSTGRES_NAMESPACE) --ignore-not-found=true
	kubectl delete namespace $(POSTGRES_NAMESPACE) --ignore-not-found=true
	@echo "PostgreSQL fully deleted!"

delete-cnpg-all: delete-postgres uninstall-cnpg-operator
	@echo "Deleting CNPG Operator and all resources..."
	kubectl delete namespace cnpg-system --ignore-not-found=true
	kubectl delete validatingwebhookconfiguration cnpg-validating-webhook-configuration --ignore-not-found=true
	kubectl delete mutatingwebhookconfiguration cnpg-mutating-webhook-configuration --ignore-not-found=true
	kubectl get crd | grep cnpg | awk '{print $$1}' | xargs -r kubectl delete crd 2>/dev/null || true
	kubectl delete clusterrole -l app.kubernetes.io/name=cloudnative-pg --ignore-not-found=true 2>/dev/null || true
	kubectl delete clusterrolebinding -l app.kubernetes.io/name=cloudnative-pg --ignore-not-found=true 2>/dev/null || true
	@echo "CNPG fully deleted!"

status-postgres:
	@echo "=== PostgreSQL Cluster Status ==="
	kubectl get clusters -n $(POSTGRES_NAMESPACE) 2>/dev/null || echo "No CNPG clusters found"
	@echo ""
	@echo "=== Pods ==="
	kubectl get pods -n $(POSTGRES_NAMESPACE) 2>/dev/null || echo "No pods found"
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -n $(POSTGRES_NAMESPACE) 2>/dev/null || echo "No services found"

logs-postgres:
	kubectl logs -f -l cnpg.io/cluster=$(POSTGRES_RELEASE)-cnpg-postgres -n $(POSTGRES_NAMESPACE) --tail=100

port-forward-postgres:
	@echo "Port forwarding PostgreSQL on localhost:5432..."
	@echo "Connection: psql -h localhost -U appuser -d appdb"
	kubectl port-forward -n $(POSTGRES_NAMESPACE) svc/$(POSTGRES_RELEASE)-cnpg-postgres-rw 5432:5432

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

delete-oracle: uninstall-oracle
	@echo "Deleting Oracle XE namespace and PVCs..."
	kubectl delete pvc --all -n $(ORACLE_NAMESPACE) --ignore-not-found=true
	kubectl delete namespace $(ORACLE_NAMESPACE) --ignore-not-found=true
	@echo "Oracle XE fully deleted!"

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

delete-all: delete-postgres delete-oracle
	@echo "All databases fully deleted!"

clean: delete-cnpg-all delete-oracle
	@echo "Full cleanup complete!"

#------------------------------------------------------------------------------
# Helm Repository
#------------------------------------------------------------------------------

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

git-commit:
	@echo "Committing changes..."
	git add -A
	git commit -m "$(COMMIT_MSG)" || echo "Nothing to commit"

git-push: git-commit
	@echo "Pushing to $(GIT_REPO) ($(GIT_BRANCH))..."
	git push origin $(GIT_BRANCH)
	@echo "Pushed to GitHub successfully!"

git-set-remote:
	@echo "Setting git remote to $(GIT_REPO)..."
	git remote set-url origin $(GIT_REPO) || git remote add origin $(GIT_REPO)
	@echo "Remote set successfully!"
