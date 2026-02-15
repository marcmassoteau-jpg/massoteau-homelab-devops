# Terraform Setup Guide for Proxmox

> Complete guide to setting up Terraform for Proxmox VE infrastructure automation

This guide walks through installing Terraform, configuring the Proxmox provider, and deploying your first Kubernetes cluster VMs.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installing Terraform](#installing-terraform)
3. [Proxmox API Configuration](#proxmox-api-configuration)
4. [VM Template Setup](#vm-template-setup)
5. [Terraform Configuration](#terraform-configuration)
6. [First Deployment](#first-deployment)
7. [Terraform Workflow](#terraform-workflow)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## Prerequisites

Before starting, ensure you have:

- **Proxmox VE 8.x** installed and accessible
- **Root or privileged access** to Proxmox server
- **Ubuntu 22.04 cloud image** downloaded
- **SSH key pair** generated on your workstation
- **Network configuration** planned (IP ranges, gateway, DNS)
- **Basic Linux command line** knowledge

## Installing Terraform

### macOS (Homebrew)

```bash
# Install Terraform via Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify installation
terraform version
```

Expected output:
```
Terraform v1.7.0
on darwin_amd64
```

### Linux (Ubuntu/Debian)

```bash
# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update and install
sudo apt update
sudo apt install terraform

# Verify
terraform version
```

### Linux (RHEL/CentOS)

```bash
# Add HashiCorp repository
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

# Install Terraform
sudo yum install terraform

# Verify
terraform version
```

### Windows

1. Download Terraform from https://www.terraform.io/downloads
2. Extract the `.zip` file
3. Add the directory to your system PATH
4. Verify in PowerShell: `terraform version`

## Proxmox API Configuration

Terraform needs API access to Proxmox. Follow these steps to create a dedicated API token.

### Step 1: Create Terraform User

SSH to your Proxmox server:

```bash
ssh root@192.168.1.222
```

Create a dedicated user for Terraform:

```bash
# Create PAM user
pveum user add terraform@pam --comment "Terraform automation user"

# Set a password (optional, we'll use API tokens instead)
pveum passwd terraform@pam
```

### Step 2: Create API Token

```bash
# Create API token (no privilege separation)
pveum user token add terraform@pam terraform --privsep=0
```

**IMPORTANT**: Save the output! It looks like:

```
┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
╞══════════════╪══════════════════════════════════════╡
│ full-tokenid │ terraform@pam!terraform              │
├──────────────┼──────────────────────────────────────┤
│ info         │ {"privsep":0}                        │
├──────────────┼──────────────────────────────────────┤
│ value        │ xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx │
└──────────────┴──────────────────────────────────────┘
```

Save these values:
- **Token ID**: `terraform@pam!terraform`
- **Token Secret**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Step 3: Grant Permissions

Give the terraform user Administrator privileges:

```bash
# Grant full privileges
pveum acl modify / --user terraform@pam --role Administrator

# Verify permissions
pveum acl list
```

Expected output should show:
```
Path: /
terraform@pam: Administrator
```

### Security Best Practice

For production, limit permissions to only what Terraform needs:

```bash
# Create custom role with limited permissions
pveum role add TerraformRole -privs "VM.Allocate VM.Audit VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit Datastore.AllocateTemplate"

# Apply role
pveum acl modify / --user terraform@pam --role TerraformRole
```

### Step 4: Test API Access

From your workstation, test the API token:

```bash
# Replace with your values
PROXMOX_URL="https://192.168.1.222:8006/api2/json"
TOKEN_ID="terraform@pam!terraform"
TOKEN_SECRET="your-secret-here"

# Test API call
curl -k -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
  "${PROXMOX_URL}/nodes"
```

If successful, you'll see JSON output with Proxmox node information.

## VM Template Setup

Terraform clones VMs from a template. Create an Ubuntu 22.04 cloud image template.

### Step 1: Download Cloud Image

On Proxmox:

```bash
# Download Ubuntu 22.04 cloud image
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Verify download
ls -lh jammy-server-cloudimg-amd64.img
```

### Step 2: Create VM Template

```bash
# Create VM (ID 9000)
qm create 9000 --name ubuntu-2204-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Import disk
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm

# Attach disk
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Add cloud-init drive
qm set 9000 --ide2 local-lvm:cloudinit

# Set boot disk
qm set 9000 --boot c --bootdisk scsi0

# Add serial console
qm set 9000 --serial0 socket --vga serial0

# Enable QEMU guest agent
qm set 9000 --agent enabled=1

# Resize disk (optional, increase from default ~2GB)
qm resize 9000 scsi0 +30G

# Convert to template
qm template 9000

# Verify
qm list | grep template
```

Expected output:
```
9000 ubuntu-2204-template    0      2048    0    0.00    32.00
```

## Terraform Configuration

### Step 1: Clone Repository

```bash
git clone https://github.com/marcmassoteau-jpg/massoteau-homelab-devops.git
cd massoteau-homelab-devops
```

### Step 2: Configure Variables

```bash
cd terraform/proxmox-vms

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
nano terraform.tfvars
```

Update these critical values:

```hcl
# Proxmox connection
proxmox_api_url          = "https://192.168.1.222:8006/api2/json"
proxmox_api_token_id     = "terraform@pam!terraform"
proxmox_api_token_secret = "your-actual-secret-here"  # ← Change this!

# SSH access
ssh_public_key = <<-EOT
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...  # ← Your actual public key!
EOT

# VM template (must match template name from Proxmox)
vm_template_name = "ubuntu-2204-template"

# Network (adjust if your network is different)
master_ip      = "192.168.1.250"  # ← Ensure this IP is available
worker_base_ip = "192.168.1.251"  # ← Workers will use 251, 252, 253, 254
```

**Get your SSH public key**:

```bash
cat ~/.ssh/id_rsa.pub
```

Copy the entire output into the `ssh_public_key` field.

### Step 3: Verify Configuration

```bash
# Check syntax
terraform fmt

# Validate configuration
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

## First Deployment

### Step 1: Initialize Terraform

```bash
terraform init
```

This downloads the Proxmox provider and prepares the working directory.

Expected output:
```
Initializing the backend...

Initializing provider plugins...
- Finding telmate/proxmox versions matching "~> 2.9"...
- Installing telmate/proxmox v2.9.14...
- Installed telmate/proxmox v2.9.14

Terraform has been successfully initialized!
```

### Step 2: Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the output carefully. Terraform will show:
- **5 VMs to create** (1 master + 4 workers)
- Resource specifications (CPU, memory, disk)
- Network configuration
- Cloud-init settings

Example output:
```
Terraform will perform the following actions:

  # proxmox_vm_qemu.k8s_master will be created
  + resource "proxmox_vm_qemu" "k8s_master" {
      + name        = "k8s-master-tf"
      + target_node = "pve"
      + cores       = 4
      + memory      = 8192
      + clone       = "ubuntu-2204-template"
      ...
    }

  # proxmox_vm_qemu.k8s_workers[0] will be created
  ...

Plan: 5 to add, 0 to change, 0 to destroy.
```

### Step 3: Apply Configuration

```bash
terraform apply tfplan
```

Deployment takes 2-3 minutes. You'll see:
- VM creation progress
- Resource allocation
- Network configuration
- Outputs with node information

### Step 4: Verify Deployment

Check Terraform outputs:

```bash
terraform output
```

Example output:
```
deployment_summary = <<EOT

╔════════════════════════════════════════════════════════════╗
║  Kubernetes Cluster - Terraform Deployment Summary        ║
╚════════════════════════════════════════════════════════════╝

Master Node:
  Name: k8s-master-tf
  IP:   192.168.1.250
  VMID: 100
  SSH:  ssh ubuntu@192.168.1.250

Worker Nodes:
  k8s-worker-tf-01: 192.168.1.251 (VMID: 101)
  k8s-worker-tf-02: 192.168.1.252 (VMID: 102)
  k8s-worker-tf-03: 192.168.1.253 (VMID: 103)
  k8s-worker-tf-04: 192.168.1.254 (VMID: 104)

Total Nodes: 5
Environment: homelab

Next Steps:
  1. Wait ~60 seconds for VMs to complete cloud-init
  2. Test connectivity: ansible all -m ping -i inventory
  3. Run Ansible playbooks to configure cluster

╚════════════════════════════════════════════════════════════╝
EOT
```

### Step 5: Test SSH Connectivity

Wait 60 seconds for cloud-init to complete, then test SSH:

```bash
# Test master node
ssh ubuntu@192.168.1.250

# Test worker nodes
ssh ubuntu@192.168.1.251
ssh ubuntu@192.168.1.252
ssh ubuntu@192.168.1.253
ssh ubuntu@192.168.1.254
```

## Terraform Workflow

### Viewing State

```bash
# List all resources
terraform state list

# Show specific resource details
terraform state show proxmox_vm_qemu.k8s_master

# Show all outputs
terraform output
```

### Making Changes

Edit `terraform.tfvars`, then:

```bash
# Preview changes
terraform plan

# Apply changes
terraform apply
```

### Scaling Worker Nodes

Edit `terraform.tfvars`:

```hcl
worker_count = 6  # Increase from 4 to 6
```

Apply:

```bash
terraform plan  # Shows 2 new workers to be added
terraform apply
```

### Destroying Infrastructure

```bash
# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=proxmox_vm_qemu.k8s_workers[0]
```

## Troubleshooting

### Issue: "Error creating VM: timeout while waiting"

**Cause**: Proxmox may be slow or overloaded.

**Solution**: Increase timeout in `main.tf`:

```hcl
provider "proxmox" {
  pm_timeout = 1200  # 20 minutes
}
```

### Issue: "Template not found"

**Cause**: Template name mismatch.

**Solution**: Verify template name on Proxmox:

```bash
qm list | grep template
```

Update `terraform.tfvars`:

```hcl
vm_template_name = "actual-template-name-from-proxmox"
```

### Issue: "IP address already in use"

**Cause**: IP conflict with existing VMs.

**Solution**: Change IP ranges in `terraform.tfvars`:

```hcl
master_ip      = "192.168.1.250"  # Use available IP
worker_base_ip = "192.168.1.251"  # Ensure 251-254 are free
```

### Issue: "Authentication failed"

**Cause**: Incorrect API token or expired token.

**Solution**: Regenerate API token:

```bash
# On Proxmox
pveum user token remove terraform@pam terraform
pveum user token add terraform@pam terraform --privsep=0
```

Update `terraform.tfvars` with new secret.

### Issue: Cloud-init not applying

**Cause**: Template doesn't have cloud-init or QEMU guest agent.

**Solution**: Recreate template with cloud-init:

```bash
# On Proxmox - install cloud-init in template
qm start 9000
# SSH to VM, install: sudo apt update && sudo apt install cloud-init qemu-guest-agent
qm stop 9000
qm template 9000
```

## Best Practices

### Security

1. **Never commit terraform.tfvars** - It contains secrets
2. **Use API tokens** - Don't use root password
3. **Limit permissions** - Use custom roles, not Administrator
4. **Rotate tokens** - Change API tokens regularly (every 90 days)
5. **Secure state files** - Use remote state for teams (S3, Terraform Cloud)

### State Management

For homelab (single user):
- **Local state** is acceptable (`terraform.tfstate`)
- Ensure `.gitignore` excludes `*.tfstate` files

For teams:
- Use **remote state** (Terraform Cloud, S3, etc.)
- Enable state locking
- Use separate state files per environment

### Version Control

Create `.gitignore`:

```gitignore
*.tfstate
*.tfstate.backup
*.tfvars
.terraform/
.terraform.lock.hcl
```

Commit to git:
```bash
git add main.tf variables.tf outputs.tf README.md
git add terraform.tfvars.example .gitignore
git commit -m "Add Terraform configuration for Proxmox"
git push
```

### Code Organization

```
terraform/
├── proxmox-vms/          # Environment-specific
│   ├── main.tf           # Resources
│   ├── variables.tf      # Variable declarations
│   ├── outputs.tf        # Outputs
│   ├── terraform.tfvars  # Values (gitignored)
│   └── README.md
├── modules/              # Reusable modules
│   └── k8s-node/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── docs/
    └── terraform-setup.md  # This file
```

### Resource Naming

Use consistent naming conventions:

```hcl
# Good
resource "proxmox_vm_qemu" "k8s_master" {
  name = "k8s-master-${var.environment}"
}

# Bad
resource "proxmox_vm_qemu" "master1" {
  name = "master"
}
```

### Variables

Always provide:
- **Description**: What the variable controls
- **Type**: String, number, bool, list, map
- **Default**: Sensible default value
- **Validation**: Input validation rules

Example:

```hcl
variable "worker_count" {
  description = "Number of worker nodes (2-10 recommended)"
  type        = number
  default     = 4

  validation {
    condition     = var.worker_count >= 2 && var.worker_count <= 10
    error_message = "worker_count must be between 2 and 10"
  }
}
```

## Next Steps

After deploying VMs with Terraform:

1. **Run Ansible playbooks** to configure Kubernetes:
   ```bash
   cd ../../ansible
   ansible-playbook playbooks/01-network-setup.yml
   ansible-playbook playbooks/02-security-hardening.yml
   ansible-playbook playbooks/03-kubernetes-prereqs.yml
   ansible-playbook playbooks/04-install-kubernetes.yml
   ```

2. **Use the integration script** for one-command deployment:
   ```bash
   scripts/automation/provision-cluster.sh
   ```

3. **Read the articles**:
   - Article 10: Terraform Foundations
   - Article 11: Ansible Configuration Management
   - Article 12: Terraform + Ansible Integration

## Resources

- **Terraform Documentation**: https://www.terraform.io/docs
- **Proxmox Provider**: https://registry.terraform.io/providers/Telmate/proxmox/latest/docs
- **Terraform Best Practices**: https://www.terraform-best-practices.com/
- **Cloud-init Documentation**: https://cloudinit.readthedocs.io/

## Support

- **GitHub Issues**: https://github.com/marcmassoteau-jpg/massoteau-homelab-devops/issues
- **Medium Blog**: https://medium.com/@marcmassoteau

---

**Author**: Marc Massoteau
**Last Updated**: 2026-02-03
**Repository**: https://github.com/marcmassoteau-jpg/massoteau-homelab-devops
