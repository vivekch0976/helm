# Database Helm Charts

This repository contains Helm charts for deploying:
- **cnpg-postgres** - CloudNativePG PostgreSQL HA cluster
- **oracle-xe** - Oracle Express Edition database

## Prerequisites

- Kubernetes cluster (1.25+)
- Helm 3.x
- kubectl configured
- Storage class available (default: `standard`)

---

## Quick Start with Makefile

This repository includes a Makefile for easy deployment and management. All configuration can be customized via the `.env` file.

### Setup

```bash
# Copy the example environment file and customize
cp .env.example .env
vim .env
```

### Available Commands

Run `make help` to see all available commands:

```bash
make help
```

#### Installation Commands

| Command | Description |
|---------|-------------|
| `make install-cnpg-operator` | Install CNPG operator (required for PostgreSQL) |
| `make install-postgres` | Install CNPG PostgreSQL cluster (includes operator) |
| `make install-oracle` | Install Oracle XE database |
| `make install-all` | Install both databases |

#### Uninstallation Commands

| Command | Description |
|---------|-------------|
| `make uninstall-postgres` | Uninstall PostgreSQL cluster |
| `make uninstall-oracle` | Uninstall Oracle XE database |
| `make uninstall-all` | Uninstall both databases |
| `make clean` | Uninstall all and delete namespaces |

#### Development Commands

| Command | Description |
|---------|-------------|
| `make lint` | Lint all Helm charts |
| `make template-postgres` | Render PostgreSQL templates |
| `make template-oracle` | Render Oracle XE templates |
| `make package` | Package all Helm charts |
| `make repo-index` | Generate Helm repo index |
| `make repo-update` | Package charts and update index |

#### Operations Commands

| Command | Description |
|---------|-------------|
| `make status-postgres` | Show PostgreSQL cluster status |
| `make status-oracle` | Show Oracle XE status |
| `make logs-postgres` | Show PostgreSQL logs |
| `make logs-oracle` | Show Oracle XE logs |
| `make port-forward-postgres` | Port forward PostgreSQL (5432) |
| `make port-forward-oracle` | Port forward Oracle XE (1521) |

#### Git Commands

| Command | Description |
|---------|-------------|
| `make git-push` | Commit and push to GitHub |
| `make git-set-remote` | Set git remote from .env |

### Environment Variables (.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `GIT_REPO` | GitHub repository URL | `https://github.com/vivekch0976/helm.git` |
| `GIT_BRANCH` | Git branch name | `master` |
| `POSTGRES_RELEASE` | Helm release name for PostgreSQL | `postgres` |
| `POSTGRES_NAMESPACE` | Kubernetes namespace for PostgreSQL | `postgres` |
| `POSTGRES_VALUES` | Custom values file for PostgreSQL | `` |
| `ORACLE_RELEASE` | Helm release name for Oracle | `oracle` |
| `ORACLE_NAMESPACE` | Kubernetes namespace for Oracle | `oracle` |
| `ORACLE_VALUES` | Custom values file for Oracle | `` |
| `CNPG_VERSION` | CNPG operator version | `1.22.0` |
| `CHARTS_DIR` | Directory for packaged charts | `packages` |
| `COMMIT_MSG` | Default git commit message | `Update Helm charts` |

### Examples

```bash
# Install PostgreSQL with one command (includes operator)
make install-postgres

# Install with custom values file
make install-postgres POSTGRES_VALUES=custom-postgres.yaml

# Install with custom release name and namespace
make install-postgres POSTGRES_RELEASE=mydb POSTGRES_NAMESPACE=production

# Check status
make status-postgres

# View logs
make logs-postgres

# Port forward for local connection
make port-forward-postgres

# Commit and push changes
make git-push COMMIT_MSG="Updated PostgreSQL configuration"

# Package charts for Helm repository
make repo-update
```

---

## CNPG PostgreSQL Helm Chart

### Prerequisites: Install CNPG Operator

```bash
# Install the CNPG operator (required before deploying clusters)
kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.22/releases/cnpg-1.22.0.yaml

# Verify operator is running
kubectl get pods -n cnpg-system
```

### Install

```bash
# Default installation
helm install postgres ./cnpg-postgres

# Custom installation with values
helm install postgres ./cnpg-postgres \
  --set cluster.instances=3 \
  --set storage.size=20Gi \
  --set secrets.superuser.password=mypassword

# Install with custom values file
helm install postgres ./cnpg-postgres -f custom-values.yaml
```

### Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.create` | Create namespace | `true` |
| `namespace.name` | Namespace name | `postgres` |
| `cluster.name` | Cluster name | `postgres-cluster` |
| `cluster.instances` | Number of replicas | `3` |
| `cluster.image.tag` | PostgreSQL version | `16.2` |
| `storage.size` | Storage size | `10Gi` |
| `storage.storageClass` | Storage class | `standard` |
| `secrets.superuser.password` | Superuser password | `supersecretpassword` |
| `secrets.appuser.password` | App user password | `appuserpassword` |
| `bootstrap.database` | Database name | `appdb` |
| `bootstrap.owner` | Database owner | `appuser` |
| `pooler.enabled` | Enable PgBouncer | `false` |
| `backup.enabled` | Enable backups | `false` |
| `service.enabled` | Enable LoadBalancer | `false` |

### Connect to PostgreSQL

```bash
# Port forward
kubectl port-forward -n postgres svc/postgres-cluster-rw 5432:5432

# Connect
psql -h localhost -U appuser -d appdb
```

### Uninstall

```bash
helm uninstall postgres
kubectl delete ns postgres
```

---

## Oracle XE Helm Chart

### Prerequisites

1. Accept Oracle license at https://container-registry.oracle.com/
2. (Optional) Create Docker registry secret:

```bash
kubectl create secret docker-registry oracle-registry \
  --docker-server=container-registry.oracle.com \
  --docker-username=<your-email> \
  --docker-password=<your-password> \
  -n oracle
```

### Install

```bash
# Default installation (Deployment)
helm install oracle ./oracle-xe

# Install as StatefulSet
helm install oracle ./oracle-xe --set deploymentType=statefulset

# Custom installation
helm install oracle ./oracle-xe \
  --set oracle.password=MyPassword123 \
  --set persistence.size=50Gi \
  --set externalService.enabled=true
```

### Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.create` | Create namespace | `true` |
| `namespace.name` | Namespace name | `oracle` |
| `deploymentType` | `deployment` or `statefulset` | `deployment` |
| `image.tag` | Oracle XE version | `21.3.0-xe` |
| `oracle.password` | SYS/SYSTEM password | `OraclePassword123` |
| `oracle.characterSet` | Character set | `AL32UTF8` |
| `persistence.enabled` | Enable persistence | `true` |
| `persistence.size` | Storage size | `20Gi` |
| `persistence.storageClass` | Storage class | `standard` |
| `resources.requests.memory` | Memory request | `2Gi` |
| `resources.limits.memory` | Memory limit | `4Gi` |
| `externalService.enabled` | Enable LoadBalancer | `false` |
| `initScripts.enabled` | Enable init scripts | `true` |

### Connect to Oracle

```bash
# Port forward
kubectl port-forward -n oracle svc/oracle-xe 1521:1521

# Connect as SYSDBA
sqlplus sys/OraclePassword123@localhost:1521/XE as sysdba

# Connect to PDB
sqlplus appuser/apppassword123@localhost:1521/XEPDB1
```

### JDBC Connection String

```
jdbc:oracle:thin:@//oracle-xe.oracle.svc.cluster.local:1521/XEPDB1
```

### Uninstall

```bash
helm uninstall oracle
kubectl delete ns oracle
```

---

## Directory Structure

```
├── .env.example              # Environment template
├── .gitignore                # Git ignore rules
├── Makefile                  # Automation commands
├── README.md
├── cnpg-postgres/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── namespace.yaml
│       ├── secrets.yaml
│       ├── cluster.yaml
│       ├── service.yaml
│       ├── pooler.yaml
│       ├── scheduled-backup.yaml
│       └── NOTES.txt
├── oracle-xe/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── namespace.yaml
│       ├── secret.yaml
│       ├── configmap.yaml
│       ├── pvc.yaml
│       ├── deployment.yaml
│       ├── statefulset.yaml
│       ├── service.yaml
│       └── NOTES.txt
```

## Lint Charts

```bash
# Using Makefile
make lint

# Or directly with Helm
helm lint ./cnpg-postgres
helm lint ./oracle-xe
```

## Template Rendering (Debug)

```bash
# Using Makefile
make template-postgres
make template-oracle

# Or directly with Helm
helm template postgres ./cnpg-postgres
helm template oracle ./oracle-xe
```
