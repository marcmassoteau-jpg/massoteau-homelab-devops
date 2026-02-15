# Terraform Proxmox VM Configuration

> Automated Kubernetes cluster VM provisioning on Proxmox VE using Terraform

This Terraform configuration provisions virtual machines on Proxmox VE for a complete Kubernetes cluster with one master node and multiple worker nodes.

## 📋 What This Does

- **Provisions VMs**: Creates 1 master + 4 worker nodes (configurable)
- **Cloud-init**: Automatically configures network and SSH access
- **Dynamic**: Easily scale worker nodes up or down
- **Idempotent**: Safe to run multiple times
- **Integrated**: Outputs Ansible inventory for seamless automation

## 🏗️ Architecture

```
Proxmox VE
    └── Kubernetes Cluster (5 VMs)
        ├── k8s-master-tf (192.168.1.250)
        │   └── 4 vCPU / 8GB RAM / 100GB Disk
        └── k8s-worker-tf-01 to 04 (192.168.1.251-254)
            └── 4 vCPU / 16GB RAM / 200GB Disk each
```

## 🚀 Quick Start

### Prerequisites

1. **Proxmox VE 8.x** with API access
2. **Ubuntu 22.04 cloud image template** already created on Proxmox
3. **Terraform 1.5+** installed locally
4. **API Token** created in Proxmox for Terraform

### Step 1: Create Proxmox API Token

On your Proxmox server, create an API token for Terraform:

```bash
# SSH to Proxmox
ssh root@192.168.1.222

# Create user (if not exists)
pveum user add terraform@pam

# Create API token
pveum user token add terraform@pam terraform --privsep=0

# Grant permissions
pveum acl modify / --user terraform@pam --role Administrator
```

Save the token secret - you'll need it for `terraform.tfvars`.

### Step 2: Configure Variables

```bash
cd terraform/proxmox-vms

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Update these critical values:
- `proxmox_api_token_secret`: Your API token from Step 1
- `ssh_public_key`: Your SSH public key (~/.ssh/id_rsa.pub)
- IP addresses (if different from defaults)

### Step 3: Initialize Terraform

```bash
terraform init
```

This downloads the Proxmox provider and initializes the working directory.

### Step 4: Plan Deployment

```bash
terraform plan
```

Review the execution plan. Terraform will show:
- 5 VMs to be created
- Network configuration
- Resource allocation

### Step 5: Deploy Cluster

```bash
terraform apply
```

Type `yes` to confirm. Deployment takes 2-3 minutes.

### Step 6: Verify VMs

```bash
# Check Terraform outputs
terraform output

# Test SSH connectivity
ssh ubuntu@192.168.1.250

# Or use Ansible
cd ../../ansible
ansible all -m ping -i <(terraform -chdir=../terraform/proxmox-vms output -json ansible_inventory_json | jq -r .)
```

## 📁 File Structure

```
terraform/proxmox-vms/
├── main.tf                      # Primary resource definitions
├── variables.tf                 # Input variable declarations
├── outputs.tf                   # Output value definitions
├── terraform.tfvars.example     # Example variable values
├── .gitignore                   # Exclude sensitive files
└── README.md                    # This file
```

## 🔧 Configuration Reference

### VM Template Requirements

Your Proxmox VM template should have:
- **OS**: Ubuntu 22.04 LTS (cloud image)
- **Cloud-init**: Configured and enabled
- **QEMU Guest Agent**: Installed
- **Storage**: At least 100GB for master, 200GB for workers

### Network Configuration

Default network settings:
- **Bridge**: vmbr0
- **Gateway**: 192.168.1.1
- **DNS**: 192.168.1.1, 8.8.8.8
- **Master IP**: 192.168.1.250
- **Worker IPs**: 192.168.1.251-254

Change these in `terraform.tfvars` if needed.

### Resource Sizing

**Master Node:**
- 4 vCPU cores
- 8GB RAM
- 100GB disk

**Worker Nodes:**
- 4 vCPU cores per node
- 16GB RAM per node
- 200GB disk per node

Adjust in `terraform.tfvars` based on your Proxmox resources.

## 📤 Outputs

Terraform provides several useful outputs:

```bash
# View all outputs
terraform output

# Specific outputs
terraform output master_node_ip
terraform output worker_node_ips
terraform output ansible_inventory_json

# Deployment summary
terraform output deployment_summary
```

### Ansible Integration

Generate Ansible inventory directly from Terraform:

```bash
# JSON format (for dynamic inventory)
terraform output -json ansible_inventory_json > ../../ansible/inventory/terraform.json

# INI format (manual)
terraform output deployment_summary
```

## 🔄 Managing the Cluster

### Scale Worker Nodes

Edit `terraform.tfvars`:

```hcl
worker_count = 6  # Increase from 4 to 6
```

Then apply:

```bash
terraform apply
```

Terraform will add 2 new worker nodes without touching existing ones.

### Update VM Resources

Edit resources in `terraform.tfvars`, then:

```bash
terraform apply
```

**Note**: Some changes (like CPU/memory) may require VM reboot.

### Destroy Cluster

```bash
# Remove all VMs
terraform destroy

# Or destroy specific resources
terraform destroy -target=proxmox_vm_qemu.k8s_workers[0]
```

## 🔐 Security Best Practices

1. **Never commit terraform.tfvars** - Contains API tokens and secrets
2. **Use API tokens** - Don't use root password for Terraform
3. **Limit token permissions** - Scope to VM management only
4. **Rotate tokens regularly** - Change API tokens periodically
5. **Secure state files** - Keep .tfstate files secure (contain IPs and metadata)

## 🐛 Troubleshooting

### Issue: "Error creating VM: timeout while waiting for VM"

**Solution**: Proxmox may be slow to respond. Increase timeout:

```hcl
provider "proxmox" {
  pm_timeout = 1200  # Increase to 20 minutes
}
```

### Issue: "VM template not found"

**Solution**: Verify template name matches:

```bash
# On Proxmox
qm list | grep template

# Update terraform.tfvars
vm_template_name = "your-actual-template-name"
```

### Issue: "IP address already in use"

**Solution**: Change IP ranges in `terraform.tfvars` to avoid conflicts:

```hcl
master_ip      = "192.168.1.250"
worker_base_ip = "192.168.1.251"
```

### Issue: Cloud-init not applying

**Solution**: Verify template has cloud-init installed:

```bash
# In the template VM
sudo systemctl status cloud-init
```

## 📚 Next Steps

After deploying VMs with Terraform:

1. **Test connectivity**: SSH to all nodes
2. **Run Ansible playbooks**: Configure Kubernetes
   ```bash
   cd ../../ansible
   ansible-playbook playbooks/01-network-setup.yml
   ansible-playbook playbooks/02-security-hardening.yml
   ansible-playbook playbooks/03-kubernetes-prereqs.yml
   ansible-playbook playbooks/04-install-kubernetes.yml
   ```
3. **Verify cluster**: Check Kubernetes health
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

## 🔗 Related Documentation

- **Article 10**: Terraform Foundations (../../../docs/articles/article-10-terraform-proxmox.md)
- **Terraform Setup Guide**: ../docs/terraform-setup.md
- **Ansible Playbooks**: ../../ansible/README.md
- **Architecture**: ../../docs/architecture/network-design.md

## 🤝 Contributing

Found an issue or want to improve this configuration?

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

MIT License - See LICENSE file for details

---

**Author**: Marc Massoteau
**Repository**: https://github.com/marcmassoteau-jpg/massoteau-homelab-devops
**Blog Series**: https://medium.com/@marcmassoteau
