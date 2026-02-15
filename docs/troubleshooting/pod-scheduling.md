# Pod Scheduling Troubleshooting Guide

Common pod scheduling issues, their causes, and how to resolve them.

## Pending Pods (Insufficient Resources)

### Symptoms
- Pod stays in `Pending` state
- Events show: `FailedScheduling` with message `Insufficient cpu` or `Insufficient memory`
- `kubectl describe pod` shows "0/N nodes are available"

### Diagnosis

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 Events

# Check node resource availability
kubectl describe nodes | grep -A 5 "Allocated resources"

# Show node capacity vs allocatable
kubectl get nodes -o custom-columns='NAME:.metadata.name,CPU_CAP:.status.capacity.cpu,CPU_ALLOC:.status.allocatable.cpu,MEM_CAP:.status.capacity.memory,MEM_ALLOC:.status.allocatable.memory'

# Check current resource usage
kubectl top nodes
```

### Resolution

1. **Reduce resource requests**: If the pod requests more than any single node can provide, lower the requests.
   ```yaml
   resources:
     requests:
       cpu: "250m"    # Lowered from 1000m
       memory: "256Mi" # Lowered from 1Gi
   ```

2. **Scale up the cluster**: Add more worker nodes to provide additional capacity.

3. **Evict low-priority pods**: Use PriorityClasses to allow critical pods to preempt less important ones.
   ```yaml
   priorityClassName: high-priority
   ```

4. **Clean up completed/failed jobs**: Remove old pods that still consume resource reservations.
   ```bash
   kubectl delete pods --field-selector=status.phase=Succeeded -A
   kubectl delete pods --field-selector=status.phase=Failed -A
   ```

---

## Unschedulable Nodes

### Symptoms
- Pods pending even though nodes have resources
- Node shows `SchedulingDisabled` status
- Events mention "node is unschedulable"

### Diagnosis

```bash
# Check node status
kubectl get nodes

# Check if node is cordoned
kubectl describe node <node-name> | grep -i unschedulable

# Check taints on the node
kubectl describe node <node-name> | grep -A 5 Taints
```

### Resolution

1. **Uncordon the node**: If the node was cordoned for maintenance.
   ```bash
   kubectl uncordon <node-name>
   ```

2. **Remove unwanted taints**: If a taint was applied accidentally.
   ```bash
   kubectl taint nodes <node-name> <taint-key>-
   ```

3. **Check kubelet status**: The node may be NotReady due to kubelet issues.
   ```bash
   # On the node:
   sudo systemctl status kubelet
   sudo journalctl -u kubelet --since "10 minutes ago"
   ```

---

## Taint and Toleration Issues

### Symptoms
- Pods not scheduled on specific nodes despite available resources
- Only certain pods can run on tainted nodes
- Control plane nodes not accepting workloads (by design)

### Diagnosis

```bash
# List all taints on all nodes
kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].key'

# Check specific node taints
kubectl describe node <node-name> | grep -A 10 Taints

# Check pod tolerations
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.tolerations}' | python3 -m json.tool
```

### Resolution

1. **Add tolerations to pods** that need to run on tainted nodes:
   ```yaml
   tolerations:
   - key: "node-role.kubernetes.io/control-plane"
     operator: "Exists"
     effect: "NoSchedule"
   ```

2. **Remove taints** from nodes if no longer needed:
   ```bash
   # Remove a specific taint
   kubectl taint nodes <node-name> key=value:NoSchedule-

   # Remove control-plane taint (to allow workloads on master)
   kubectl taint nodes <node-name> node-role.kubernetes.io/control-plane:NoSchedule-
   ```

3. **Use NoExecute tolerations** with `tolerationSeconds` for temporary workloads:
   ```yaml
   tolerations:
   - key: "node.kubernetes.io/not-ready"
     operator: "Exists"
     effect: "NoExecute"
     tolerationSeconds: 300
   ```

---

## Affinity and Anti-Affinity Problems

### Symptoms
- Pods stuck in Pending with affinity-related scheduling messages
- Pods not distributing across nodes as expected
- `requiredDuringSchedulingIgnoredDuringExecution` rules preventing placement

### Diagnosis

```bash
# Check pod affinity rules
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 30 affinity

# Check node labels
kubectl get nodes --show-labels

# Check pod labels across nodes
kubectl get pods -n <namespace> -o wide
```

### Resolution

1. **Switch from required to preferred affinity**: Use `preferredDuringSchedulingIgnoredDuringExecution` instead of `requiredDuringSchedulingIgnoredDuringExecution` when strict placement is not critical.

2. **Add missing node labels**: If nodeAffinity references a label that does not exist.
   ```bash
   kubectl label nodes <node-name> disktype=ssd
   ```

3. **Relax anti-affinity rules**: Use `topologyKey: kubernetes.io/hostname` for per-node distribution instead of overly restrictive rules.

4. **Check topology spread constraints**: These can also cause scheduling failures if not enough topology domains exist.
   ```yaml
   topologySpreadConstraints:
   - maxSkew: 1
     topologyKey: kubernetes.io/hostname
     whenUnsatisfiable: ScheduleAnyway  # vs DoNotSchedule
     labelSelector:
       matchLabels:
         app: my-app
   ```

---

## PVC Binding Waiting

### Symptoms
- Pod pending with event: "persistently claim is not bound"
- PVC stuck in `Pending` state
- Pod cannot start because its volume is not ready

### Diagnosis

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# Check PVC events
kubectl describe pvc <pvc-name> -n <namespace>

# Check available PVs
kubectl get pv

# Check storage class
kubectl get storageclass
```

### Resolution

1. **Storage class does not exist**: Create the required StorageClass or change the PVC to use an existing one.
   ```bash
   kubectl get storageclass
   ```

2. **No matching PV**: For static provisioning, create a PV that matches the PVC's size, access mode, and storage class.

3. **Storage provisioner not running**: Check that the CSI driver or storage provisioner pods are healthy.
   ```bash
   kubectl get pods -A | grep -i csi
   kubectl get pods -A | grep -i provisioner
   ```

4. **Volume binding mode `WaitForFirstConsumer`**: The PVC will not bind until a pod using it is scheduled. This is by design to ensure the volume is created in the correct topology zone.

5. **Capacity exhausted**: The underlying storage system may be out of space. Check the storage backend directly.

See also: [Storage Issues](storage-issues.md) for more PVC troubleshooting.
