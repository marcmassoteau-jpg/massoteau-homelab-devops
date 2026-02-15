# Hybrid CI/CD + GitOps Workflow Example

Complete example demonstrating the hybrid workflow where CI (Jenkins/GitLab CI) handles build/test/package and ArgoCD handles deploy/sync/heal.

## Architecture

```
Developer pushes code to Git
         │
         ▼
┌─────────────────────────────────┐
│      CI Pipeline (Jenkins)      │
│                                 │
│  build ─→ test ─→ package       │  ← CI/CD (imperative)
│                      │          │
│              Docker image       │
│              pushed to          │
│              registry           │
│                      │          │
│         update-manifests        │
│              │                  │
│   Updates image tag in          │
│   GitOps repository             │
└──────────────┼──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│      GitOps Repository (Git)    │
│                                 │
│  environments/                  │  ← Source of Truth
│    dev/demo-app/                │
│    staging/demo-app/            │
│    prod/demo-app/               │
└──────────────┼──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│          ArgoCD                 │
│                                 │
│  Detects Git change             │  ← GitOps (declarative)
│  Syncs to Kubernetes            │
│  Self-heals drift               │
│  Reports health                 │
└─────────────────────────────────┘
```

## Contents

```
gitops-workflow/
├── demo-app/
│   ├── app.py              # Flask application
│   ├── requirements.txt    # Python dependencies
│   ├── test_app.py         # Unit tests
│   └── Dockerfile          # Multi-stage Docker build
├── Jenkinsfile             # Jenkins pipeline (primary)
├── .gitlab-ci-gitops.yml   # GitLab CI pipeline (alternative)
├── update-gitops-manifest.sh  # Manifest update script
└── README.md               # This file
```

## How It Works

### 1. Developer Pushes Code

```bash
git add .
git commit -m "Add new feature"
git push origin main
```

### 2. CI Pipeline Builds and Tests

The Jenkins pipeline runs automatically:
- **Build**: Installs dependencies
- **Test**: Runs pytest with coverage and flake8 linting (parallel)
- **Package**: Builds Docker image with Kaniko
- **Update Dev Manifests**: Automatically updates dev environment

### 3. Pipeline Updates GitOps Manifests

The pipeline:
- Clones the GitOps repository
- Updates the image tag using `kustomize edit set image`
- Commits with `[skip ci]` to prevent pipeline loops
- Pushes to the GitOps repo

### 4. ArgoCD Syncs to Cluster

ArgoCD detects the Git change and:
- Compares desired state (Git) with live state (cluster)
- Applies the new deployment with updated image
- Reports sync and health status

## Prerequisites

- Jenkins with Kubernetes plugin configured
- ArgoCD deployed on cluster
- GitOps repository set up (`gitops/`)
- Container registry accessible

### Required Jenkins Credentials

| Credential ID | Type | Description |
|---------------|------|-------------|
| `registry-credentials` | Username/Password | Docker registry credentials |
| `gitops-token` | Secret text | Git access token for GitOps repo push |

## Quick Start

### 1. Set Up Jenkins Credentials

In Jenkins (Manage Jenkins > Credentials):

- **registry-credentials**: Username/password for container registry
- **gitops-token**: GitLab/Git access token for pushing to GitOps repo

### 2. Create Multibranch Pipeline

In Jenkins:
1. New Item > Multibranch Pipeline
2. Add Git source with your application repo
3. Script Path: `Jenkinsfile`
4. Save and scan repository

### 3. Push and Watch

```bash
git push origin main
# Watch pipeline in Jenkins
# Watch sync in ArgoCD UI
```

## Alternative: GitLab CI

If using GitLab CI instead of Jenkins, use `.gitlab-ci-gitops.yml`:

```bash
cp .gitlab-ci-gitops.yml /path/to/your/project/.gitlab-ci.yml
```

Set GitLab CI/CD variables:
- `GITOPS_USER` = root
- `GITOPS_TOKEN` = your-gitlab-access-token

## Promotion Flow

```
Dev (automatic) → Staging (manual) → Production (manual)
```

1. **Dev**: Automatically updated on every `main` push
2. **Staging**: Manual trigger in GitLab CI (click play button)
3. **Production**: Manual trigger with additional approval

## Update Script

The standalone `update-gitops-manifest.sh` can be used outside of GitLab CI:

```bash
# Set credentials
export GITOPS_TOKEN=your-token

# Update dev
./update-gitops-manifest.sh dev registry.gitlab.homelab.local:30080/homelab/demo-app abc123

# Promote to staging
./update-gitops-manifest.sh staging registry.gitlab.homelab.local:30080/homelab/demo-app abc123

# Release to production
./update-gitops-manifest.sh prod registry.gitlab.homelab.local:30080/homelab/demo-app v1.0.0
```

## Related Documentation

- **Article 17:** GitOps with ArgoCD
- **GitOps Repository:** `gitops/`
- **ArgoCD Configuration:** `Kubernetes/manifests/argocd/`
- **CI/CD Templates:** `examples/cicd-templates/`
