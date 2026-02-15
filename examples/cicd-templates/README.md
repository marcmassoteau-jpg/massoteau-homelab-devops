# CI/CD Templates Repository

Reusable CI/CD pipeline templates demonstrating advanced patterns for production-grade pipelines in the Kubernetes homelab environment.

## 📋 Overview

This repository contains a collection of **reusable CI/CD templates** for both **Jenkins** (primary CI engine) and **GitLab CI** (for comparison and educational purposes). These templates follow the DRY (Don't Repeat Yourself) principle and demonstrate industry best practices.

**This project uses Jenkins as the PRIMARY CI/CD tool**, with GitLab serving as source control and container registry. GitLab CI templates are included for educational comparison.

**Benefits:**
- **Consistency** - Same patterns across all projects
- **Maintainability** - Update templates once, all projects benefit
- **Best practices** - Security scanning, testing, deployment patterns built-in
- **Flexibility** - Customize via variables without modifying templates
- **Production-ready** - Battle-tested patterns from real-world usage
- **Educational** - Compare Jenkins vs GitLab CI approaches

## 📁 Repository Structure

```
cicd-templates/
├── jenkins/                      # Jenkins Shared Libraries (PRIMARY)
│   ├── vars/                     # Global pipeline functions
│   │   ├── buildApp.groovy       # Build stage functions
│   │   ├── testApp.groovy        # Test stage functions
│   │   ├── scanSecurity.groovy   # Security scanning
│   │   ├── buildDocker.groovy    # Docker image building (Kaniko)
│   │   └── deployK8s.groovy      # Kubernetes deployment
│   ├── src/                      # Shared classes
│   │   └── com/homelab/          # Custom utilities
│   └── README.md                 # Jenkins shared library docs
├── gitlab/                       # GitLab CI Templates (COMPARISON)
│   ├── templates/                # Reusable template definitions
│   │   ├── .build-template.yml   # Build stage templates
│   │   ├── .test-template.yml    # Test stage templates
│   │   ├── .security-scan.yml    # Security scanning templates
│   │   ├── .docker-build.yml     # Docker image building (Kaniko)
│   │   └── .k8s-deploy.yml       # Kubernetes deployment templates
│   ├── .gitlab-ci.yml            # Main example pipeline
│   └── .gitlab-ci-child.yml      # Child pipeline example
├── examples/                     # Example applications
│   ├── node-app/                 # Node.js/Express example
│   │   ├── Jenkinsfile           # Jenkins pipeline
│   │   └── .gitlab-ci.yml        # GitLab CI (comparison)
│   ├── python-app/               # Python/Flask example
│   │   ├── Jenkinsfile
│   │   └── .gitlab-ci.yml
│   └── go-app/                   # Go example
│       ├── Jenkinsfile
│       └── .gitlab-ci.yml
└── README.md                     # This file
```

## 🎯 Jenkins vs GitLab CI: Which to Use?

**This project uses Jenkins as the PRIMARY CI/CD engine** because:

| Aspect | Jenkins | GitLab CI | Our Choice |
|--------|---------|-----------|------------|
| **Flexibility** | Groovy scripting, infinite possibilities | YAML-based, constrained | ✅ Jenkins |
| **Shared Libraries** | Centralized, versioned, reusable | Includes work, but less powerful | ✅ Jenkins |
| **UI/UX** | Blue Ocean provides excellent visualization | Clean, integrated | ✅ Jenkins |
| **Plugin Ecosystem** | 1800+ plugins | Built-in features | ✅ Jenkins |
| **Learning Curve** | Steeper (Groovy) | Easier (YAML) | GitLab CI |
| **Integration** | Needs setup | Native to GitLab | GitLab CI |

**Our Architecture:**
- **GitLab** = Source control + Container registry
- **Jenkins** = CI/CD pipelines (primary)
- **ArgoCD** = GitOps deployment

**Why keep GitLab CI templates?** Educational value - showing both approaches helps users understand trade-offs and choose what fits their needs.

---

## 🔧 Jenkins Shared Libraries (Primary Approach)

### What are Shared Libraries?

Jenkins Shared Libraries allow you to extract common pipeline logic into reusable, centralized functions. Instead of duplicating pipeline code across projects, you call library functions.

**Benefits:**
- **DRY Principle** - Write once, use everywhere
- **Versioning** - Tag library versions, pin in pipelines
- **Testing** - Test library code independently
- **Governance** - Central place to enforce standards
- **Maintainability** - Update once, all pipelines benefit

### Quick Start with Shared Libraries

**1. Configure Shared Library in Jenkins:**

Go to `Manage Jenkins` → `Configure System` → `Global Pipeline Libraries`:

```
Name: homelab-pipeline-library
Default version: main
Retrieval method: Modern SCM
  - Git
  - Project Repository: http://gitlab.homelab.local/homelab/jenkins-shared-library
  - Credentials: gitlab-token
```

**2. Use Library in Jenkinsfile:**

```groovy
@Library('homelab-pipeline-library@main') _

pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                buildApp(
                    language: 'node',
                    buildCommand: 'npm ci && npm run build'
                )
            }
        }
        stage('Test') {
            steps {
                testApp(
                    language: 'node',
                    testCommand: 'npm test'
                )
            }
        }
        stage('Security Scan') {
            steps {
                scanSecurity(
                    scanType: 'trivy',
                    severity: 'HIGH,CRITICAL'
                )
            }
        }
        stage('Build Docker') {
            steps {
                buildDocker(
                    dockerfile: 'Dockerfile',
                    imageTag: "${env.GIT_COMMIT}"
                )
            }
        }
        stage('Deploy') {
            steps {
                deployK8s(
                    environment: 'dev',
                    namespace: 'demo-dev',
                    manifest: 'k8s/deployment.yaml'
                )
            }
        }
    }
}
```

**That's it!** Your pipeline is now 30 lines instead of 200+, and all logic is centralized.

### Available Shared Library Functions

#### Build Functions (`buildApp.groovy`)

```groovy
buildApp(
    language: 'node',           // node, python, go
    buildCommand: 'npm ci && npm run build',
    buildDir: 'dist',
    cacheKey: 'node-modules'
)
```

Handles:
- Language-specific build environments
- Dependency caching
- Build artifact archiving
- Build time reporting

#### Test Functions (`testApp.groovy`)

```groovy
testApp(
    language: 'node',
    testCommand: 'npm test -- --coverage',
    coverageThreshold: 80,
    publishResults: true
)
```

Handles:
- Test execution
- Coverage reporting
- Test result publishing (JUnit XML)
- Coverage thresholds

#### Security Scanning (`scanSecurity.groovy`)

```groovy
scanSecurity(
    scanType: 'trivy',          // trivy, semgrep, secrets
    severity: 'HIGH,CRITICAL',
    failOnVulnerabilities: true,
    imageTag: "${env.GIT_COMMIT}"
)
```

Handles:
- Container vulnerability scanning (Trivy)
- SAST scanning (Semgrep)
- Secret detection (Trivy)
- License compliance
- Security report publishing

#### Docker Build (`buildDocker.groovy`)

```groovy
buildDocker(
    dockerfile: 'Dockerfile',
    imageTag: "${env.GIT_COMMIT}",
    registry: 'registry.gitlab.homelab.local:30080',
    buildArgs: ['VERSION': '1.0.0']
)
```

Handles:
- Kaniko-based builds (no Docker-in-Docker)
- Multi-stage builds
- Build arg injection
- Registry push with credentials
- Image tagging strategy

#### Kubernetes Deployment (`deployK8s.groovy`)

```groovy
deployK8s(
    environment: 'dev',         // dev, staging, prod
    namespace: 'demo-dev',
    manifest: 'k8s/deployment.yaml',
    waitForRollout: true,
    timeout: 300
)
```

Handles:
- Kubectl deployment
- Rollout status monitoring
- Deployment verification
- Rollback on failure
- Environment-specific configuration

### Shared Library Structure

```
jenkins-shared-library/
├── vars/                      # Global functions (loaded automatically)
│   ├── buildApp.groovy
│   ├── testApp.groovy
│   ├── scanSecurity.groovy
│   ├── buildDocker.groovy
│   └── deployK8s.groovy
├── src/                       # Shared classes
│   └── com/
│       └── homelab/
│           ├── Build.groovy
│           ├── Test.groovy
│           └── Deploy.groovy
├── resources/                 # Non-Groovy files
│   ├── templates/
│   │   └── Dockerfile.template
│   └── scripts/
│       └── security-scan.sh
└── README.md
```

### Example: Node.js Application Pipeline

**Without Shared Library (verbose):**

```groovy
pipeline {
    agent { label 'docker' }
    stages {
        stage('Build') {
            steps {
                script {
                    docker.image('node:18-alpine').inside {
                        sh 'npm ci'
                        sh 'npm run build'
                        archiveArtifacts artifacts: 'dist/**', fingerprint: true
                    }
                }
            }
        }
        stage('Test') {
            steps {
                script {
                    docker.image('node:18-alpine').inside {
                        sh 'npm test -- --coverage'
                        publishHTML([
                            reportDir: 'coverage',
                            reportFiles: 'index.html',
                            reportName: 'Coverage Report'
                        ])
                    }
                }
            }
        }
        // ... 100+ more lines
    }
}
```

**With Shared Library (concise):**

```groovy
@Library('homelab-pipeline-library@main') _

pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                buildApp(language: 'node', buildCommand: 'npm ci && npm run build')
            }
        }
        stage('Test') {
            steps {
                testApp(language: 'node', testCommand: 'npm test')
            }
        }
        stage('Scan') {
            steps {
                scanSecurity(scanType: 'trivy', severity: 'HIGH,CRITICAL')
            }
        }
        stage('Docker') {
            steps {
                buildDocker(imageTag: env.GIT_COMMIT)
            }
        }
        stage('Deploy') {
            steps {
                deployK8s(environment: 'dev', namespace: 'demo-dev')
            }
        }
    }
}
```

**Result:** 25 lines vs 200+ lines, same functionality, centrally maintained.

---

## 🚀 GitLab CI Templates (Comparison)

### Quick Start with GitLab CI

For comparison purposes, here's how to use GitLab CI templates:

### Option 1: Include from This Repository

```yaml
# .gitlab-ci.yml in your project
include:
  - project: 'homelab/cicd-templates'
    ref: main
    file:
      - 'templates/.build-template.yml'
      - 'templates/.test-template.yml'
      - 'templates/.docker-build.yml'
      - 'templates/.k8s-deploy.yml'

stages:
  - build
  - test
  - deploy

build-app:
  extends: .build-node
  variables:
    BUILD_COMMAND: "npm ci && npm run build"

test-app:
  extends: .test-node
  variables:
    TEST_COMMAND: "npm test"

deploy-app:
  extends: .deploy-dev
  needs: ["build-app"]
```

### Option 2: Local Includes

Copy templates to your project:

```yaml
# .gitlab-ci.yml
include:
  - local: 'ci/templates/.build-template.yml'
  - local: 'ci/templates/.test-template.yml'

build:
  extends: .build-node
```

### Option 3: Remote Includes

Include from a public repository:

```yaml
include:
  - remote: 'https://gitlab.homelab.local/homelab/cicd-templates/-/raw/main/templates/.build-template.yml'
```

## 📦 Available Templates

### Build Templates (`.build-template.yml`)

Reusable build templates for different languages and frameworks.

**Base template:**
```yaml
.build-template:
  stage: build
  variables:
    BUILD_COMMAND: "echo 'No build command specified'"
    BUILD_OUTPUT_DIR: "dist"
  # ... (artifact handling, caching)
```

**Language-specific templates:**

| Template | Image | Use Case |
|----------|-------|----------|
| `.build-node` | `node:18-alpine` | Node.js/npm projects |
| `.build-python` | `python:3.11-alpine` | Python projects |
| `.build-go` | `golang:1.21-alpine` | Go applications |

**Usage example:**
```yaml
build-frontend:
  extends: .build-node
  variables:
    BUILD_COMMAND: "npm ci && npm run build"
    BUILD_OUTPUT_DIR: "dist"
```

### Test Templates (`.test-template.yml`)

Test execution templates with coverage reporting.

**Available templates:**

| Template | Description |
|----------|-------------|
| `.test-template` | Base test template |
| `.test-node` | Node.js testing (Jest/Mocha) |
| `.test-python` | Python testing (pytest) |
| `.test-go` | Go testing with coverage |
| `.test-integration` | Integration tests with services |

**Usage example:**
```yaml
test-unit:
  extends: .test-node
  variables:
    TEST_COMMAND: "npm run test:unit -- --coverage"
  coverage: '/Statements\s+:\s+(\d+\.\d+)%/'

test-integration:
  extends: .test-integration
  services:
    - postgres:15-alpine
  variables:
    TEST_COMMAND: "npm run test:integration"
    DATABASE_URL: "postgresql://testuser:testpass@postgres:5432/testdb"
```

### Security Templates (`.security-scan.yml`)

Automated security scanning at multiple levels.

**Available scans:**

| Template | Tool | Scans For |
|----------|------|-----------|
| `.scan-trivy-image` | Trivy | Container vulnerabilities |
| `.scan-trivy-fs` | Trivy | Filesystem vulnerabilities |
| `.scan-secrets` | Trivy | Hardcoded secrets |
| `.scan-dependencies` | Various | Dependency vulnerabilities |
| `.scan-licenses` | License Finder | License compliance |
| `.scan-sast` | Semgrep | Code security issues |

**Usage example:**
```yaml
security-scan-image:
  extends: .scan-trivy-image
  variables:
    SCAN_SEVERITY: "HIGH,CRITICAL"
  needs: ["build-docker"]

security-scan-secrets:
  extends: .scan-secrets
  allow_failure: false  # Block pipeline if secrets found
```

### Docker Build Templates (`.docker-build.yml`)

Container image building using Kaniko (no Docker-in-Docker, no privileged mode).

**Available templates:**

| Template | Description |
|----------|-------------|
| `.docker-build` | Base Docker build |
| `.docker-build-latest` | Build with `latest` tag (main only) |
| `.docker-build-feature` | Feature branch builds |
| `.docker-build-release` | Tagged release builds |
| `.docker-build-multistage` | Multi-stage with build args |

**Usage example:**
```yaml
build-image:
  extends: .docker-build
  variables:
    DOCKERFILE_PATH: "Dockerfile"
    IMAGE_TAG: "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA"
  needs:
    - job: build-app
      artifacts: true
```

### Kubernetes Deployment Templates (`.k8s-deploy.yml`)

Kubernetes deployment templates for different environments.

**Available templates:**

| Template | Environment | Auto-deploy | Approval Required |
|----------|-------------|-------------|-------------------|
| `.deploy-dev` | Development | Yes | No |
| `.deploy-staging` | Staging | Yes | No |
| `.deploy-production` | Production | No | Yes (manual) |
| `.deploy-review` | Review (per-MR) | Yes | No |
| `.deploy-canary` | Canary | No | Yes (manual) |

**Usage example:**
```yaml
deploy-to-dev:
  extends: .deploy-dev
  needs: ["build-image"]
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"

deploy-to-prod:
  extends: .deploy-production
  needs: ["build-image", "security-scan"]
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

## 🎯 Advanced Patterns

### Matrix Builds

Test across multiple versions/platforms in parallel:

```yaml
test-matrix:
  extends: .test-node
  parallel:
    matrix:
      - NODE_VERSION: ["16", "18", "20"]
        OS: ["alpine", "bullseye"]
  image: node:${NODE_VERSION}-${OS}
  script:
    - echo "Testing Node ${NODE_VERSION} on ${OS}"
    - npm ci
    - npm test
```

### Dynamic Environments (Review Apps)

Automatically create per-merge-request environments:

```yaml
deploy-review-app:
  extends: .deploy-review
  needs: ["build-docker"]
  rules:
    - if: $CI_MERGE_REQUEST_ID
  environment:
    name: review/$CI_COMMIT_REF_NAME
    url: https://review-${CI_MERGE_REQUEST_IID}.homelab.local
    on_stop: stop-review
    auto_stop_in: 1 week

stop-review:
  extends: .stop-review
  rules:
    - if: $CI_MERGE_REQUEST_ID
      when: manual
```

### Parent-Child Pipelines

Trigger downstream pipelines for monorepos:

```yaml
trigger-microservices:
  stage: deploy
  trigger:
    include: .gitlab-ci-microservices.yml
    strategy: depend
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      changes:
        - microservices/**/*
```

### Conditional Execution

Execute jobs based on rules:

```yaml
deploy-hotfix:
  extends: .deploy-production
  rules:
    # Deploy immediately for hotfix branches
    - if: $CI_COMMIT_BRANCH =~ /^hotfix\/.*/
      when: on_success
    # Manual for main branch
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
    # Never for other branches
    - when: never
```

## 📚 Example Applications

### Node.js Application

See `examples/node-app/.gitlab-ci.yml` for a complete Node.js/Express pipeline:

- Build with npm
- Unit tests with Jest
- Linting with ESLint
- Dependency scanning (npm audit)
- Docker image build
- Deploy to dev/staging/production

### Python Application

See `examples/python-app/.gitlab-ci.yml` for a complete Python/Flask pipeline:

- Build with pip
- Unit tests with pytest
- Code quality with flake8/black/mypy
- Dependency scanning (safety)
- Integration tests with PostgreSQL
- Docker image build
- Deploy to Kubernetes

### Go Application

See `examples/go-app/.gitlab-ci.yml` for a complete Go pipeline:

- Build with go build
- Unit tests with coverage
- Benchmarking
- Linting with golangci-lint
- Security scanning with gosec
- Vulnerability scanning with govulncheck
- Multi-platform builds (Linux/macOS/Windows, amd64/arm64)
- Docker image build

## 🔧 Customization

### Override Template Behavior

Extend templates and override specific sections:

```yaml
build-custom:
  extends: .build-node
  before_script:
    - echo "Custom pre-build steps"
    - !reference [.build-node, before_script]  # Include original before_script
  variables:
    BUILD_COMMAND: "npm ci && npm run custom-build"
  after_script:
    - echo "Custom post-build cleanup"
```

### Template Variables

Common variables you can customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `BUILD_COMMAND` | `echo 'No build command'` | Command to build application |
| `TEST_COMMAND` | `echo 'No test command'` | Command to run tests |
| `SCAN_SEVERITY` | `HIGH,CRITICAL` | Trivy scan severity levels |
| `NAMESPACE` | `default` | Kubernetes namespace |
| `REPLICAS` | `3` | Number of pod replicas |
| `IMAGE_TAG` | `$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA` | Docker image tag |

### Cache Configuration

Templates include sensible caching. Override per project:

```yaml
build:
  extends: .build-node
  cache:
    key: ${CI_COMMIT_REF_SLUG}-custom
    paths:
      - node_modules/
      - .next/cache/
    policy: pull-push  # Default: pull-push
```

## 🛡️ Security Best Practices

### 1. Never Skip Security Scans

```yaml
security-scan:
  extends: .scan-trivy-image
  allow_failure: false  # Block pipeline on HIGH/CRITICAL vulnerabilities
```

### 2. Use Secret Detection

```yaml
scan-secrets:
  extends: .scan-secrets
  allow_failure: false  # Always block if secrets found
```

### 3. Require Manual Approval for Production

```yaml
deploy-prod:
  extends: .deploy-production
  when: manual  # Force manual approval
  environment:
    name: production
```

### 4. Use Protected Branches

Configure GitLab to protect `main` branch and require approvals before merge.

### 5. Scan Dependencies Regularly

```yaml
nightly-dependency-scan:
  extends: .scan-dependencies
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
```

## 📊 Pipeline Optimization

### Reduce Pipeline Time

**Use `needs` to parallelize:**

```yaml
test-unit:
  extends: .test-node
  needs: ["build"]  # Don't wait for unrelated jobs

test-integration:
  extends: .test-integration
  needs: ["build"]  # Run in parallel with test-unit
```

**Use cache effectively:**

```yaml
build:
  extends: .build-node
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
    policy: pull-push  # Download and upload

test:
  extends: .test-node
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
    policy: pull  # Download only, faster
```

**Limit artifact size:**

```yaml
build:
  extends: .build-node
  artifacts:
    paths:
      - dist/  # Only what's needed
    expire_in: 1 hour  # Auto-cleanup
```

## 🐛 Troubleshooting

### Template Not Found

**Error:** `jobs:build config should contain a script keyword`

**Solution:** Ensure you're extending the template correctly:

```yaml
# ❌ Wrong
build:
  include: .build-template

# ✅ Correct
build:
  extends: .build-node
```

### Image Pull Errors

**Error:** `image 'gcr.io/kaniko-project/executor:debug' not found`

**Solution:** Check GitLab Runner has internet access or use local registry mirror.

### Cache Not Working

**Problem:** Cache not persisting between jobs.

**Solution:** Ensure same cache key and S3/MinIO configured:

```yaml
build:
  cache:
    key: ${CI_COMMIT_REF_SLUG}  # Same key for all jobs
    paths:
      - node_modules/
```

### Kubernetes Deployment Fails

**Error:** `error: unable to connect to cluster`

**Solution:** Ensure KUBECONFIG secret is configured:

```bash
# In GitLab CI/CD Variables
kubectl config view --raw | base64 | pbcopy
# Add as KUBECONFIG variable (type: File)
```

## 📚 Jenkins vs GitLab CI: Side-by-Side Comparison

### Example: Build and Test

**Jenkins Shared Library:**
```groovy
@Library('homelab-pipeline-library@main') _
pipeline {
    agent any
    stages {
        stage('Build & Test') {
            steps {
                buildApp(language: 'node', buildCommand: 'npm ci && npm run build')
                testApp(language: 'node', testCommand: 'npm test')
            }
        }
    }
}
```

**GitLab CI Template:**
```yaml
include:
  - project: 'homelab/cicd-templates'
    file: 'gitlab/templates/.build-template.yml'

build:
  extends: .build-node
  variables:
    BUILD_COMMAND: "npm ci && npm run build"

test:
  extends: .test-node
  variables:
    TEST_COMMAND: "npm test"
```

**Analysis:**
- **Jenkins**: Imperative (Groovy code), more flexible, steeper learning curve
- **GitLab CI**: Declarative (YAML), simpler, less flexible
- **Both**: Achieve same goal, centralized logic, maintainable

### When to Choose What?

| Scenario | Recommendation | Reason |
|----------|---------------|--------|
| Complex logic, conditional flows | Jenkins | Groovy scripting power |
| Simple pipelines, quick setup | GitLab CI | YAML simplicity |
| Already using GitLab heavily | GitLab CI | Integrated experience |
| Need plugin ecosystem | Jenkins | 1800+ plugins |
| Team prefers code over config | Jenkins | Groovy is code |
| Team prefers config over code | GitLab CI | YAML is config |
| This homelab project | Jenkins | Flexibility + learning |

## 📖 Related Documentation

- **Article 13**: GitLab Deployment (Source Control & Registry)
- **Article 14**: Jenkins CI/CD Deployment and Integration
- **Article 15**: Advanced CI/CD Patterns with Jenkins Shared Libraries
- **Article 16**: Deployment Strategies
- **Article 17**: GitOps with ArgoCD
- **Jenkins Docs**: [Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- **Jenkins Shared Libraries**: [Extending with Shared Libraries](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)
- **GitLab CI Docs**: [CI/CD Pipeline Configuration Reference](https://docs.gitlab.com/ee/ci/yaml/)
- **Kaniko**: [Building images without Docker](https://github.com/GoogleContainerTools/kaniko)
- **Trivy**: [Vulnerability scanning](https://aquasecurity.github.io/trivy/)

## 🤝 Contributing

To add new templates:

1. Create template file in `templates/`
2. Prefix with `.` (e.g., `.my-template.yml`)
3. Add comprehensive comments
4. Create example usage in `examples/`
5. Update this README
6. Test in real project

## 💡 Tips and Tricks

### Debugging Templates

Use `CI_DEBUG_TRACE: "true"` to see expanded template:

```yaml
build:
  extends: .build-node
  variables:
    CI_DEBUG_TRACE: "true"  # Show all commands
```

### Validate Before Commit

```bash
# Lint CI configuration
gitlab-ci-lint < .gitlab-ci.yml

# Or use GitLab UI
# Project → CI/CD → Pipelines → "CI Lint" button
```

### Template Inheritance

Templates can extend other templates:

```yaml
.base-template:
  stage: build
  script:
    - echo "Base"

.extended-template:
  extends: .base-template
  before_script:
    - echo "Extended"
```

## 📄 License

This template repository is part of the Homelab DevOps Pipeline project.
Licensed under the MIT License.

## 🙏 Acknowledgments

- GitLab CI/CD best practices
- Kubernetes community patterns
- r/homelab community

---

**Ready to use these templates?** Copy them to your project or include from this repository!
