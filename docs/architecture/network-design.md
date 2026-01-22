# Network Design for Kubernetes Cluster

This document describes the network architecture for the homelab Kubernetes cluster.

## Network Overview

The Kubernetes cluster operates on a private home network with static IP assignments for all nodes.

### Network Configuration

- **Network**: 192.168.1.0/24 (private home network)
- **Gateway**: 192.168.1.1 (router/gateway)
- **DNS**: 192.168.1.1 (primary), 8.8.8.8 (secondary)
- **Domain**: localdomain

## Node IP Assignments

### Static IP Addresses

All cluster nodes use static IP addresses configured via cloud-init:

| Node | IP Address | Hostname | Role | Resources |
|------|------------|----------|------|-----------|
| Control Plane | 192.168.1.240 | k8s-master | Master | 8GB RAM, 4 cores, 100GB disk |
| Worker 1 | 192.168.1.241 | k8s-worker-01 | Worker | 16GB RAM, 4 cores, 200GB disk |
| Worker 2 | 192.168.1.242 | k8s-worker-02 | Worker | 16GB RAM, 4 cores, 200GB disk |
| Worker 3 | 192.168.1.243 | k8s-worker-03 | Worker | 16GB RAM, 4 cores, 200GB disk |
| Worker 4 | 192.168.1.244 | k8s-worker-04 | Worker | 16GB RAM, 4 cores, 200GB disk |

### Why Static IPs?

Static IP addresses are essential for Kubernetes because:
1. **Stable references**: Nodes must be able to reliably reach each other
2. **DNS independence**: Cluster can function even with DNS issues
3. **Certificate stability**: TLS certificates reference specific IPs
4. **Load balancer configuration**: External services need predictable endpoints

## Hostname Resolution

### /etc/hosts Configuration

All nodes have identical /etc/hosts files mapping hostnames to IPs:

```
192.168.1.240 k8s-master
192.168.1.241 k8s-worker-01
192.168.1.242 k8s-worker-02
192.168.1.243 k8s-worker-03
192.168.1.244 k8s-worker-04
```

### Cloud-Init Persistence

To prevent cloud-init from overwriting /etc/hosts on reboot, we configure the cloud-init template:

**File**: `/etc/cloud/templates/hosts.debian.tmpl`

This ensures hostname resolution persists across reboots.

## Firewall Configuration

### UFW Rules

Each node runs UFW (Uncomplicated Firewall) with the following configuration:

**Default Policies**:
- Incoming: DENY
- Outgoing: ALLOW

**Allowed Connections**:
- SSH (port 22) from anywhere
- ALL traffic from cluster node IPs (192.168.1.240-244)

### Rationale

- **Simple cluster communication**: Allowing all traffic between nodes simplifies Kubernetes setup
- **External security**: Blocks unwanted external traffic
- **SSH access**: Allows management from workstation

### Production Considerations

For production environments, restrict firewall rules to specific ports:

**Master Node**:
- 6443: Kubernetes API server
- 2379-2380: etcd server client API
- 10250: Kubelet API
- 10259: kube-scheduler
- 10257: kube-controller-manager

**Worker Nodes**:
- 10250: Kubelet API
- 30000-32767: NodePort Services

## Network Verification

### Connectivity Tests

The network must support:
1. **Ping**: ICMP connectivity between all nodes
2. **SSH**: SSH access between all nodes
3. **Hostname resolution**: All hostnames resolve correctly
4. **Internet access**: All nodes can reach external services
5. **DNS**: DNS resolution works from all nodes

### Test Script

Use `scripts/network/test-network.sh` to verify all network requirements:

```bash
./scripts/network/test-network.sh
```

This tests:
- Ping connectivity
- SSH connectivity
- Hostname resolution
- Internet connectivity
- DNS resolution
- Firewall status
- Time synchronization

## Kubernetes Networking

### Pod Network CIDR

The cluster uses a pod network CIDR separate from the node network:

- **Pod Network**: 10.244.0.0/16
- **Service Network**: 10.96.0.0/12 (default)

### CNI Plugin

The cluster will use **Flannel** as the CNI (Container Network Interface) plugin:
- Simple and reliable
- VXLAN backend for pod-to-pod communication
- Well-suited for homelab environments

## Network Topology

```
Internet
    |
[Router/Gateway: 192.168.1.1]
    |
[Home Network: 192.168.1.0/24]
    |
    +-- [Proxmox Host: 192.168.1.222]
    |        |
    |        +-- [k8s-master: 192.168.1.240]
    |        +-- [k8s-worker-01: 192.168.1.241]
    |        +-- [k8s-worker-02: 192.168.1.242]
    |        +-- [k8s-worker-03: 192.168.1.243]
    |        +-- [k8s-worker-04: 192.168.1.244]
    |
    +-- [Workstation: 192.168.1.x]
```

## Network Traffic Flow

### Control Plane → Worker Communication

1. **API requests**: Workers connect to master on port 6443
2. **Kubelet API**: Master connects to workers on port 10250
3. **Pod-to-pod**: Overlay network (Flannel) handles inter-pod traffic

### External → Cluster Communication

1. **NodePort**: External traffic → Node IP:30000-32767 → Service → Pods
2. **LoadBalancer** (future): MetalLB will provide load balancer IPs
3. **Ingress** (future): Nginx Ingress for HTTP/HTTPS routing

## Troubleshooting

### Common Network Issues

**Cannot ping nodes**:
- Check firewall: `sudo ufw status`
- Verify IP configuration: `ip addr show`
- Test from Proxmox host

**Hostname resolution fails**:
- Check /etc/hosts: `cat /etc/hosts`
- Verify cloud-init template: `cat /etc/cloud/templates/hosts.debian.tmpl`
- Test resolution: `getent hosts k8s-master`

**SSH connection refused**:
- Check SSH service: `systemctl status ssh`
- Verify firewall allows SSH: `sudo ufw status | grep 22`
- Test from workstation: `ssh -v ubuntu@192.168.1.240`

**No internet access**:
- Check default route: `ip route show`
- Test DNS: `nslookup google.com`
- Verify gateway: `ping 192.168.1.1`

## Security Considerations

### Current Security

✅ Firewall enabled on all nodes
✅ SSH-only access (no passwords)
✅ Limited incoming traffic
✅ Cluster nodes trust each other

### Future Enhancements

- **Network Policies**: Pod-level network policies with Calico
- **Service Mesh**: Istio or Linkerd for encrypted service-to-service communication
- **VPN**: WireGuard for secure remote access
- **Monitoring**: Network traffic monitoring with Prometheus

## Performance Considerations

### Network Bandwidth

- **1 Gbps** network interfaces on all nodes
- Sufficient for homelab workloads
- Consider 10 Gbps for production workloads

### Latency

- **< 1ms** latency between nodes (same physical host)
- Excellent for distributed systems
- Suitable for databases, caches, and real-time applications

## References

- [Kubernetes Networking Concepts](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [Flannel CNI](https://github.com/flannel-io/flannel)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- Article 3: Network Planning and Static IP Management
