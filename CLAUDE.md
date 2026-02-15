# Kubernetes Homelab Automation Project

## Project Overview

This is a comprehensive Kubernetes homelab automation project with an accompanying Medium article series documenting the journey from infrastructure provisioning to production-grade GitOps workflows.

**Current Status:**
- 17/21 articles complete (~98,605 words, 123% of 80K target)
- Phases 1-6 complete (Infrastructure → Security → CI/CD → GitOps)
- Phases 7-8 planned (Monitoring & Operations)

**Technology Stack:**
- **Infrastructure**: Proxmox VE, Terraform
- **Configuration**: Ansible
- **Container Orchestration**: Kubernetes (kubeadm)
- **CI/CD**: GitLab, Jenkins, ArgoCD
- **GitOps**: ArgoCD with Kustomize
- **Security**: Security hardening, GitHub Actions

## Project Structure

```
.
├── ansible/              # Ansible automation
│   ├── playbooks/       # Main playbooks for each phase
│   └── roles/           # Reusable Ansible roles
├── terraform/           # Infrastructure as Code
│   ├── proxmox-vms/    # VM provisioning
│   └── modules/        # Terraform modules
├── gitops/             # GitOps repository structure
│   ├── base/           # Kustomize base configurations
│   └── overlays/       # Environment-specific overlays
├── examples/           # Example workflows and templates
├── scripts/            # Automation scripts
├── docs/              # Documentation
└── Kubernetes/        # Kubernetes manifests
```

## Coding Standards & Patterns

### Ansible Roles

Follow this standard structure for all Ansible roles:

```
roles/
└── role-name/
    ├── tasks/
    │   └── main.yml          # Main task file
    ├── defaults/
    │   └── main.yml          # Default variables
    ├── handlers/
    │   └── main.yml          # Handlers (optional)
    ├── templates/            # Jinja2 templates
    └── README.md            # Role documentation
```

**Variable Naming Convention:**
- Use pattern: `role_name_variable_name`
- Example: `argocd_namespace`, `gitlab_version`, `jenkins_admin_password`

**YAML Formatting:**
- Use `#=====` dividers between major sections
- Include descriptive comments for complex logic
- Always use 2-space indentation

### Ansible Playbooks

Every playbook must include:

1. **Top comment block** with metadata:
```yaml
# =============================================================================
# Playbook: Deploy [Service Name]
# Description: [What this playbook does]
# Tags: [comma-separated tags]
# =============================================================================
```

2. **Banner in pre_tasks**:
```yaml
pre_tasks:
  - name: Display deployment banner
    ansible.builtin.debug:
      msg:
        - "============================================"
        - "  Deploying [Service Name]"
        - "============================================"
```

3. **Role invocation with tags**:
```yaml
roles:
  - role: service-name
    tags:
      - service-name
      - deployment
```

4. **Post-task verification**:
```yaml
post_tasks:
  - name: Verify deployment
    # verification tasks
```

### Terraform Modules

- Always include `README.md` with usage examples
- Document all variables in `variables.tf`
- Provide meaningful outputs in `outputs.tf`
- Use `.gitignore` to exclude sensitive files

### GitOps Structure

Follow Kustomize base + overlay pattern:
```
gitops/
├── base/
│   ├── kustomization.yaml
│   └── [resource].yaml
└── overlays/
    ├── dev/
    ├── staging/
    └── production/
```

### Documentation & Articles

**Article Structure:**
- Target: 8,000-10,000 words per article
- Sections: 15-20 major sections
- Always include "Execution Context" header before code examples
- Provide real, working code examples
- Include troubleshooting sections

**Code Examples:**
- Always test code before documenting
- Include comments explaining non-obvious logic
- Show both the command and expected output

## Workflow Guidelines

### Git Workflow

- Create feature branches for new work
- Keep commits atomic and well-described
- Follow conventional commit format when possible
- Don't commit sensitive data (use `.gitignore`)

### Testing Approach

- Test Ansible roles individually before integration
- Validate Terraform plans before applying
- Test GitOps changes in dev overlay first
- Document test procedures in role READMEs

### Security Practices

- Never commit credentials or API keys
- Use Ansible Vault for sensitive variables
- Follow security hardening best practices
- Regular security updates via automation

## Current Phase Focus

### Phase 6 Complete: GitOps with ArgoCD
- 46 files created across 6 categories
- ArgoCD Helm values in `Kubernetes/manifests/argocd/`
- Ansible role in `ansible/roles/argocd/`
- GitOps repo structure in `gitops/`
- Hybrid workflow examples in `examples/gitops-workflow/`

### Phase 7 Next: Monitoring Stack
- Prometheus deployment
- Grafana deployment
- Integration with existing services
- Article 18

### Phase 8 Final: Operations & Troubleshooting
- Common troubleshooting scenarios
- Operational runbooks
- Best practices guide
- Articles 19-21

## Working with This Codebase

### Before Creating New Files

1. Check existing patterns in similar components
2. Follow the established directory structure
3. Use consistent naming conventions
4. Document as you build

### When Modifying Existing Code

1. Read the entire file first
2. Understand existing patterns
3. Maintain consistency with current style
4. Update related documentation

### Preferred Approaches

- **Edit existing files** rather than creating new ones when possible
- **Follow established patterns** from existing roles (e.g., gitlab, argocd)
- **Keep it simple**: No over-engineering or premature optimization
- **Document decisions**: Update relevant README files

## Common Commands

### Terraform
```bash
cd terraform/proxmox-vms
terraform init
terraform plan
terraform apply
```

### Ansible
```bash
cd ansible
ansible-playbook playbooks/site.yml --tags [tag-name]
ansible-playbook playbooks/[specific-playbook].yml
```

### Kubernetes
```bash
kubectl get nodes
kubectl get pods -A
kubectl logs [pod-name] -n [namespace]
```

## Important Notes

- **Never create documentation files** unless explicitly requested
- **Avoid emojis** unless user specifically asks
- **No over-engineering**: Only make changes that are directly requested
- **Test before documenting**: All code examples must be verified
- **Security first**: Never compromise on security practices

## Questions?

For help or feedback: https://github.com/anthropics/claude-code/issues
