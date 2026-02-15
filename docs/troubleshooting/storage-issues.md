# Storage Troubleshooting Guide

Common Kubernetes storage problems including PersistentVolume/PersistentVolumeClaim failures, StorageClass misconfigurations, disk pressure, and volume mount errors in a homelab environment.

## PV/PVC Binding Failures

### Symptoms
- PVC stays in `Pending` state indefinitely
- Pod events show "persistentvolumeclaim is not bound"
- `kubectl get pvc` shows no bound volumes
- Deployments fail to start due to unbound claims

### Diagnosis

```bash
# Check PVC status and events
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>

# Check available PVs and their status
kubectl get pv -o wide

# Compare PVC requirements with PV specs
kubectl get pv -o custom-columns='NAME:.metadata.name,CAPACITY:.spec.capacity.storage,ACCESS:.spec.accessModes[*],RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase,CLAIM:.spec.claimRef.name,STORAGECLASS:.spec.storageClassName'

# Check if the StorageClass exists
kubectl get storageclass

# Check provisioner pods
kubectl get pods -A | grep -i provisioner
kubectl get pods -A | grep -i csi
```

### Resolution

1. **StorageClass mismatch**: The PVC requests a StorageClass that does not exist or does not match any PV.
   ```bash
   # List available StorageClasses
   kubectl get storageclass

   # Patch PVC to use the correct StorageClass (requires recreation)
   kubectl delete pvc <pvc-name> -n <namespace>
   # Recreate with the correct storageClassName
   ```

2. **Capacity mismatch**: The PVC requests more storage than any available PV provides.
   ```bash
   # Check PV capacities
   kubectl get pv --sort-by=.spec.capacity.storage

   # Create a PV with sufficient capacity for static provisioning
   cat <<EOF | kubectl apply -f -
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: pv-data-01
   spec:
     capacity:
       storage: 50Gi
     accessModes:
       - ReadWriteOnce
     persistentVolumeReclaimPolicy: Retain
     storageClassName: local-storage
     hostPath:
       path: /mnt/data/pv-data-01
   EOF
   ```

3. **Access mode mismatch**: PVC requests `ReadWriteMany` but PV only supports `ReadWriteOnce`.
   ```bash
   # Check PV access modes
   kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.accessModes[*]}{"\n"}{end}'
   ```

4. **PV stuck in Released state**: A previously bound PV cannot be reused without clearing its claimRef.
   ```bash
   # Check for Released PVs
   kubectl get pv | grep Released

   # Clear the claimRef to make it Available again
   kubectl patch pv <pv-name> --type json -p '[{"op": "remove", "path": "/spec/claimRef"}]'
   ```

### Prevention
- Use a consistent naming convention for StorageClasses across all namespaces
- Document PV capacity requirements for each service (e.g., GitLab requires 115Gi total)
- Monitor PV usage with `kubectl get pv` as part of regular cluster checks
- Use `WaitForFirstConsumer` volume binding mode for topology-aware provisioning

---

## StorageClass Misconfiguration

### Symptoms
- Dynamic provisioning does not create PVs automatically
- PVCs stay Pending with "no persistent volumes available" message
- Wrong reclaim policy causes data loss or orphaned volumes
- Default StorageClass not being selected

### Diagnosis

```bash
# List all StorageClasses with details
kubectl get storageclass -o wide

# Check which StorageClass is the default
kubectl get storageclass -o custom-columns='NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,BINDING:.volumeBindingMode,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class'

# Check if the provisioner is available
kubectl get pods -A -l app=nfs-subdir-external-provisioner

# Check StorageClass events
kubectl describe storageclass <storageclass-name>
```

### Resolution

1. **No default StorageClass**: Set a default StorageClass for PVCs that do not specify one.
   ```bash
   # Mark a StorageClass as default
   kubectl patch storageclass <name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
   ```

2. **Provisioner not installed**: Install the required storage provisioner.
   ```bash
   # Example: Install local-path-provisioner for homelab
   kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

   # Verify it is running
   kubectl get pods -n local-path-storage
   ```

3. **Wrong reclaim policy**: Change reclaimPolicy to avoid accidental data deletion.
   ```bash
   # PVs created by the StorageClass inherit its reclaimPolicy
   # Patch existing PVs to Retain
   kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
   ```

4. **Multiple default StorageClasses**: Only one should be default.
   ```bash
   # Remove default annotation from the wrong one
   kubectl patch storageclass <wrong-name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
   ```

### Prevention
- Always set exactly one default StorageClass in the cluster
- Use `Retain` reclaim policy for critical data (GitLab, databases)
- Document which StorageClass each application should use
- Include StorageClass validation in deployment pipelines

---

## Disk Pressure and Capacity Issues

### Symptoms
- Node enters `DiskPressure` condition
- Pods evicted with reason "The node was low on resource: ephemeral-storage"
- `kubectl describe node` shows DiskPressure taint
- Image pulls fail with "no space left on device"
- Container logs fill up disk space

### Diagnosis

```bash
# Check node conditions for disk pressure
kubectl get nodes -o custom-columns='NAME:.metadata.name,DISK_PRESSURE:.status.conditions[?(@.type=="DiskPressure")].status'

# Check disk usage on the node (SSH required)
ssh ubuntu@192.168.1.241 "df -h / /var/lib/kubelet /var/lib/containerd"

# Check which pods use the most ephemeral storage
kubectl get pods -A -o json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for pod in data['items']:
    name = pod['metadata']['name']
    ns = pod['metadata']['namespace']
    for c in pod.get('spec',{}).get('containers',[]):
        req = c.get('resources',{}).get('requests',{}).get('ephemeral-storage','<none>')
        print(f'{ns}/{name}: {req}')
"

# Check container image cache size
ssh ubuntu@192.168.1.241 "sudo crictl images | tail -1"

# Check kubelet garbage collection thresholds
ssh ubuntu@192.168.1.241 "sudo cat /var/lib/kubelet/config.yaml | grep -A 5 eviction"
```

### Resolution

1. **Clean up unused container images**: Remove images that are no longer referenced.
   ```bash
   # On the affected node
   ssh ubuntu@192.168.1.241 "sudo crictl rmi --prune"
   ```

2. **Clean up old pods and containers**: Remove stopped containers and their logs.
   ```bash
   # On the affected node
   ssh ubuntu@192.168.1.241 "sudo crictl rm $(sudo crictl ps -a --state exited -q)"
   ```

3. **Clean up completed and failed pods**: Remove cluster-wide clutter.
   ```bash
   kubectl delete pods --field-selector=status.phase=Succeeded -A
   kubectl delete pods --field-selector=status.phase=Failed -A
   ```

4. **Expand disk capacity**: For Proxmox-based homelab VMs, increase disk size.
   ```bash
   # On Proxmox host - increase disk
   qm resize <vmid> scsi0 +20G

   # On the VM - extend partition and filesystem
   ssh ubuntu@192.168.1.241 "sudo growpart /dev/sda 2 && sudo resize2fs /dev/sda2"
   ```

5. **Configure kubelet eviction thresholds**: Adjust thresholds to trigger cleanup earlier.
   ```bash
   # Edit kubelet config on the node
   ssh ubuntu@192.168.1.241 "sudo vi /var/lib/kubelet/config.yaml"
   # Set evictionHard:
   #   nodefs.available: "15%"
   #   imagefs.available: "15%"
   ssh ubuntu@192.168.1.241 "sudo systemctl restart kubelet"
   ```

### Prevention
- Set ephemeral storage limits on pods to prevent runaway log growth
- Configure log rotation for container runtime (`/etc/containerd/config.toml`)
- Monitor disk usage with Prometheus node exporter alerts at 80% threshold
- Schedule regular image garbage collection via cron or kubelet configuration
- Allocate sufficient disk space during VM provisioning (minimum 50Gi for workers)

---

## Volume Mount Errors

### Symptoms
- Pod stuck in `ContainerCreating` with "MountVolume.SetUp failed"
- Events show "unable to attach or mount volumes"
- "permission denied" when container writes to mounted volume
- "read-only file system" errors in application logs

### Diagnosis

```bash
# Check pod events for mount errors
kubectl describe pod <pod-name> -n <namespace> | grep -A 15 Events

# Check if the volume exists and is accessible
kubectl get pv <pv-name> -o yaml

# Check node-level mount status (SSH required)
ssh ubuntu@192.168.1.241 "mount | grep kubelet"
ssh ubuntu@192.168.1.241 "ls -la /var/lib/kubelet/pods/"

# Check if the hostPath directory exists on the node
ssh ubuntu@192.168.1.241 "ls -la /mnt/data/<volume-path>"

# Check for SELinux or AppArmor blocking mounts
ssh ubuntu@192.168.1.241 "sudo dmesg | grep -i denied | tail -20"
```

### Resolution

1. **hostPath directory does not exist**: Create it on the correct node.
   ```bash
   ssh ubuntu@192.168.1.241 "sudo mkdir -p /mnt/data/<volume-path>"
   ssh ubuntu@192.168.1.241 "sudo chmod 755 /mnt/data/<volume-path>"
   ```

2. **Permission issues**: Set correct ownership for the volume directory.
   ```bash
   # Check what UID/GID the container runs as
   kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].securityContext}'

   # Set ownership on the node
   ssh ubuntu@192.168.1.241 "sudo chown -R 1000:1000 /mnt/data/<volume-path>"
   ```

3. **Use initContainer to fix permissions**: Avoid SSH by fixing permissions at pod startup.
   ```yaml
   initContainers:
   - name: fix-permissions
     image: busybox:1.36
     command: ["sh", "-c", "chown -R 1000:1000 /data"]
     volumeMounts:
     - name: data
       mountPath: /data
     securityContext:
       runAsUser: 0
   ```

4. **Volume stuck in terminating state**: Force detach a volume that is stuck.
   ```bash
   # Check volumeattachments
   kubectl get volumeattachments

   # Delete stuck attachment
   kubectl delete volumeattachment <attachment-name>
   ```

5. **Subpath mount failures**: Verify the subPath exists within the volume.
   ```bash
   # Check if subPath exists
   kubectl exec <pod-name> -n <namespace> -- ls -la /path/to/volume/
   ```

### Prevention
- Use initContainers to set volume permissions consistently
- Document required directory structures for each service
- Use `fsGroup` in the pod securityContext for automatic group ownership
- Test volume mounts in a dev overlay before deploying to production

---

## NFS Volume Issues

### Symptoms
- Pods hang during startup waiting for NFS mount
- "mount.nfs: Connection timed out" errors
- Stale NFS handle errors causing application failures
- Slow read/write performance on NFS-backed volumes

### Diagnosis

```bash
# Check NFS mount errors in pod events
kubectl describe pod <pod-name> -n <namespace> | grep -i nfs

# Test NFS connectivity from the node
ssh ubuntu@192.168.1.241 "showmount -e 192.168.1.50"

# Check NFS mount on the node
ssh ubuntu@192.168.1.241 "mount | grep nfs"

# Test NFS port connectivity
ssh ubuntu@192.168.1.241 "nc -zv 192.168.1.50 2049"

# Check NFS server exports
ssh ubuntu@192.168.1.50 "cat /etc/exports"
ssh ubuntu@192.168.1.50 "exportfs -v"
```

### Resolution

1. **NFS server unreachable**: Verify network connectivity and NFS service status.
   ```bash
   # On the NFS server
   ssh ubuntu@192.168.1.50 "sudo systemctl status nfs-server"
   ssh ubuntu@192.168.1.50 "sudo systemctl restart nfs-server"
   ```

2. **Firewall blocking NFS**: Ensure NFS ports are open (TCP/UDP 2049, 111).
   ```bash
   # On the NFS server
   ssh ubuntu@192.168.1.50 "sudo ufw allow from 192.168.1.0/24 to any port 2049"
   ssh ubuntu@192.168.1.50 "sudo ufw allow from 192.168.1.0/24 to any port 111"
   ```

3. **Stale NFS handles**: Remount the NFS volume.
   ```bash
   # On the affected node
   ssh ubuntu@192.168.1.241 "sudo umount -f /mnt/nfs-share && sudo mount -a"
   ```

4. **NFS client not installed**: Install nfs-common on worker nodes.
   ```bash
   # On the affected node
   ssh ubuntu@192.168.1.241 "sudo apt-get install -y nfs-common"
   ```

5. **Export permissions**: Ensure the NFS export allows the Kubernetes node IPs.
   ```bash
   # On the NFS server, add to /etc/exports:
   # /mnt/nfs-share 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
   ssh ubuntu@192.168.1.50 "sudo exportfs -ra"
   ```

### Prevention
- Include `nfs-common` installation in Ansible node provisioning playbooks
- Monitor NFS server health and disk space
- Use `soft` mount option with `timeo` to prevent pod hangs on NFS failures
- Consider local-path-provisioner as an alternative for non-shared storage needs
