# GitOps Repository

Declarative Kubernetes application deployments managed by ArgoCD, using Kustomize for multi-environment configuration.

## Overview

This directory contains the GitOps repository structure for the Kubernetes homelab. ArgoCD monitors this repository and automatically syncs application state to the cluster.

**GitOps Principle:** Git is the single source of truth for the desired state of all applications and infrastructure.

## Directory Structure

```
gitops/
├── applications/              # ArgoCD Application manifests
│   ├── demo-app-dev.yaml      # Dev environment Application
│   ├── demo-app-staging.yaml  # Staging environment Application
│   ├── demo-app-prod.yaml     # Production environment Application
│   ├── blue-green-app.yaml    # Blue-green deployment Application
│   └── canary-app.yaml        # Canary deployment Application
├── base/                      # Base Kubernetes manifests (shared)
│   ├── demo-app/              # Demo application base
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── blue-green/            # Blue-green deployment base
│   │   ├── deployment-blue.yaml
│   │   ├── deployment-green.yaml
│   │   ├── service-production.yaml
│   │   ├── service-blue.yaml
│   │   ├── service-green.yaml
│   │   └── kustomization.yaml
│   └── canary/                # Canary deployment base
│       ├── deployment-stable.yaml
│       ├── deployment-canary.yaml
│       ├── service-stable.yaml
│       ├── service-canary.yaml
│       ├── ingress-canary.yaml
│       └── kustomization.yaml
├── environments/              # Environment-specific overlays
│   ├── dev/                   # Development environment
│   │   └── demo-app/
│   │       └── kustomization.yaml
│   ├── staging/               # Staging environment
│   │   └── demo-app/
│   │       └── kustomization.yaml
│   └── prod/                  # Production environment
│       └── demo-app/
│           └── kustomization.yaml
├── scripts/                   # Automation scripts
│   ├── switch-blue-green.sh   # Blue-green traffic switch
│   └── promote-canary.sh      # Canary traffic promotion
├── README.md                  # This file
└── GETTING-STARTED.md         # Quick start guide
```

## How It Works

### CI/CD Integration

**GitLab** = Source control + Container registry (stores code and Docker images)
**Jenkins** = CI engine (builds, tests, packages, updates GitOps manifests)
**ArgoCD** = CD engine (deploys to Kubernetes, maintains desired state)

### Kustomize Base + Overlay Pattern

1. **Base manifests** (`base/`) define the common application configuration
2. **Environment overlays** (`environments/`) customize for each environment
3. **ArgoCD Applications** (`applications/`) define what to deploy where

```
base/demo-app/          # Shared: Deployment, Service
    │
    ├── environments/dev/demo-app/     # Override: 1 replica, debug logging
    ├── environments/staging/demo-app/ # Override: 2 replicas, info logging
    └── environments/prod/demo-app/    # Override: 3 replicas, production settings
```

### ArgoCD Sync Policies

| Environment | Auto-Sync | Self-Heal | Auto-Prune | Approval |
|-------------|-----------|-----------|------------|----------|
| Dev | Yes | Yes | Yes | None |
| Staging | Yes | Yes | Yes | None |
| Production | Yes | Yes | **No** | Manual prune |

### Deployment Flow

```
Developer pushes code to GitLab
    │
    ▼
Jenkins builds and tests (triggered by webhook)
    │
    ▼
Jenkins pipeline updates image tag in gitops/environments/
    │
    ▼
Git commit pushed to main branch
    │
    ▼
ArgoCD detects change (polling every 3 minutes)
    │
    ▼
ArgoCD syncs new state to cluster
    │
    ▼
Application updated with zero downtime
```

## Quick Start

See [GETTING-STARTED.md](GETTING-STARTED.md) for step-by-step instructions.

## Environment Configuration

### Dev Environment
- **Namespace:** `demo-dev`
- **Replicas:** 1
- **Log Level:** debug
- **Resources:** Minimal (25m CPU, 32Mi memory)
- **Image Tag:** `dev-latest`

### Staging Environment
- **Namespace:** `demo-staging`
- **Replicas:** 2
- **Log Level:** info
- **Resources:** Standard (50m CPU, 64Mi memory)
- **Image Tag:** `staging-latest`

### Production Environment
- **Namespace:** `demo-prod`
- **Replicas:** 3
- **Log Level:** info
- **Resources:** Production (100m CPU, 128Mi memory)
- **Image Tag:** Semantic versioned (e.g., `v1.0.0`)

## Common Operations

### Deploy to Dev

```bash
# Update image tag in dev overlay
cd gitops/environments/dev/demo-app
kustomize edit set image \
  registry.gitlab.homelab.local:30080/homelab/demo-app:abc123

# Commit and push
git add . && git commit -m "Update dev image to abc123" && git push

# ArgoCD will sync automatically
```

### Promote to Staging

```bash
cd gitops/environments/staging/demo-app
kustomize edit set image \
  registry.gitlab.homelab.local:30080/homelab/demo-app:abc123

git add . && git commit -m "Promote abc123 to staging" && git push
```

### Promote to Production

```bash
cd gitops/environments/prod/demo-app
kustomize edit set image \
  registry.gitlab.homelab.local:30080/homelab/demo-app:v1.0.0

git add . && git commit -m "Release v1.0.0 to production" && git push
```

### Rollback

```bash
# Option 1: Git revert
git revert HEAD
git push

# Option 2: ArgoCD CLI
argocd app rollback demo-app-prod

# Option 3: ArgoCD UI
# Navigate to application > History > Rollback
```

### Check Sync Status

```bash
# All applications
argocd app list

# Specific application
argocd app get demo-app-dev

# Force sync
argocd app sync demo-app-dev
```

## Related Documentation

- **Article 17:** GitOps with ArgoCD
- **ArgoCD Configuration:** `Kubernetes/manifests/argocd/`
- **Ansible Role:** `ansible/roles/argocd/`
- **CI/CD Templates:** `examples/cicd-templates/`
- **Deployment Strategies:** `examples/deployment-strategies/`
