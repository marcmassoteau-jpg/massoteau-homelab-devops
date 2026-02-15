# Common Kubernetes Errors Guide

Practical troubleshooting reference for the most frequently encountered Kubernetes error states, with diagnosis steps and resolutions for homelab environments.

## ImagePullBackOff

### Symptoms
- Pod stuck in `ImagePullBackOff` or `ErrImagePull` state
- Events show "Failed to pull image" or "repository does not exist"
- Image tag not found errors
- Authentication failures for private registries

### Diagnosis

```bash
# Check pod status and events
kubectl describe pod <pod-name> -n <namespace> | grep -A 15 Events

# Check the exact image reference
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].image}'

# Check if imagePullSecrets are configured
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.imagePullSecrets}'

# Test image pull manually on the node
ssh ubuntu@192.168.1.241 "sudo crictl pull <image-name>"

# Check registry connectivity from the node
ssh ubuntu@192.168.1.241 "curl -v https://registry.gitlab.homelab.local/v2/"

# Check existing image pull secrets
kubectl get secrets -n <namespace> | grep docker
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
```

### Resolution

1. **Image tag does not exist**: Verify the image name and tag are correct.
   ```bash
   # Check available tags for Docker Hub images
   curl -s "https://registry.hub.docker.com/v2/repositories/library/<image>/tags?page_size=10" | \
     python3 -m json.tool | grep name

   # For GitLab registry, list tags
   curl -s --header "PRIVATE-TOKEN: <token>" \
     "https://gitlab.homelab.local/api/v4/projects/<id>/registry/repositories/<repo-id>/tags"
   ```

2. **Private registry authentication**: Create or update the image pull secret.
   ```bash
   # Create a docker-registry secret
   kubectl create secret docker-registry registry-creds \
     -n <namespace> \
     --docker-server=registry.gitlab.homelab.local \
     --docker-username=deploy-token \
     --docker-password=<token>

   # Patch the default service account to use the secret
   kubectl patch serviceaccount default -n <namespace> \
     -p '{"imagePullSecrets": [{"name": "registry-creds"}]}'
   ```

3. **DNS resolution failure**: The node cannot resolve the registry hostname.
   ```bash
   # Check DNS resolution on the node
   ssh ubuntu@192.168.1.241 "nslookup registry.gitlab.homelab.local"

   # Add to /etc/hosts if DNS is not configured
   ssh ubuntu@192.168.1.241 "echo '192.168.1.240 registry.gitlab.homelab.local' | sudo tee -a /etc/hosts"
   ```

4. **Self-signed certificate not trusted**: For homelab registries using self-signed certs.
   ```bash
   # Add the CA certificate to containerd's trust store
   ssh ubuntu@192.168.1.241 "sudo mkdir -p /etc/containerd/certs.d/registry.gitlab.homelab.local"
   ssh ubuntu@192.168.1.241 "sudo cp ca.crt /etc/containerd/certs.d/registry.gitlab.homelab.local/"
   ssh ubuntu@192.168.1.241 "sudo systemctl restart containerd"
   ```

5. **Rate limiting**: Docker Hub limits pulls for anonymous users.
   ```bash
   # Check rate limit status
   curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/nginx:pull" | \
     python3 -c "import json,sys; print(json.load(sys.stdin)['token'])" | \
     xargs -I {} curl -sI -H "Authorization: Bearer {}" \
     "https://registry-1.docker.io/v2/library/nginx/manifests/latest" | grep ratelimit
   ```

### Prevention
- Use a local registry mirror to avoid external dependency and rate limits
- Store image pull secrets in a sealed-secret or external secret manager
- Pin image tags to specific versions instead of `latest`
- Pre-pull critical images on all nodes during provisioning with Ansible

---

## CrashLoopBackOff

### Symptoms
- Pod restarts repeatedly with increasing back-off delay
- `kubectl get pods` shows high restart count
- Container exits immediately after starting
- Application fails health checks on startup

### Diagnosis

```bash
# Check pod status and restart count
kubectl get pod <pod-name> -n <namespace>

# Check the exit code and reason
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Last State"

# Check container logs (current attempt)
kubectl logs <pod-name> -n <namespace>

# Check logs from the previous crash
kubectl logs <pod-name> -n <namespace> --previous

# Check if the container command is correct
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].command}'
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].args}'

# Check environment variables
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].env}' | python3 -m json.tool

# Check liveness probe configuration
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].livenessProbe}' | python3 -m json.tool
```

### Resolution

1. **Application configuration error**: Fix the configuration causing the crash.
   ```bash
   # Check ConfigMaps referenced by the pod
   kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].envFrom}' | python3 -m json.tool

   # View the ConfigMap contents
   kubectl get configmap <configmap-name> -n <namespace> -o yaml
   ```

2. **Missing dependencies**: The application cannot connect to a required service.
   ```bash
   # Check if dependent services are running
   kubectl get svc -n <namespace>
   kubectl get endpoints -n <namespace>
   ```
   Add an init container to wait for dependencies:
   ```yaml
   initContainers:
   - name: wait-for-db
     image: busybox:1.36
     command: ['sh', '-c', 'until nc -z postgres-svc 5432; do echo waiting for db; sleep 2; done']
   ```

3. **Liveness probe too aggressive**: The probe fails before the application is ready.
   ```yaml
   livenessProbe:
     httpGet:
       path: /healthz
       port: 8080
     initialDelaySeconds: 60    # Increased from 10
     periodSeconds: 10
     failureThreshold: 5        # Increased from 3
   startupProbe:
     httpGet:
       path: /healthz
       port: 8080
     failureThreshold: 30
     periodSeconds: 10
   ```

4. **Insufficient resources**: The container is being OOM-killed silently.
   ```bash
   # Check the exit code (137 = OOMKilled)
   kubectl describe pod <pod-name> -n <namespace> | grep "Exit Code"

   # Increase memory limit
   kubectl set resources deployment <deployment-name> -n <namespace> \
     --limits=memory=1Gi --requests=memory=512Mi
   ```

5. **Wrong command or entrypoint**: The container exits because the command is invalid.
   ```bash
   # Debug by overriding the command
   kubectl run debug-pod --image=<image> --rm -it --restart=Never -- /bin/sh
   ```

### Prevention
- Always check logs from the previous crash (`--previous`) for root cause
- Use startup probes for applications with slow initialization
- Set appropriate resource requests and limits
- Test container images locally before deploying to the cluster

---

## OOMKilled

### Symptoms
- Container terminated with exit code 137
- `kubectl describe pod` shows reason: OOMKilled
- Application crashes under load or during memory-intensive operations
- Pod restarts without clear application-level errors

### Diagnosis

```bash
# Confirm OOMKilled status
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Last State"

# Check current memory limits
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].resources.limits.memory}'

# Check actual memory usage before the kill
kubectl top pod <pod-name> -n <namespace>

# Check node-level OOM events
ssh ubuntu@192.168.1.241 "sudo dmesg | grep -i 'oom\|out of memory' | tail -20"

# Check memory usage patterns across the namespace
kubectl top pods -n <namespace> --sort-by=memory

# Check if the pod has memory requests set
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].resources}'
```

### Resolution

1. **Increase memory limits**: The most common fix when the application legitimately needs more memory.
   ```yaml
   resources:
     requests:
       memory: "512Mi"
     limits:
       memory: "2Gi"   # Increased from 1Gi
   ```

2. **Fix memory leaks**: If memory usage grows unbounded over time.
   ```bash
   # Monitor memory usage over time
   watch -n 10 "kubectl top pod <pod-name> -n <namespace>"

   # Check application-specific memory metrics
   kubectl port-forward <pod-name> -n <namespace> 8080:8080
   # Then check /metrics or /debug/pprof endpoints
   ```

3. **Set JVM heap size for Java applications**: JVM defaults may exceed the container limit.
   ```yaml
   env:
   - name: JAVA_OPTS
     value: "-Xmx768m -Xms256m"
   # Or use container-aware JVM flags
   - name: JAVA_OPTS
     value: "-XX:MaxRAMPercentage=75.0"
   ```

4. **Use VPA (Vertical Pod Autoscaler)**: Automatically adjust resource limits based on usage.
   ```bash
   # Check if VPA is available
   kubectl get vpa -A
   ```

### Prevention
- Set memory limits to at least 1.5x the application's steady-state usage
- For JVM apps, always explicitly set heap size relative to the container limit
- Monitor memory usage trends and adjust limits proactively
- Load test applications to determine peak memory requirements

---

## Evicted Pods

### Symptoms
- Pods in `Evicted` status with reason "The node was low on resource"
- Multiple pods evicted simultaneously from the same node
- Events mention `ephemeral-storage`, `memory`, or `nodefs` pressure
- Node conditions show DiskPressure or MemoryPressure

### Diagnosis

```bash
# List evicted pods
kubectl get pods -A --field-selector=status.phase=Failed | grep Evicted

# Check eviction reason
kubectl describe pod <evicted-pod-name> -n <namespace> | grep -A 5 "Status\|Reason\|Message"

# Check node conditions that triggered eviction
kubectl describe node <node-name> | grep -A 20 Conditions

# Check kubelet eviction thresholds
ssh ubuntu@192.168.1.241 "sudo cat /var/lib/kubelet/config.yaml | grep -A 10 eviction"

# Check current resource usage on the node
kubectl top node <node-name>
ssh ubuntu@192.168.1.241 "df -h"
ssh ubuntu@192.168.1.241 "free -h"
```

### Resolution

1. **Clean up evicted pods**: They remain as Failed pods consuming metadata space.
   ```bash
   # Delete all evicted pods cluster-wide
   kubectl get pods -A --field-selector=status.phase=Failed -o json | \
     python3 -c "
   import json, sys
   data = json.load(sys.stdin)
   for pod in data['items']:
       if pod.get('status',{}).get('reason') == 'Evicted':
           name = pod['metadata']['name']
           ns = pod['metadata']['namespace']
           print(f'kubectl delete pod {name} -n {ns}')
   " | sh
   ```

2. **Resolve disk pressure**: Free up disk space on the affected node.
   ```bash
   # Clean up unused images
   ssh ubuntu@192.168.1.241 "sudo crictl rmi --prune"

   # Clean up old container logs
   ssh ubuntu@192.168.1.241 "sudo find /var/log/containers -name '*.log' -mtime +7 -delete"

   # Clean up old journal logs
   ssh ubuntu@192.168.1.241 "sudo journalctl --vacuum-size=500M"
   ```

3. **Resolve memory pressure**: Free up memory on the affected node.
   ```bash
   # Scale down non-critical workloads
   kubectl scale deployment <low-priority-app> -n <namespace> --replicas=0

   # Check for pods without memory limits
   kubectl get pods -A -o json | python3 -c "
   import json, sys
   data = json.load(sys.stdin)
   for pod in data['items']:
       for c in pod.get('spec',{}).get('containers',[]):
           if not c.get('resources',{}).get('limits',{}).get('memory'):
               print(f\"{pod['metadata']['namespace']}/{pod['metadata']['name']}/{c['name']}: NO MEMORY LIMIT\")"
   ```

4. **Set pod priority**: Ensure critical pods are evicted last.
   ```yaml
   apiVersion: scheduling.k8s.io/v1
   kind: PriorityClass
   metadata:
     name: critical-apps
   value: 1000000
   globalDefault: false
   description: "Priority class for critical applications"
   ---
   # In the pod spec:
   # priorityClassName: critical-apps
   ```

### Prevention
- Always set resource requests and limits on all pods
- Configure kubelet eviction thresholds with soft and hard limits
- Set up PriorityClasses for workload tiering (critical > normal > batch)
- Monitor node resource usage and set alerts at 80% utilization
- Schedule regular cleanup of evicted pods via a CronJob

---

## CreateContainerConfigError

### Symptoms
- Pod stuck in `CreateContainerConfigError` state
- Container never starts
- Events reference missing ConfigMaps, Secrets, or ServiceAccounts
- "couldn't find key" errors in pod events

### Diagnosis

```bash
# Check pod events for the exact error
kubectl describe pod <pod-name> -n <namespace> | grep -A 15 Events

# Check referenced ConfigMaps
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].envFrom[*].configMapRef.name}'
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.volumes[*].configMap.name}'

# Check referenced Secrets
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].envFrom[*].secretRef.name}'
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.volumes[*].secret.secretName}'

# List available ConfigMaps and Secrets in the namespace
kubectl get configmaps -n <namespace>
kubectl get secrets -n <namespace>

# Check if a specific key exists in a ConfigMap
kubectl get configmap <configmap-name> -n <namespace> -o jsonpath='{.data}' | python3 -m json.tool
```

### Resolution

1. **Missing ConfigMap**: Create the required ConfigMap.
   ```bash
   # Check what ConfigMap the pod expects
   kubectl describe pod <pod-name> -n <namespace> | grep -i configmap

   # Create the missing ConfigMap
   kubectl create configmap <configmap-name> -n <namespace> \
     --from-literal=key1=value1 \
     --from-literal=key2=value2
   ```

2. **Missing Secret**: Create the required Secret.
   ```bash
   # Check what Secret the pod expects
   kubectl describe pod <pod-name> -n <namespace> | grep -i secret

   # Create the missing Secret
   kubectl create secret generic <secret-name> -n <namespace> \
     --from-literal=password=<value> \
     --from-literal=username=<value>
   ```

3. **Key not found in ConfigMap/Secret**: The pod references a key that does not exist.
   ```bash
   # Check which key is missing
   kubectl describe pod <pod-name> -n <namespace> | grep "couldn't find key"

   # Add the missing key to the ConfigMap
   kubectl patch configmap <configmap-name> -n <namespace> \
     --type merge -p '{"data":{"missing-key":"value"}}'
   ```

4. **ServiceAccount does not exist**: Create the referenced ServiceAccount.
   ```bash
   # Check which ServiceAccount the pod references
   kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.serviceAccountName}'

   # Create the missing ServiceAccount
   kubectl create serviceaccount <sa-name> -n <namespace>
   ```

5. **Secret type mismatch**: Pod expects a specific secret type (e.g., kubernetes.io/tls).
   ```bash
   # Check secret type
   kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.type}'
   ```

### Prevention
- Use Helm or Kustomize to deploy ConfigMaps and Secrets alongside the application
- Include ConfigMap/Secret creation in ArgoCD Application definitions
- Use `optional: true` for non-critical ConfigMap/Secret references
- Validate manifests with `kubectl apply --dry-run=client` before deploying

---

## FailedScheduling

### Symptoms
- Pod stays in `Pending` state
- Events show "0/N nodes are available" with specific scheduling failure reasons
- No node satisfies all scheduling constraints simultaneously
- Pod affinity or topology constraints cannot be met

### Diagnosis

```bash
# Check the scheduling failure reason
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 Events

# Check node resources
kubectl describe nodes | grep -A 10 "Allocated resources"

# Check node taints
kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].effect'

# Check node labels (for affinity rules)
kubectl get nodes --show-labels

# Check if PVC binding is blocking scheduling
kubectl get pvc -n <namespace>

# Check resource quotas in the namespace
kubectl get resourcequota -n <namespace>
kubectl describe resourcequota -n <namespace>
```

### Resolution

1. **Insufficient resources**: No node has enough CPU or memory.
   ```bash
   # Check what the pod requests
   kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].resources.requests}'

   # Check available resources per node
   kubectl describe nodes | grep -B 5 -A 10 "Allocated resources"

   # Reduce pod resource requests or add cluster capacity
   ```

2. **Node selector mismatch**: Pod requires a label no node has.
   ```bash
   # Check the pod's nodeSelector
   kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.nodeSelector}'

   # Add the required label to a node
   kubectl label nodes <node-name> <label-key>=<label-value>
   ```

3. **All nodes tainted**: Pod does not tolerate the taints on available nodes.
   ```bash
   # Check taints on all nodes
   kubectl describe nodes | grep Taints

   # Add toleration to the pod or remove the taint
   kubectl taint nodes <node-name> <taint-key>-
   ```

4. **ResourceQuota exhausted**: The namespace has reached its resource limit.
   ```bash
   # Check quota usage
   kubectl describe resourcequota -n <namespace>

   # Increase the quota or free resources
   kubectl patch resourcequota <quota-name> -n <namespace> \
     --type merge -p '{"spec":{"hard":{"requests.cpu":"8","requests.memory":"16Gi"}}}'
   ```

5. **PVC not bound**: A volume claim is blocking the pod from scheduling.
   ```bash
   # Check PVC status
   kubectl get pvc -n <namespace>

   # If using WaitForFirstConsumer, this is expected
   # Check StorageClass binding mode
   kubectl get storageclass -o custom-columns='NAME:.metadata.name,BINDING:.volumeBindingMode'
   ```

6. **Pod topology spread constraints too strict**: Relax the constraints.
   ```yaml
   topologySpreadConstraints:
   - maxSkew: 2                          # Increased from 1
     topologyKey: kubernetes.io/hostname
     whenUnsatisfiable: ScheduleAnyway   # Changed from DoNotSchedule
     labelSelector:
       matchLabels:
         app: my-app
   ```

### Prevention
- Monitor cluster resource utilization and plan capacity ahead of deployments
- Use `preferredDuringSchedulingIgnoredDuringExecution` instead of `required` when possible
- Document node labels and taints as part of cluster configuration
- Include scheduling constraint validation in CI/CD pipelines
- See also: [Pod Scheduling Guide](pod-scheduling.md) for detailed scheduling troubleshooting
