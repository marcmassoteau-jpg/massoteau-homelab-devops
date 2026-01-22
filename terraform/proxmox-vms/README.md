# Terraform - Proxmox VM Provisioning

This directory will contain Terraform configurations for provisioning VMs on Proxmox.

## Status

🚧 **To be implemented in Article 10: Terraform for Infrastructure as Code**

## Planned Features

- Terraform configuration for Proxmox provider
- VM module for creating Kubernetes nodes
- Variables for customization
- Outputs for node information
- State management

## Prerequisites (Future)

- Terraform installed (v1.5+)
- Proxmox API token
- Terraform Proxmox provider

## Usage (Future)

```bash
cd terraform/proxmox-vms

# Initialize Terraform
terraform init

# Plan infrastructure changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy
```

## Resources

- [Terraform Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [Terraform Documentation](https://www.terraform.io/docs)

---

**Note**: Currently, VMs are created using the scripts in `scripts/proxmox/`. Terraform automation will be added in Article 10.
