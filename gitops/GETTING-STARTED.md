# Getting Started with GitOps

Step-by-step guide to deploy your first application using ArgoCD and the GitOps workflow.

## Prerequisites

- ArgoCD deployed on cluster (`ansible-playbook playbooks/06-deploy-argocd.yml`)
- ArgoCD CLI installed (`argocd version`)
- kubectl access to the cluster
- GitOps repository added to ArgoCD

## Step 1: Login to ArgoCD

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode; echo

# Login via CLI
argocd login argocd.homelab.local --insecure --username admin

# Or access the Web UI at http://argocd.homelab.local
```

## Step 2: Add the GitOps Repository

```bash
argocd repo add http://gitlab.homelab.local:30080/homelab/gitops.git \
  --username root \
  --password <your-gitlab-password>
```

## Step 3: Deploy the Demo App to Dev

```bash
# Apply the ArgoCD Application manifest
kubectl apply -f gitops/applications/demo-app-dev.yaml

# Watch the sync
argocd app get demo-app-dev --watch

# Check the deployed resources
kubectl get all -n demo-dev
```

## Step 4: Verify the Deployment

```bash
# Check application health
argocd app get demo-app-dev

# Expected output:
# Name:               demo-app-dev
# Sync Status:        Synced
# Health Status:      Healthy
```

## Step 5: Test Self-Healing

```bash
# Make a manual change (ArgoCD should revert it)
kubectl scale deployment demo-app -n demo-dev --replicas=5

# Wait a few seconds, then check
kubectl get deployment demo-app -n demo-dev
# Should be back to 1 replica (self-healed)
```

## Step 6: Update via GitOps

```bash
# Change the image tag in the dev overlay
cd gitops/environments/dev/demo-app
kustomize edit set image \
  registry.gitlab.homelab.local:30080/homelab/demo-app:new-version

# Commit and push
git add . && git commit -m "Update dev to new version" && git push

# ArgoCD detects the change and syncs automatically
argocd app get demo-app-dev
```

## Step 7: Deploy to Additional Environments

```bash
# Deploy to staging
kubectl apply -f gitops/applications/demo-app-staging.yaml

# Deploy to production
kubectl apply -f gitops/applications/demo-app-prod.yaml

# Check all applications
argocd app list
```

## Next Steps

- Set up the hybrid CI/CD + GitOps workflow (see `examples/gitops-workflow/`)
- Try blue-green deployments with ArgoCD
- Try canary deployments with ArgoCD
- Read Article 17 for comprehensive guidance
