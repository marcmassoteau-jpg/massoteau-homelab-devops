# Cost Analysis Template

Use this template to track and analyze the total cost of ownership for your Kubernetes homelab cluster.

---

## Hardware Costs

### Initial Investment

| Component | Model/Spec | Quantity | Unit Cost | Total |
|-----------|-----------|----------|-----------|-------|
| Server/Node 1 (Control Plane) | _e.g., Dell Optiplex 7050_ | 1 | $_____ | $_____ |
| Server/Node 2 (Worker) | | 1 | $_____ | $_____ |
| Server/Node 3 (Worker) | | 1 | $_____ | $_____ |
| Server/Node 4 (Worker) | | 1 | $_____ | $_____ |
| Server/Node 5 (Worker) | | 1 | $_____ | $_____ |
| Network Switch | _e.g., Ubiquiti USW-Lite-8_ | 1 | $_____ | $_____ |
| UPS | _e.g., APC BE600M1_ | 1 | $_____ | $_____ |
| Storage (NAS/SSD) | | | $_____ | $_____ |
| Cables/Accessories | | | $_____ | $_____ |
| **Total Hardware** | | | | **$_____** |

### RAM Upgrades

| Node | Original | Upgraded To | Cost |
|------|----------|-------------|------|
| k8s-cp01 | ___GB | ___GB | $_____ |
| k8s-w01 | ___GB | ___GB | $_____ |
| k8s-w02 | ___GB | ___GB | $_____ |
| k8s-w03 | ___GB | ___GB | $_____ |
| k8s-w04 | ___GB | ___GB | $_____ |
| **Total RAM Upgrades** | | | **$_____** |

### Storage Upgrades

| Node | Type | Capacity | Cost |
|------|------|----------|------|
| k8s-cp01 | _SSD/NVMe_ | ___GB | $_____ |
| k8s-w01 | | ___GB | $_____ |
| k8s-w02 | | ___GB | $_____ |
| k8s-w03 | | ___GB | $_____ |
| k8s-w04 | | ___GB | $_____ |
| NAS (if applicable) | | ___TB | $_____ |
| **Total Storage** | | | **$_____** |

---

## Power Consumption

### Per-Node Power Draw

| Component | Idle (W) | Average (W) | Peak (W) | Hours/Day |
|-----------|----------|-------------|----------|-----------|
| k8s-cp01 | ___W | ___W | ___W | 24 |
| k8s-w01 | ___W | ___W | ___W | 24 |
| k8s-w02 | ___W | ___W | ___W | 24 |
| k8s-w03 | ___W | ___W | ___W | 24 |
| k8s-w04 | ___W | ___W | ___W | 24 |
| Network Switch | ___W | ___W | ___W | 24 |
| UPS overhead | ___W | ___W | ___W | 24 |
| **Total** | **___W** | **___W** | **___W** | |

### Monthly Power Cost

| Metric | Value |
|--------|-------|
| Total average watts | ___W |
| kWh per month | ___ kWh _(Watts x 24 x 30 / 1000)_ |
| Electricity rate | $_____ / kWh |
| **Monthly power cost** | **$_____** |
| **Annual power cost** | **$_____** |

**How to measure:**
```bash
# If you have a smart plug or kill-a-watt meter:
# Record idle, average, and peak wattage per node

# Estimate from CPU TDP:
# Idle ~= 30% of TDP
# Average ~= 50% of TDP
# Peak ~= 80% of TDP + peripherals
```

---

## Resource Utilization

### CPU Allocation vs Usage

| Node | Allocatable (cores) | Requested (cores) | Used (avg) | Utilization % |
|------|--------------------|--------------------|------------|---------------|
| k8s-cp01 | ___ | ___ | ___ | ___% |
| k8s-w01 | ___ | ___ | ___ | ___% |
| k8s-w02 | ___ | ___ | ___ | ___% |
| k8s-w03 | ___ | ___ | ___ | ___% |
| k8s-w04 | ___ | ___ | ___ | ___% |
| **Cluster Total** | **___** | **___** | **___** | **___%** |

**How to measure:**
```bash
# Current usage
kubectl top nodes

# Allocatable vs requested
kubectl describe nodes | grep -E "Name:|cpu|memory" | head -40

# Detailed allocation report
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU_CAPACITY:.status.capacity.cpu,\
CPU_ALLOCATABLE:.status.allocatable.cpu
```

### Memory Allocation vs Usage

| Node | Allocatable (GB) | Requested (GB) | Used (avg GB) | Utilization % |
|------|------------------|-----------------|---------------|---------------|
| k8s-cp01 | ___ | ___ | ___ | ___% |
| k8s-w01 | ___ | ___ | ___ | ___% |
| k8s-w02 | ___ | ___ | ___ | ___% |
| k8s-w03 | ___ | ___ | ___ | ___% |
| k8s-w04 | ___ | ___ | ___ | ___% |
| **Cluster Total** | **___** | **___** | **___** | **___%** |

### Storage Allocation vs Usage

| PVC / Volume | Namespace | Allocated | Used | Utilization % |
|-------------|-----------|-----------|------|---------------|
| gitlab-data | gitlab | ___Gi | ___Gi | ___% |
| gitlab-registry | gitlab | ___Gi | ___Gi | ___% |
| gitlab-minio | gitlab | ___Gi | ___Gi | ___% |
| jenkins-home | jenkins | ___Gi | ___Gi | ___% |
| prometheus-data | monitoring | ___Gi | ___Gi | ___% |
| grafana-data | monitoring | ___Gi | ___Gi | ___% |
| argocd-repo | argocd | ___Gi | ___Gi | ___% |
| **Total PVC Storage** | | **___Gi** | **___Gi** | **___%** |

**How to measure:**
```bash
# List all PVCs with capacity
kubectl get pvc -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
STATUS:.status.phase,\
CAPACITY:.status.capacity.storage

# Check actual disk usage on nodes
df -h /var/lib/kubelet
```

---

## Per-Service Cost Allocation

### Resource Consumption by Service

| Service | Namespace | CPU Req | CPU Used | Mem Req | Mem Used | Storage |
|---------|-----------|---------|----------|---------|----------|---------|
| GitLab (all components) | gitlab | ___ cores | ___ cores | ___Gi | ___Gi | ___Gi |
| Jenkins | jenkins | ___ cores | ___ cores | ___Gi | ___Gi | ___Gi |
| ArgoCD | argocd | ___ cores | ___ cores | ___Gi | ___Gi | ___Gi |
| Traefik | traefik | ___ cores | ___ cores | ___Gi | ___Gi | N/A |
| Prometheus | monitoring | ___ cores | ___ cores | ___Gi | ___Gi | ___Gi |
| Grafana | monitoring | ___ cores | ___ cores | ___Gi | ___Gi | ___Gi |
| System (kube-system) | kube-system | ___ cores | ___ cores | ___Gi | ___Gi | N/A |
| **Total** | | **___** | **___** | **___Gi** | **___Gi** | **___Gi** |

**How to measure:**
```bash
# Per-namespace resource usage
for ns in gitlab jenkins argocd traefik monitoring kube-system; do
  echo "=== $ns ==="
  kubectl top pods -n $ns --no-headers 2>/dev/null | \
    awk '{cpu+=$2; mem+=$3} END {printf "CPU: %sm, Memory: %sMi\n", cpu, mem}'
done
```

### Proportional Cost Per Service

| Service | % of Cluster Resources | Share of Hardware | Share of Power | Monthly Cost |
|---------|----------------------|-------------------|---------------|-------------|
| GitLab | ___% | $_____ | $_____ | **$_____** |
| Jenkins | ___% | $_____ | $_____ | **$_____** |
| ArgoCD | ___% | $_____ | $_____ | **$_____** |
| Traefik | ___% | $_____ | $_____ | **$_____** |
| Prometheus + Grafana | ___% | $_____ | $_____ | **$_____** |
| System overhead | ___% | $_____ | $_____ | **$_____** |
| **Total** | **100%** | **$_____** | **$_____** | **$_____** |

_Cost allocation formula: Service monthly cost = (service % of resources) x (total monthly operating cost) + (service % of resources) x (hardware amortized monthly)_

---

## Cloud Comparison

### Equivalent AWS Costs (us-east-1)

| Resource | AWS Service | Spec | Monthly Cost |
|----------|-----------|------|-------------|
| 5x VMs (4 CPU, 16GB RAM) | EC2 t3.xlarge | On-demand | $_____ |
| Managed Kubernetes | EKS | Cluster fee | $73 |
| Load Balancer | ALB | Per hour + LCU | $_____ |
| Persistent Storage (___GB) | EBS gp3 | Per GB/month | $_____ |
| Container Registry | ECR | Storage + transfer | $_____ |
| Monitoring | CloudWatch | Metrics + logs | $_____ |
| CI/CD | CodeBuild + CodePipeline | Build minutes | $_____ |
| GitOps | N/A (ArgoCD on EKS) | Included in compute | $0 |
| Backup storage | S3 | Per GB/month | $_____ |
| Data transfer | | ___GB/month | $_____ |
| **Total AWS Monthly** | | | **$_____** |

### Equivalent GCP Costs (us-central1)

| Resource | GCP Service | Spec | Monthly Cost |
|----------|-----------|------|-------------|
| 5x VMs (4 CPU, 16GB RAM) | GCE e2-standard-4 | On-demand | $_____ |
| Managed Kubernetes | GKE | Cluster fee | $73 |
| Load Balancer | Cloud LB | Per rule + GB | $_____ |
| Persistent Storage (___GB) | Persistent Disk SSD | Per GB/month | $_____ |
| Container Registry | Artifact Registry | Storage + transfer | $_____ |
| Monitoring | Cloud Monitoring | Metrics volume | $_____ |
| **Total GCP Monthly** | | | **$_____** |

### Cost Comparison Summary

| | Homelab | AWS | GCP |
|--|---------|-----|-----|
| Year 1 (hardware + power) | $_____ | $_____ | $_____ |
| Year 2 (power only) | $_____ | $_____ | $_____ |
| Year 3 (power only) | $_____ | $_____ | $_____ |
| **3-Year Total** | **$_____** | **$_____** | **$_____** |
| **Break-even point** | **_____ months** | N/A | N/A |

---

## Total Cost of Ownership (3-Year)

### Summary

| Category | Year 1 | Year 2 | Year 3 | 3-Year Total |
|----------|--------|--------|--------|-------------|
| Hardware (one-time) | $_____ | $0 | $0 | $_____ |
| Hardware upgrades | $_____ | $_____ | $_____ | $_____ |
| Power | $_____ | $_____ | $_____ | $_____ |
| Network/Internet | $_____ | $_____ | $_____ | $_____ |
| Replacement parts | $0 | $_____ | $_____ | $_____ |
| **Total** | **$_____** | **$_____** | **$_____** | **$_____** |

### Amortized Monthly Cost

| Item | Monthly |
|------|---------|
| Hardware (amortized over 3 years) | $_____ |
| Power | $_____ |
| Network | $_____ |
| **Total monthly cost** | **$_____** |

---

## Intangible Value

These benefits do not have direct dollar values but are significant:

| Benefit | Value Assessment |
|---------|-----------------|
| Hands-on Kubernetes experience | High - directly applicable to career |
| Full control over infrastructure | Medium - customization flexibility |
| Data privacy and sovereignty | Medium - no third-party access |
| Learning DevOps practices (CI/CD, GitOps, monitoring) | High - marketable skills |
| Interview preparation | High - demonstrable real-world experience |
| Experimentation freedom | High - no cost per experiment |
| Article/blog content creation | High - professional portfolio |

---

## Notes

_Record any additional cost factors, assumptions, or changes here:_

-
-
-

---

**Last Updated:** ____-__-__
**Next Review:** ____-__-__
