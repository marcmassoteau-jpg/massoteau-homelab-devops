# Integration Test 1: Complete Application Lifecycle

**Test ID**: IT-001
**Test Type**: End-to-End Integration Test
**Component**: CI/CD Pipeline + GitOps Workflow
**Target Duration**: 4 hours
**Status**: READY FOR EXECUTION
**Created**: 2026-02-14
**Environment**: Homelab Kubernetes Cluster

---

## Executive Summary

This integration test validates the complete application lifecycle from code commit through multi-environment deployment using the CI/CD and GitOps infrastructure. The test demonstrates:

- Automated build and test pipeline
- Security scanning integration
- Container image build with Kaniko
- GitOps repository updates
- ArgoCD automatic synchronization
- Manual promotion workflow
- Rollback capabilities

**Test Application**: Node.js Demo App (created for this test)
**Location**: `/tmp/nodejs-demo-app/`

---

## Test Objectives

### Primary Objectives
1. ✅ Validate complete CI/CD pipeline execution
2. ✅ Verify GitOps workflow integration
3. ✅ Test multi-environment promotion (dev → staging → production)
4. ✅ Validate rollback functionality
5. ✅ Measure deployment timing metrics

### Success Criteria
- Code commit triggers automated build
- All pipeline stages execute successfully (test, security scan, build, push)
- GitOps repository updates automatically
- ArgoCD syncs changes to dev environment
- Manual promotion to staging works correctly
- Manual promotion to production works correctly
- Rollback completes successfully
- All timing metrics captured

---

## Test Environment

### Infrastructure Components
- **GitLab**: http://gitlab.homelab.local
- **Jenkins**: http://jenkins.homelab.local
- **ArgoCD**: https://argocd.homelab.local
- **Container Registry**: registry.gitlab.homelab.local
- **Kubernetes Cluster**: k8s-master (192.168.1.240)
- **GitOps Repository**: http://gitlab.homelab.local/root/gitops.git

### Required Access
- GitLab user credentials (with project creation rights)
- Jenkins access (with pipeline creation rights)
- ArgoCD access (for monitoring)
- kubectl access (via SSH tunnel)
- SSH access to Proxmox/k8s-master

### Kubernetes Namespaces
- `development` - Dev environment
- `staging` - Staging environment
- `production` - Production environment

---

## Pre-Test Setup

### 1. Demo Application Created

A complete Node.js demo application has been prepared at `/tmp/nodejs-demo-app/` with:

**Application Files**:
- `app.js` - Express.js web server with health checks
- `package.json` - Dependencies and scripts
- `app.test.js` - Jest unit tests
- `Dockerfile` - Multi-stage container build
- `.eslintrc.json` - Code linting configuration

**CI/CD Configuration**:
- `Jenkinsfile` - Jenkins pipeline (complete lifecycle)
- `.gitlab-ci.yml` - GitLab CI pipeline (complete lifecycle)

**Kubernetes Manifests** (`k8s/` directory):
- `deployment.yaml` - Kubernetes Deployment
- `service.yaml` - ClusterIP Service
- `ingress.yaml` - Traefik Ingress
- `kustomization.yaml` - Kustomize configuration

### 2. GitOps Repository Structure Required

The GitOps repository needs the following structure:

```
gitops/
├── apps/
│   └── nodejs-demo-app/
│       ├── base/
│       │   ├── kustomization.yaml
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── ingress.yaml
│       └── overlays/
│           ├── dev/
│           │   └── kustomization.yaml
│           ├── staging/
│           │   └── kustomization.yaml
│           └── production/
│               └── kustomization.yaml
```

### 3. ArgoCD Application Definition

Create ArgoCD applications for each environment:

```yaml
# dev-nodejs-demo-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nodejs-demo-app-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitlab.homelab.local/root/gitops.git
    targetRevision: main
    path: apps/nodejs-demo-app/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: development
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## Test Procedure

### Phase 1: Project Setup (Est. 15 minutes)

**Step 1.1: Create GitLab Project**
```bash
# Via GitLab UI or API
# Project name: nodejs-demo-app
# Visibility: Internal
# Initialize with README: No
```

**Timing Metric**: `project_creation_time`

**Step 1.2: Initialize Git Repository**
```bash
cd /tmp/nodejs-demo-app
git init
git remote add origin http://gitlab.homelab.local/root/nodejs-demo-app.git
git add .
git commit -m "Initial commit: Node.js demo app"
git branch -M main
git push -u origin main
```

**Timing Metric**: `initial_push_time`

**Step 1.3: Configure CI/CD**

Choose one of:
- **Option A**: Jenkins pipeline (use Jenkinsfile)
- **Option B**: GitLab CI (use .gitlab-ci.yml)

For Jenkins:
```bash
# Create Jenkins pipeline job pointing to:
# Repository: http://gitlab.homelab.local/root/nodejs-demo-app.git
# Script Path: Jenkinsfile
```

**Timing Metric**: `pipeline_config_time`

**Step 1.4: Setup GitOps Repository**
```bash
# Clone gitops repo
git clone http://gitlab.homelab.local/root/gitops.git /tmp/gitops

# Create application structure
mkdir -p /tmp/gitops/apps/nodejs-demo-app/{base,overlays/{dev,staging,production}}

# Copy manifests to base
cp /tmp/nodejs-demo-app/k8s/* /tmp/gitops/apps/nodejs-demo-app/base/

# Create overlay kustomizations (see below)
# Commit and push
cd /tmp/gitops
git add apps/nodejs-demo-app
git commit -m "Add nodejs-demo-app GitOps structure"
git push origin main
```

**Overlay Kustomization Examples**:

`overlays/dev/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: development

resources:
  - ../../base

namePrefix: dev-

images:
  - name: registry.gitlab.homelab.local/nodejs-demo-app
    newTag: latest

replicas:
  - name: nodejs-demo-app
    count: 1

patches:
  - patch: |-
      - op: replace
        path: /spec/rules/0/host
        value: nodejs-demo-app.dev.homelab.local
    target:
      kind: Ingress
      name: nodejs-demo-app
```

**Step 1.5: Create ArgoCD Applications**
```bash
# Apply ArgoCD application for dev
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nodejs-demo-app-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitlab.homelab.local/root/gitops.git
    targetRevision: main
    path: apps/nodejs-demo-app/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: development
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Repeat for staging and production (with manual sync)
```

---

### Phase 2: Initial Build & Deploy (Est. 30 minutes)

**Step 2.1: Trigger Initial Build**

**Start Time**: Record timestamp
```bash
# Trigger Jenkins build or GitLab pipeline
# Via UI or:
curl -X POST http://jenkins.homelab.local/job/nodejs-demo-app/build \
  --user admin:token
```

**Step 2.2: Monitor Pipeline Execution**

Watch pipeline stages:
1. ✅ Test (unit tests + lint)
2. ✅ Security Scan (Trivy)
3. ✅ Build Image (Kaniko)
4. ✅ Scan Image (Trivy container scan)
5. ✅ Update GitOps (commit to gitops repo)

**Expected Pipeline Stages**:
```
Stage                Duration    Status
────────────────────────────────────────
Initialize           ~10s        ✅
Test (Unit + Lint)   ~30s        ✅
Security Scan        ~20s        ✅
Build Image          ~2-3min     ✅
Scan Image           ~30s        ✅
Update GitOps        ~15s        ✅
```

**Timing Metrics**:
- `pipeline_start_time`
- `test_stage_duration`
- `security_scan_duration`
- `build_stage_duration`
- `image_scan_duration`
- `gitops_update_duration`
- `pipeline_end_time`
- `total_pipeline_duration` = end - start

**Step 2.3: Verify GitOps Update**
```bash
cd /tmp/gitops
git pull origin main
cat apps/nodejs-demo-app/overlays/dev/kustomization.yaml | grep newTag
# Should show new image tag
```

**Expected Output**:
```yaml
newTag: abc1234-42  # Short commit SHA + build number
```

**Step 2.4: Monitor ArgoCD Sync**

**Start Time**: Record timestamp when GitOps updated
```bash
# Watch ArgoCD application
argocd app get nodejs-demo-app-dev --refresh

# Or via UI: https://argocd.homelab.local
```

**Expected Sync Stages**:
```
1. OutOfSync detected (~10s after git push)
2. Sync initiated (automated)
3. Resources created/updated
4. Health check (waiting for pods)
5. Synced + Healthy
```

**Timing Metrics**:
- `argocd_sync_start_time`
- `argocd_sync_end_time`
- `argocd_sync_duration` = end - start

**Step 2.5: Verify Deployment**
```bash
# Check pod status
kubectl get pods -n development | grep nodejs-demo-app

# Check application health
kubectl get pods -n development -l app=nodejs-demo-app -o wide

# Test endpoint
curl http://nodejs-demo-app.dev.homelab.local/health
```

**Expected Output**:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2026-02-14T..."
}
```

**Timing Metrics**:
- `dev_deployment_complete_time`
- `commit_to_dev_time` = dev_deployment_complete - initial_push

---

### Phase 3: Code Change & Redeployment (Est. 20 minutes)

**Step 3.1: Make Code Change**

**Start Time**: Record timestamp
```bash
cd /tmp/nodejs-demo-app

# Modify app.js to change version
sed -i '' 's/version: process.env.APP_VERSION || '\''1.0.0'\''/version: process.env.APP_VERSION || '\''1.1.0'\''/' app.js

# Commit and push
git add app.js
git commit -m "Update version to 1.1.0"
git push origin main
```

**Timing Metric**: `code_change_commit_time`

**Step 3.2: Monitor Automated Build**

Watch pipeline automatically trigger and execute same stages as Phase 2.

**Timing Metrics**:
- `rebuild_pipeline_start`
- `rebuild_pipeline_end`
- `rebuild_pipeline_duration`

**Step 3.3: Verify Auto-Deployment to Dev**
```bash
# Watch ArgoCD sync again
argocd app get nodejs-demo-app-dev

# Verify new version
curl http://nodejs-demo-app.dev.homelab.local/ | jq .version
# Expected: "1.1.0"
```

**Timing Metrics**:
- `code_change_to_dev_time` = dev_ready - code_change_commit

---

### Phase 4: Manual Promotion to Staging (Est. 15 minutes)

**Step 4.1: Promote to Staging**

**Start Time**: Record timestamp

**Option A: Via GitLab CI Manual Job**
```bash
# Trigger manual deploy:staging job in GitLab UI
```

**Option B: Via GitOps Manual Update**
```bash
cd /tmp/gitops

# Get current dev image tag
DEV_TAG=$(grep newTag apps/nodejs-demo-app/overlays/dev/kustomization.yaml | awk '{print $2}')

# Update staging overlay
sed -i "s/newTag:.*/newTag: $DEV_TAG/" apps/nodejs-demo-app/overlays/staging/kustomization.yaml

git add apps/nodejs-demo-app/overlays/staging/
git commit -m "Promote nodejs-demo-app to staging: $DEV_TAG"
git push origin main
```

**Timing Metric**: `staging_promotion_start_time`

**Step 4.2: Monitor Staging Deployment**
```bash
# If ArgoCD app for staging is manual sync:
argocd app sync nodejs-demo-app-staging

# Watch deployment
kubectl get pods -n staging -w | grep nodejs-demo-app
```

**Step 4.3: Verify Staging Deployment**
```bash
# Check pods
kubectl get pods -n staging -l app=nodejs-demo-app

# Test endpoint
curl http://nodejs-demo-app.staging.homelab.local/health
curl http://nodejs-demo-app.staging.homelab.local/ | jq .version
# Expected: "1.1.0"
```

**Timing Metrics**:
- `staging_deployment_complete_time`
- `staging_promotion_duration` = complete - start

---

### Phase 5: Manual Promotion to Production (Est. 15 minutes)

**Step 5.1: Promote to Production**

**Start Time**: Record timestamp

**Option A: Via GitLab CI Manual Job**
```bash
# Trigger manual deploy:production job in GitLab UI
```

**Option B: Via GitOps Manual Update**
```bash
cd /tmp/gitops

# Get current staging image tag
STAGING_TAG=$(grep newTag apps/nodejs-demo-app/overlays/staging/kustomization.yaml | awk '{print $2}')

# Update production overlay
sed -i "s/newTag:.*/newTag: $STAGING_TAG/" apps/nodejs-demo-app/overlays/production/kustomization.yaml

git add apps/nodejs-demo-app/overlays/production/
git commit -m "Promote nodejs-demo-app to production: $STAGING_TAG"
git push origin main
```

**Timing Metric**: `production_promotion_start_time`

**Step 5.2: Monitor Production Deployment**
```bash
# Sync ArgoCD app (manual sync policy for production)
argocd app sync nodejs-demo-app-production

# Watch deployment
kubectl get pods -n production -w | grep nodejs-demo-app
```

**Step 5.3: Verify Production Deployment**
```bash
# Check pods (should have more replicas)
kubectl get pods -n production -l app=nodejs-demo-app

# Test endpoint
curl http://nodejs-demo-app.homelab.local/health
curl http://nodejs-demo-app.homelab.local/ | jq .version
# Expected: "1.1.0"
```

**Timing Metrics**:
- `production_deployment_complete_time`
- `production_promotion_duration` = complete - start

---

### Phase 6: Rollback Test (Est. 20 minutes)

**Step 6.1: Identify Rollback Target**

**Start Time**: Record timestamp
```bash
# Get previous image tag from GitOps history
cd /tmp/gitops
git log --oneline apps/nodejs-demo-app/overlays/production/kustomization.yaml | head -5

# Or from ArgoCD history
argocd app history nodejs-demo-app-production
```

**Timing Metric**: `rollback_start_time`

**Step 6.2: Execute Rollback**

**Option A: Git Revert**
```bash
cd /tmp/gitops

# Revert last commit
git revert HEAD --no-edit
git push origin main
```

**Option B: Manual Tag Update**
```bash
cd /tmp/gitops

# Get previous tag (e.g., from git history)
PREVIOUS_TAG="abc1234-41"  # First build tag

# Update production overlay
sed -i "s/newTag:.*/newTag: $PREVIOUS_TAG/" apps/nodejs-demo-app/overlays/production/kustomization.yaml

git add apps/nodejs-demo-app/overlays/production/
git commit -m "Rollback nodejs-demo-app in production to $PREVIOUS_TAG"
git push origin main
```

**Option C: ArgoCD Rollback**
```bash
# Rollback to previous revision
argocd app rollback nodejs-demo-app-production
```

**Step 6.3: Monitor Rollback**
```bash
# Watch pods rolling back
kubectl get pods -n production -w | grep nodejs-demo-app

# Watch rollout status
kubectl rollout status deployment/nodejs-demo-app -n production
```

**Step 6.4: Verify Rollback**
```bash
# Check version (should be back to 1.0.0)
curl http://nodejs-demo-app.homelab.local/ | jq .version
# Expected: "1.0.0"

# Check pod image
kubectl get pods -n production -l app=nodejs-demo-app -o jsonpath='{.items[0].spec.containers[0].image}'
```

**Timing Metrics**:
- `rollback_complete_time`
- `rollback_duration` = complete - start

---

## Timing Metrics Summary

### Target Metrics to Collect

| Metric | Description | Target | Actual |
|--------|-------------|--------|--------|
| `commit_to_dev_time` | Code commit → Dev deployment ready | < 10 min | _______ |
| `pipeline_total_duration` | Full CI/CD pipeline execution | < 6 min | _______ |
| `argocd_sync_duration` | GitOps update → ArgoCD synced | < 2 min | _______ |
| `staging_promotion_duration` | Promotion trigger → Staging ready | < 5 min | _______ |
| `production_promotion_duration` | Promotion trigger → Production ready | < 5 min | _______ |
| `rollback_duration` | Rollback trigger → Rollback complete | < 3 min | _______ |

### Detailed Timing Breakdown Template

```yaml
test_execution:
  start_time: "YYYY-MM-DDTHH:MM:SSZ"
  end_time: "YYYY-MM-DDTHH:MM:SSZ"
  total_duration: "_____ minutes"

phase_1_setup:
  project_creation: "_____ seconds"
  initial_push: "_____ seconds"
  pipeline_config: "_____ minutes"
  gitops_setup: "_____ minutes"
  argocd_setup: "_____ minutes"
  total: "_____ minutes"

phase_2_initial_deploy:
  pipeline:
    start: "YYYY-MM-DDTHH:MM:SSZ"
    end: "YYYY-MM-DDTHH:MM:SSZ"
    stages:
      test: "_____ seconds"
      security_scan: "_____ seconds"
      build_image: "_____ seconds"
      scan_image: "_____ seconds"
      update_gitops: "_____ seconds"
    total: "_____ minutes"
  argocd_sync:
    start: "YYYY-MM-DDTHH:MM:SSZ"
    end: "YYYY-MM-DDTHH:MM:SSZ"
    duration: "_____ seconds"
  commit_to_dev: "_____ minutes"

phase_3_code_change:
  commit_time: "YYYY-MM-DDTHH:MM:SSZ"
  pipeline_duration: "_____ minutes"
  argocd_sync_duration: "_____ seconds"
  code_change_to_dev: "_____ minutes"

phase_4_staging:
  promotion_start: "YYYY-MM-DDTHH:MM:SSZ"
  deployment_complete: "YYYY-MM-DDTHH:MM:SSZ"
  duration: "_____ minutes"

phase_5_production:
  promotion_start: "YYYY-MM-DDTHH:MM:SSZ"
  deployment_complete: "YYYY-MM-DDTHH:MM:SSZ"
  duration: "_____ minutes"

phase_6_rollback:
  rollback_start: "YYYY-MM-DDTHH:MM:SSZ"
  rollback_complete: "YYYY-MM-DDTHH:MM:SSZ"
  duration: "_____ minutes"
```

---

## Expected Results

### Pipeline Execution
- ✅ All pipeline stages execute successfully
- ✅ Unit tests pass with coverage report
- ✅ Lint checks complete (warnings acceptable)
- ✅ Security scans complete (no critical vulnerabilities block build)
- ✅ Container image built and pushed to registry
- ✅ GitOps repository updated with new image tag

### ArgoCD Synchronization
- ✅ Dev environment syncs automatically within 2 minutes
- ✅ Application shows "Synced" and "Healthy" status
- ✅ Pods are running and passing health checks

### Multi-Environment Promotion
- ✅ Manual promotion to staging works correctly
- ✅ Manual promotion to production works correctly
- ✅ Each environment uses correct image tag
- ✅ Environment-specific configurations applied (replicas, ingress)

### Rollback
- ✅ Previous version identified correctly
- ✅ Rollback executes successfully
- ✅ Production returns to previous version
- ✅ Application remains healthy during rollback

### Endpoints
- ✅ Dev: http://nodejs-demo-app.dev.homelab.local
- ✅ Staging: http://nodejs-demo-app.staging.homelab.local
- ✅ Production: http://nodejs-demo-app.homelab.local

---

## Test Validation Checklist

### Pre-Test
- [ ] GitLab accessible
- [ ] Jenkins/GitLab CI configured
- [ ] ArgoCD accessible and configured
- [ ] kubectl access working (SSH tunnel active)
- [ ] Container registry accessible
- [ ] GitOps repository exists and accessible
- [ ] Kubernetes namespaces created (dev, staging, production)

### During Test
- [ ] Initial code push successful
- [ ] Pipeline triggered automatically
- [ ] All pipeline stages pass
- [ ] Image pushed to registry
- [ ] GitOps repository updated
- [ ] ArgoCD detects changes
- [ ] Dev deployment successful
- [ ] Code change triggers rebuild
- [ ] Staging promotion successful
- [ ] Production promotion successful
- [ ] Rollback successful

### Post-Test
- [ ] All timing metrics collected
- [ ] Screenshots captured for evidence
- [ ] Pipeline logs saved
- [ ] ArgoCD sync logs saved
- [ ] Kubernetes events reviewed
- [ ] Application accessible on all environments
- [ ] Cleanup performed (or state documented)

---

## Issue Tracking

### Encountered Issues

| Issue # | Description | Severity | Status | Resolution |
|---------|-------------|----------|--------|------------|
| | | | | |

### Blockers

| Blocker # | Description | Impact | Status | Resolution |
|-----------|-------------|--------|--------|------------|
| | | | | |

---

## Evidence Collection

### Screenshots Required
1. GitLab project created with initial commit
2. Jenkins/GitLab CI pipeline execution (all stages)
3. Container registry showing pushed images
4. GitOps repository commits
5. ArgoCD applications showing sync status
6. kubectl get pods output for each environment
7. Application health check responses
8. Rollback execution and verification

### Logs to Collect
1. Pipeline build logs (full)
2. Kaniko build output
3. Trivy security scan results
4. ArgoCD sync logs
5. Kubernetes deployment events
6. Application pod logs

### Files to Save
1. Final Jenkinsfile or .gitlab-ci.yml
2. GitOps repository structure
3. ArgoCD application manifests
4. Timing metrics YAML
5. kubectl describe output for deployments

---

## Cleanup Procedure

After test completion:

```bash
# Delete ArgoCD applications
kubectl delete application nodejs-demo-app-dev -n argocd
kubectl delete application nodejs-demo-app-staging -n argocd
kubectl delete application nodejs-demo-app-production -n argocd

# Delete Kubernetes deployments
kubectl delete namespace development
kubectl delete namespace staging
kubectl delete namespace production

# Delete GitLab project (optional)
# Via UI or API

# Remove from GitOps repository
cd /tmp/gitops
git rm -r apps/nodejs-demo-app
git commit -m "Remove nodejs-demo-app test application"
git push origin main

# Clean local files
rm -rf /tmp/nodejs-demo-app
rm -rf /tmp/gitops
```

---

## Test Results Summary

### Execution Details
- **Test Date**: _____________
- **Executed By**: _____________
- **Duration**: _____ hours _____ minutes
- **Overall Status**: [ ] PASS [ ] FAIL [ ] PARTIAL

### Performance Summary
- **Commit to Dev**: _____ minutes (Target: < 10 min)
- **Pipeline Duration**: _____ minutes (Target: < 6 min)
- **Staging Promotion**: _____ minutes (Target: < 5 min)
- **Production Promotion**: _____ minutes (Target: < 5 min)
- **Rollback Time**: _____ minutes (Target: < 3 min)

### Test Outcome
- [ ] All objectives met
- [ ] Partial success (specify failures below)
- [ ] Test blocked (specify blockers below)

### Key Findings
```
[Document key observations, performance insights, or issues discovered]
```

### Recommendations
```
[List any recommended improvements or follow-up actions]
```

---

## Appendix A: Demo Application Files

All demo application files are located in `/tmp/nodejs-demo-app/`:

**Application Code**:
- `app.js` - Express.js server (223 lines)
- `package.json` - Dependencies and scripts
- `app.test.js` - Jest unit tests
- `Dockerfile` - Multi-stage container build
- `.eslintrc.json` - Linting configuration
- `.gitignore` - Git ignore rules
- `README.md` - Application documentation

**CI/CD Configuration**:
- `Jenkinsfile` - Jenkins pipeline (167 lines)
- `.gitlab-ci.yml` - GitLab CI pipeline (152 lines)

**Kubernetes Manifests** (`k8s/`):
- `deployment.yaml` - Deployment resource
- `service.yaml` - Service resource
- `ingress.yaml` - Ingress resource
- `kustomization.yaml` - Kustomize base configuration

All files are production-ready and follow best practices for:
- Security (non-root user, minimal image, security context)
- Health checks (liveness and readiness probes)
- Resource management (requests and limits)
- Observability (health endpoints, structured logging)

---

## Appendix B: Pipeline Stage Details

### Jenkinsfile Pipeline Stages

1. **Initialize**: Display build information
2. **Test**: Run unit tests with coverage + ESLint
3. **Security Scan**: Trivy filesystem scan
4. **Build Image**: Kaniko multi-stage build
5. **Scan Image**: Trivy container image scan
6. **Update GitOps**: Commit new image tag to GitOps repo
7. **Deploy to Dev**: ArgoCD auto-sync notification

### GitLab CI Pipeline Stages

1. **test:unit**: Jest tests with coverage reporting
2. **test:lint**: ESLint code quality checks
3. **build:image**: Kaniko image build and push
4. **security:dependencies**: npm audit
5. **security:container**: Trivy image scan
6. **deploy:dev**: Auto-deploy to dev via GitOps update
7. **deploy:staging**: Manual promotion to staging
8. **deploy:production**: Manual promotion to production

---

## Appendix C: Troubleshooting Guide

### Pipeline Fails at Test Stage
**Symptom**: Jest tests fail or timeout
**Cause**: Missing dependencies or test configuration
**Solution**:
```bash
cd /tmp/nodejs-demo-app
npm ci
npm test
# Fix any failing tests
```

### Pipeline Fails at Build Stage
**Symptom**: Kaniko build fails
**Cause**: Registry credentials missing or Dockerfile error
**Solution**:
```bash
# Verify registry secret exists
kubectl get secret registry-credentials -n jenkins

# Test Dockerfile locally
docker build -t test .
```

### ArgoCD Doesn't Sync
**Symptom**: ArgoCD shows OutOfSync but doesn't update
**Cause**: Auto-sync disabled or sync policy issue
**Solution**:
```bash
# Check sync policy
argocd app get nodejs-demo-app-dev -o yaml | grep syncPolicy

# Manual sync
argocd app sync nodejs-demo-app-dev --force
```

### Pods Not Running
**Symptom**: Pods in CrashLoopBackOff or Pending
**Cause**: Image pull issues or resource constraints
**Solution**:
```bash
# Check pod status
kubectl describe pod <pod-name> -n development

# Check events
kubectl get events -n development --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n development
```

### Ingress Not Working
**Symptom**: Cannot access application via URL
**Cause**: DNS resolution or Traefik configuration
**Solution**:
```bash
# Check ingress status
kubectl get ingress -n development

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# Test with port-forward
kubectl port-forward svc/nodejs-demo-app 8080:80 -n development
curl http://localhost:8080/health
```

---

## Appendix D: Reference Commands

### Git Operations
```bash
# Clone repo
git clone http://gitlab.homelab.local/root/nodejs-demo-app.git

# Create commit
git add .
git commit -m "Update application"
git push origin main

# View history
git log --oneline

# Revert commit
git revert HEAD
```

### kubectl Commands
```bash
# Get resources
kubectl get all -n development

# Describe resource
kubectl describe deployment nodejs-demo-app -n development

# View logs
kubectl logs -f deployment/nodejs-demo-app -n development

# Execute command in pod
kubectl exec -it <pod-name> -n development -- sh

# Port forward
kubectl port-forward svc/nodejs-demo-app 8080:80 -n development
```

### ArgoCD Commands
```bash
# List applications
argocd app list

# Get application details
argocd app get nodejs-demo-app-dev

# Sync application
argocd app sync nodejs-demo-app-dev

# View sync history
argocd app history nodejs-demo-app-dev

# Rollback application
argocd app rollback nodejs-demo-app-dev 1
```

### Monitoring Commands
```bash
# Watch pod status
kubectl get pods -n development -w

# Watch deployment rollout
kubectl rollout status deployment/nodejs-demo-app -n development

# Get pod logs with timestamps
kubectl logs --timestamps -f <pod-name> -n development

# Get events
kubectl get events -n development --watch
```

---

## Test Status

**Current Status**: READY FOR EXECUTION

**Prerequisites Met**:
- ✅ Demo application created
- ✅ CI/CD configurations prepared (Jenkins + GitLab CI)
- ✅ Kubernetes manifests ready
- ✅ Test procedure documented
- ✅ Timing metrics template prepared
- ✅ Troubleshooting guide included

**Blockers**:
- ❌ Test requires live homelab environment access
- ❌ GitLab not accessible from current environment
- ❌ Jenkins not accessible from current environment
- ❌ Kubernetes cluster not accessible from current environment

**Next Steps**:
1. Ensure SSH tunnel to homelab is active
2. Verify all infrastructure components are running
3. Execute test following documented procedure
4. Collect timing metrics
5. Document results in this report
6. Share findings with team

---

**Report Prepared By**: Integration Test Agent
**Report Date**: 2026-02-14
**Report Version**: 1.0
**Ready for Execution**: YES
**Environment Required**: Homelab Kubernetes Cluster with active SSH tunnel
