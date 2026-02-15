# GitOps Architecture

Architecture documentation for the GitOps implementation using ArgoCD in the Kubernetes homelab.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Developer Workstation                     │
│                                                                   │
│  Code changes ──→ git push ──→ GitLab (source code)              │
│                                      │                            │
│                          Webhook triggers Jenkins                 │
│                                      │                            │
│                               Jenkins Pipeline                    │
│                          (build → test → package)                 │
│                                      │                            │
│                Push image to GitLab Registry                      │
│                          Update GitOps manifests                  │
│                          (image tag via kustomize)                │
│                                      │                            │
│                               git push ──→ GitOps Repo            │
└──────────────────────────────────────┼────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                            │
│                                                                   │
│  ┌──────────────────────────────────────────────────────┐        │
│  │                   ArgoCD (namespace: argocd)          │        │
│  │                                                        │        │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  │        │
│  │  │  API Server  │  │  Repo Server  │  │ Controller │  │        │
│  │  │  (Web UI,    │  │  (Git clone,  │  │ (Diff,     │  │        │
│  │  │   CLI, API)  │  │   manifest    │  │  Sync,     │  │        │
│  │  │              │  │   render)     │  │  Heal)     │  │        │
│  │  └─────────────┘  └──────────────┘  └────────────┘  │        │
│  │         │                  │                │         │        │
│  │         └──────────────────┼────────────────┘         │        │
│  │                            │                           │        │
│  │                      ┌─────┴──────┐                   │        │
│  │                      │   Redis    │                   │        │
│  │                      │   (cache)  │                   │        │
│  │                      └────────────┘                   │        │
│  └──────────────────────────────────────────────────────┘        │
│                            │                                      │
│                   Syncs to target namespaces                      │
│                            │                                      │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐                        │
│  │demo-dev │  │demo-stag │  │demo-prod │                        │
│  │ 1 replica│  │ 2 replica│  │ 3 replica│                        │
│  └─────────┘  └──────────┘  └──────────┘                        │
│                                                                   │
│  ┌─────────────────────┐  ┌──────────────────┐                  │
│  │ demo-blue-green     │  │ demo-canary      │                  │
│  │ (blue + green deploy)│  │ (stable + canary)│                  │
│  └─────────────────────┘  └──────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

## GitOps Repository Structure

```
gitops/
├── applications/          ← ArgoCD Application CRDs
│   │                        (what to deploy and where)
│   ├── demo-app-dev.yaml
│   ├── demo-app-staging.yaml
│   ├── demo-app-prod.yaml
│   ├── blue-green-app.yaml
│   └── canary-app.yaml
│
├── base/                  ← Shared base manifests
│   │                        (common configuration)
│   ├── demo-app/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── blue-green/
│   │   ├── deployment-blue.yaml
│   │   ├── deployment-green.yaml
│   │   ├── service-*.yaml
│   │   └── kustomization.yaml
│   └── canary/
│       ├── deployment-stable.yaml
│       ├── deployment-canary.yaml
│       ├── service-*.yaml
│       ├── ingress-canary.yaml
│       └── kustomization.yaml
│
├── environments/          ← Per-environment overlays
│   │                        (environment-specific config)
│   ├── dev/demo-app/
│   │   └── kustomization.yaml   (1 replica, debug, minimal)
│   ├── staging/demo-app/
│   │   └── kustomization.yaml   (2 replicas, info)
│   └── prod/demo-app/
│       └── kustomization.yaml   (3 replicas, production)
│
└── scripts/               ← Automation helpers
    ├── switch-blue-green.sh
    └── promote-canary.sh
```

## Deployment Flow

### Standard Deployment (Hybrid)

```
1. Developer pushes code to GitLab (source repository)
2. Jenkins pipeline runs (triggered by GitLab webhook):
   a. Build application
   b. Run tests
   c. Build Docker image → Push to GitLab registry
   d. Update image tag in GitOps repo via kustomize
3. Git commit pushed to GitOps repo with [skip ci]
4. ArgoCD detects change (polling every 3 minutes)
5. ArgoCD renders Kustomize manifests
6. ArgoCD compares desired state with live state
7. ArgoCD applies differences to cluster
8. ArgoCD reports sync and health status
```

### Blue-Green Traffic Switch

```
1. New version deployed to inactive environment (via Git)
2. ArgoCD syncs new image to inactive deployment
3. Test inactive deployment directly
4. Run switch-blue-green.sh → Updates role labels in Git
5. ArgoCD syncs label change
6. Production service routes to new active deployment
```

### Canary Promotion

```
1. New canary image deployed (via Git)
2. ArgoCD syncs canary deployment
3. Run promote-canary.sh 10 → Updates IngressRoute weights
4. ArgoCD syncs new weights (10% canary)
5. Monitor metrics
6. Progressively increase: 25% → 50% → 100%
7. Each step is a Git commit, ArgoCD syncs automatically
```

## Network Architecture

```
External Traffic
      │
      ▼
Traefik Ingress Controller
      │
      ├── argocd.homelab.local → ArgoCD Server (port 80)
      ├── jenkins.homelab.local → Jenkins Server (port 80)
      ├── demo-app.homelab.local → Demo App Service
      └── gitlab.homelab.local → GitLab (port 30080)
```

## Resource Allocation

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| ArgoCD Server | 100m | 128Mi | 500m | 512Mi |
| Repo Server | 100m | 128Mi | 500m | 512Mi |
| Controller | 250m | 256Mi | 1000m | 1Gi |
| ApplicationSet | 50m | 64Mi | 200m | 256Mi |
| Redis | 50m | 64Mi | 200m | 256Mi |
| **Total ArgoCD** | **550m** | **640Mi** | **2400m** | **2.5Gi** |

## Related Documentation

- **Article 17:** GitOps with ArgoCD
- **ArgoCD Values:** `Kubernetes/manifests/argocd/argocd-values.yaml`
- **Ansible Role:** `ansible/roles/argocd/README.md`
- **GitOps Repository:** `gitops/README.md`
- **Comparison:** `docs/comparisons/cicd-vs-gitops.md`
