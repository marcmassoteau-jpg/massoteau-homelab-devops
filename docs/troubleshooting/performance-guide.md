# Performance Troubleshooting Guide

Common Kubernetes performance problems in homelab environments, including CPU throttling, memory pressure, API server latency, etcd performance, and node resource exhaustion.

## CPU Throttling

### Symptoms
- Application response times increase under load
- Pods show high CPU throttling in metrics
- `kubectl top pods` shows CPU usage near the limit
- Container logs indicate slow processing or timeouts

### Diagnosis

```bash
# Check CPU usage for all pods in a namespace
kubectl top pods -n <namespace> --sort-by=cpu

# Check CPU requests and limits vs actual usage
kubectl get pods -n <namespace> -o custom-columns='NAME:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,CPU_LIM:.spec.containers[0].resources.limits.cpu'

# Check node CPU usage
kubectl top nodes

# Check CPU throttling metrics (requires access to cgroup stats)
ssh ubuntu@192.168.1.241 "cat /sys/fs/cgroup/cpu/kubepods/cpu.stat"

# Check pod resource details
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Limits\|Requests"

# Check for CPU throttling events in kernel logs
ssh ubuntu@192.168.1.241 "sudo dmesg | grep -i throttl"
```

### Resolution

1. **Increase CPU limits**: If the application legitimately needs more CPU.
   ```yaml
   resources:
     requests:
       cpu: "500m"
     limits:
       cpu: "2000m"   # Increased from 1000m
   ```

2. **Remove CPU limits**: For non-critical workloads, removing limits avoids throttling while requests ensure scheduling.
   ```yaml
   resources:
     requests:
       cpu: "500m"
     # No CPU limit - pod can burst to available CPU
   ```

3. **Observe CPU usage patterns**: Identify if throttling correlates with specific operations.
   ```bash
   # Monitor CPU usage over time
   watch -n 5 "kubectl top pods -n <namespace> --sort-by=cpu"
   ```

4. **Scale horizontally**: Add more replicas to distribute the load.
   ```bash
   kubectl scale deployment <deployment-name> -n <namespace> --replicas=3
   ```

### Prevention
- Set CPU requests based on observed baseline usage (p50)
- Set CPU limits at 2-4x the request to allow reasonable bursting
- Use Horizontal Pod Autoscaler for workloads with variable load
- Monitor CPU throttling metrics with Prometheus

---

## Memory Pressure and OOM Issues

### Symptoms
- Node enters `MemoryPressure` condition
- Pods killed with OOMKilled exit code (137)
- Node becomes unresponsive or very slow
- `kubectl top nodes` shows memory near capacity
- System processes (kubelet, containerd) start failing

### Diagnosis

```bash
# Check node memory conditions
kubectl get nodes -o custom-columns='NAME:.metadata.name,MEM_PRESSURE:.status.conditions[?(@.type=="MemoryPressure")].status'

# Check node memory usage
kubectl top nodes

# Check pod memory usage sorted by consumption
kubectl top pods -A --sort-by=memory | head -20

# Check for OOMKilled containers
kubectl get pods -A -o json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for pod in data['items']:
    for cs in pod.get('status',{}).get('containerStatuses',[]):
        last = cs.get('lastState',{}).get('terminated',{})
        if last.get('reason') == 'OOMKilled':
            print(f\"{pod['metadata']['namespace']}/{pod['metadata']['name']}: OOMKilled (exit {last.get('exitCode')})\")"

# Check memory limits vs actual usage
kubectl describe node <node-name> | grep -A 20 "Allocated resources"

# Check kernel OOM killer logs on the node
ssh ubuntu@192.168.1.241 "sudo dmesg | grep -i 'out of memory\|oom' | tail -20"
```

### Resolution

1. **Increase memory limits for affected pods**: If the application needs more memory.
   ```yaml
   resources:
     requests:
       memory: "512Mi"
     limits:
       memory: "1Gi"   # Increased from 512Mi
   ```

2. **Add more memory to the node VM**: For Proxmox-based homelab.
   ```bash
   # On Proxmox host (VM must be stopped or hotplug enabled)
   qm set <vmid> --memory 8192   # Increase from 4096 to 8192 MB
   ```

3. **Evict low-priority pods**: Free memory by removing non-critical workloads.
   ```bash
   # Check which pods are consuming the most memory
   kubectl top pods -A --sort-by=memory | head -10

   # Scale down non-critical deployments
   kubectl scale deployment <low-priority-app> -n <namespace> --replicas=0
   ```

4. **Configure resource quotas**: Prevent any single namespace from consuming all memory.
   ```yaml
   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: mem-quota
     namespace: <namespace>
   spec:
     hard:
       requests.memory: "4Gi"
       limits.memory: "8Gi"
   ```

### Prevention
- Always set memory limits on all containers to prevent unbounded growth
- Set memory requests to the application's baseline usage
- Monitor memory trends over time, not just point-in-time snapshots
- Allocate at least 4Gi RAM per worker node for homelab workloads
- Reserve memory for system components via kubelet `systemReserved` and `kubeReserved`

---

## Slow API Server Responses

### Symptoms
- `kubectl` commands take several seconds to return
- API server audit logs show high latency requests
- Webhook timeouts due to slow API responses
- etcd leader election instability
- "context deadline exceeded" errors in component logs

### Diagnosis

```bash
# Measure API server response time
time kubectl get nodes

# Check API server pod resource usage
kubectl top pods -n kube-system -l component=kube-apiserver

# Check API server request latency metrics
kubectl get --raw /metrics | grep apiserver_request_duration_seconds

# Check API server logs for slow requests
kubectl logs -n kube-system -l component=kube-apiserver --tail=100 | grep -i "slow\|timeout"

# Check number of API objects (large object counts slow the API server)
kubectl get --raw /metrics | grep apiserver_storage_objects

# Check etcd health (API server depends on etcd)
kubectl exec -n kube-system etcd-k8s-master-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```

### Resolution

1. **Increase API server resources**: Allocate more CPU and memory to the control plane node.
   ```bash
   # Check current API server resource usage
   kubectl top pods -n kube-system -l component=kube-apiserver

   # On Proxmox, increase control plane VM resources
   # qm set <vmid> --cores 4 --memory 8192
   ```

2. **Reduce webhook latency**: Slow webhooks block API requests.
   ```bash
   # Check webhook response times
   kubectl get --raw /metrics | grep apiserver_admission_webhook_admission_duration_seconds

   # Set webhook timeout lower to fail fast
   kubectl patch validatingwebhookconfiguration <name> \
     --type='json' \
     -p='[{"op": "replace", "path": "/webhooks/0/timeoutSeconds", "value": 5}]'
   ```

3. **Clean up stale resources**: Reduce the number of objects the API server must manage.
   ```bash
   # Delete completed jobs
   kubectl delete jobs --field-selector=status.successful=1 -A

   # Delete completed pods
   kubectl delete pods --field-selector=status.phase=Succeeded -A
   kubectl delete pods --field-selector=status.phase=Failed -A

   # Clean up old replicasets with zero replicas
   kubectl get replicasets -A -o json | python3 -c "
   import json, sys
   data = json.load(sys.stdin)
   for rs in data['items']:
       if rs['status'].get('replicas', 0) == 0:
           name = rs['metadata']['name']
           ns = rs['metadata']['namespace']
           print(f'kubectl delete replicaset {name} -n {ns}')"
   ```

4. **Enable API priority and fairness**: Ensure critical requests are not blocked by bulk operations.
   ```bash
   # Check current flow schemas
   kubectl get flowschemas
   kubectl get prioritylevelconfigurations
   ```

### Prevention
- Allocate at least 2 CPU cores and 4Gi RAM for the control plane node
- Set up a regular cleanup job for completed pods, jobs, and old replicasets
- Monitor API server latency with Prometheus alerts (warn at p99 > 1s)
- Limit the number of admission webhooks to those strictly necessary

---

## etcd Performance Issues

### Symptoms
- "etcdserver: request timed out" in API server or controller-manager logs
- High fsync latency causing slow writes
- etcd leader changes frequently
- "took too long" warnings in etcd logs
- Cluster instability during heavy write operations

### Diagnosis

```bash
# Check etcd pod status and logs
kubectl get pods -n kube-system -l component=etcd
kubectl logs -n kube-system etcd-k8s-master-1 --tail=100

# Check etcd health and performance
kubectl exec -n kube-system etcd-k8s-master-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=table

# Check etcd database size
kubectl exec -n kube-system etcd-k8s-master-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=json | python3 -m json.tool | grep dbSize

# Check disk I/O performance on the etcd node
ssh ubuntu@192.168.1.240 "iostat -x 1 5"
ssh ubuntu@192.168.1.240 "sudo iotop -o -b -n 3"

# Check etcd member list
kubectl exec -n kube-system etcd-k8s-master-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list --write-out=table
```

### Resolution

1. **Defragment the etcd database**: Reclaim space from deleted keys.
   ```bash
   kubectl exec -n kube-system etcd-k8s-master-1 -- etcdctl \
     --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key \
     defrag
   ```

2. **Move etcd data to faster storage**: SSD is strongly recommended for etcd.
   ```bash
   # On Proxmox, add an SSD-backed disk for etcd
   # Mount it at /var/lib/etcd on the control plane node
   ssh ubuntu@192.168.1.240 "lsblk"

   # Update etcd static pod manifest to use the new path
   ssh ubuntu@192.168.1.240 "sudo vi /etc/kubernetes/manifests/etcd.yaml"
   # Update --data-dir and the hostPath volume mount
   ```

3. **Compact etcd history**: Remove old revisions to reduce database size.
   ```bash
   # Get current revision
   REV=$(kubectl exec -n kube-system etcd-k8s-master-1 -- etcdctl \
     --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key \
     endpoint status --write-out=json | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['Status']['header']['revision'])")

   # Compact to current revision
   kubectl exec -n kube-system etcd-k8s-master-1 -- etcdctl \
     --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key \
     compact "$REV"
   ```

4. **Tune etcd parameters**: Adjust heartbeat and election timeouts for slower networks.
   ```bash
   # Edit etcd static pod manifest
   ssh ubuntu@192.168.1.240 "sudo vi /etc/kubernetes/manifests/etcd.yaml"
   # Add to etcd command args:
   #   --heartbeat-interval=500
   #   --election-timeout=5000
   ```

### Prevention
- Use SSD storage for etcd data directory
- Schedule regular etcd defragmentation (weekly cron job)
- Monitor etcd database size and set alerts at 4Gi (default quota is 8Gi)
- Take regular etcd snapshots for disaster recovery
- Keep the control plane node's disk I/O latency below 10ms (p99)

---

## Network Latency Issues

### Symptoms
- High latency between pods on different nodes
- Service-to-service calls timing out intermittently
- TCP retransmissions visible in packet captures
- DNS resolution slow (> 100ms)

### Diagnosis

```bash
# Measure pod-to-pod latency across nodes
kubectl run perf-test-a --image=busybox:1.36 --rm -it --restart=Never \
  --overrides='{"spec":{"nodeName":"k8s-worker-1"}}' -- \
  ping -c 10 <pod-b-ip-on-worker-2>

# Check node-to-node latency
ssh ubuntu@192.168.1.241 "ping -c 10 192.168.1.242"

# Check for packet drops on the node
ssh ubuntu@192.168.1.241 "netstat -s | grep -i 'segments retransmitted\|packet loss'"

# Check Calico overlay network health
kubectl get pods -n kube-system -l k8s-app=calico-node -o wide
kubectl exec -n kube-system <calico-node-pod> -- calico-node -bird-ready

# Check DNS resolution latency
kubectl run dns-perf --image=busybox:1.36 --rm -it --restart=Never -- \
  sh -c "time nslookup kubernetes.default"

# Check network interface errors
ssh ubuntu@192.168.1.241 "ip -s link show"
```

### Resolution

1. **Fix MTU mismatches**: Overlay networks need smaller MTU than the physical network.
   ```bash
   # Check current MTU on pod network interfaces
   kubectl run mtu-check --image=busybox:1.36 --rm -it --restart=Never -- ifconfig eth0

   # For Calico, update MTU in the installation
   kubectl patch felixconfiguration default --type=merge \
     -p '{"spec":{"mtuIfacePattern":"^(en|eth).*","ipipMTU":1440,"vxlanMTU":1410}}'
   ```

2. **Switch Calico encapsulation mode**: VXLAN has higher overhead than direct routing.
   ```bash
   # Check current encapsulation
   kubectl get ippool -o jsonpath='{.items[0].spec.ipipMode}'
   kubectl get ippool -o jsonpath='{.items[0].spec.vxlanMode}'
   ```

3. **Optimize DNS caching**: Reduce DNS lookup latency with NodeLocal DNSCache.
   ```bash
   # Deploy NodeLocal DNS Cache
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml
   ```

4. **Check for noisy neighbors**: Other VMs on the same Proxmox host may be consuming network bandwidth.
   ```bash
   # On Proxmox host, check VM network usage
   qm monitor <vmid>
   # info network
   ```

### Prevention
- Use consistent MTU settings across all nodes and overlay networks
- Monitor network latency between nodes with periodic ping checks
- Keep Calico CNI updated to the latest stable version
- Allocate sufficient network bandwidth to Kubernetes VMs in Proxmox
- Consider using direct routing mode in Calico for better performance in flat networks

---

## Node Resource Exhaustion

### Symptoms
- Multiple pods evicted simultaneously
- Node oscillates between Ready and NotReady
- System services (kubelet, containerd) become unresponsive
- `kubectl describe node` shows multiple pressure conditions
- Excessive swapping (if swap is enabled)

### Diagnosis

```bash
# Check all node conditions
kubectl describe node <node-name> | grep -A 20 Conditions

# Check resource allocation vs capacity
kubectl describe node <node-name> | grep -A 20 "Allocated resources"

# Check current resource usage
kubectl top node <node-name>

# Check system-level resource usage on the node
ssh ubuntu@192.168.1.241 "top -bn1 | head -15"
ssh ubuntu@192.168.1.241 "free -h"
ssh ubuntu@192.168.1.241 "df -h"

# Check kubelet reserved resources
ssh ubuntu@192.168.1.241 "sudo cat /var/lib/kubelet/config.yaml | grep -A 5 'Reserved'"

# Check evicted pods
kubectl get pods -A --field-selector=status.phase=Failed | grep Evicted
```

### Resolution

1. **Configure system and kube reserved resources**: Prevent pods from consuming all node resources.
   ```bash
   # Edit kubelet config on the node
   ssh ubuntu@192.168.1.241 "sudo vi /var/lib/kubelet/config.yaml"
   ```
   ```yaml
   # Add to kubelet config:
   systemReserved:
     cpu: "500m"
     memory: "512Mi"
     ephemeral-storage: "1Gi"
   kubeReserved:
     cpu: "500m"
     memory: "512Mi"
     ephemeral-storage: "1Gi"
   evictionHard:
     memory.available: "200Mi"
     nodefs.available: "10%"
     imagefs.available: "15%"
   ```
   ```bash
   ssh ubuntu@192.168.1.241 "sudo systemctl restart kubelet"
   ```

2. **Apply LimitRange to namespaces**: Set default resource limits for pods that do not specify them.
   ```yaml
   apiVersion: v1
   kind: LimitRange
   metadata:
     name: default-limits
     namespace: <namespace>
   spec:
     limits:
     - default:
         cpu: "500m"
         memory: "512Mi"
       defaultRequest:
         cpu: "100m"
         memory: "128Mi"
       type: Container
   ```

3. **Scale out the cluster**: Distribute workloads across more nodes.
   ```bash
   # Use Terraform to provision additional worker nodes
   cd /path/to/terraform/proxmox-vms
   terraform plan
   terraform apply

   # Join the new node to the cluster with Ansible
   ansible-playbook playbooks/04-install-kubernetes.yml --limit new-worker
   ```

4. **Rebalance workloads**: Check pod distribution across nodes.
   ```bash
   # Check pod distribution
   kubectl get pods -A -o wide --sort-by=.spec.nodeName | \
     awk '{print $8}' | sort | uniq -c | sort -rn
   ```

### Prevention
- Always configure `systemReserved` and `kubeReserved` in kubelet configuration
- Apply LimitRange in every namespace to enforce default resource boundaries
- Monitor node resource utilization trends, not just current values
- Plan capacity to keep average node utilization below 70%
- Use Ansible to enforce consistent kubelet configuration across all nodes
