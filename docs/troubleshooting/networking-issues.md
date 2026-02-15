# Networking Troubleshooting Guide

Common Kubernetes networking problems, their symptoms, diagnosis steps, and resolution.

## DNS Resolution Failures

### Symptoms
- Pods cannot resolve service names (e.g., `nslookup kubernetes.default` fails)
- Applications fail with "name resolution failed" or "DNS lookup error"
- External domains (e.g., `google.com`) do not resolve from within pods

### Diagnosis

```bash
# Check CoreDNS pods are running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs for errors
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

# Test DNS from a debug pod
kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- nslookup kubernetes.default

# Check CoreDNS ConfigMap
kubectl get configmap coredns -n kube-system -o yaml

# Check if the kube-dns service has endpoints
kubectl get endpoints kube-dns -n kube-system
```

### Resolution

1. **CoreDNS pods not running**: Restart CoreDNS deployment.
   ```bash
   kubectl rollout restart deployment coredns -n kube-system
   ```

2. **CoreDNS pods in CrashLoopBackOff**: Check logs for configuration errors. Common cause is a forwarding loop when the node's `/etc/resolv.conf` points to `127.0.0.1`.
   ```bash
   # Edit CoreDNS ConfigMap to use explicit upstream DNS
   kubectl edit configmap coredns -n kube-system
   # Change "forward . /etc/resolv.conf" to "forward . 8.8.8.8 8.8.4.4"
   ```

3. **Intermittent DNS failures**: Scale up CoreDNS replicas.
   ```bash
   kubectl scale deployment coredns -n kube-system --replicas=3
   ```

4. **External DNS fails but internal works**: Check node DNS configuration and firewall rules allowing UDP port 53 outbound.

---

## Pod-to-Pod Connectivity Issues

### Symptoms
- Pods on different nodes cannot communicate
- `ping` between pod IPs fails across nodes
- Services return connection timeout

### Diagnosis

```bash
# Check CNI plugin pods
kubectl get pods -n kube-system -l k8s-app=calico-node

# Verify pod CIDR allocation
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'

# Test connectivity between pods on different nodes
kubectl run test-a --image=busybox:1.36 --rm -it --restart=Never \
  --overrides='{"spec":{"nodeName":"k8s-worker-1"}}' -- ping -c 3 <pod-b-ip>

# Check Calico node status
kubectl exec -n kube-system <calico-node-pod> -- calico-node -bird-live
```

### Resolution

1. **Calico node pods not running**: Check for resource constraints or image pull issues.
   ```bash
   kubectl describe pod -n kube-system -l k8s-app=calico-node
   ```

2. **IP-in-IP or VXLAN tunnel issues**: Verify encapsulation settings match your network.
   ```bash
   kubectl get ippool -o yaml
   ```

3. **Firewall blocking overlay traffic**: Ensure VXLAN (UDP 4789) or IP-in-IP (protocol 4) traffic is allowed between nodes.

4. **Pod CIDR overlap**: Verify pod CIDR does not overlap with node network or service CIDR.

---

## Service Not Reachable

### Symptoms
- ClusterIP service does not respond
- NodePort service connection refused
- Service returns "no route to host" or "connection refused"

### Diagnosis

```bash
# Check service exists and has correct selector
kubectl get svc <service-name> -n <namespace> -o wide

# Verify endpoints are populated
kubectl get endpoints <service-name> -n <namespace>

# Check if pods match the service selector
kubectl get pods -n <namespace> -l <selector-key>=<selector-value>

# Test from within the cluster
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s -o /dev/null -w "%{http_code}" http://<service-name>.<namespace>.svc.cluster.local

# Check kube-proxy logs
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=50
```

### Resolution

1. **No endpoints**: Verify the service selector matches pod labels exactly.
   ```bash
   # Compare service selector with pod labels
   kubectl get svc <svc> -o jsonpath='{.spec.selector}'
   kubectl get pod <pod> -o jsonpath='{.metadata.labels}'
   ```

2. **Pods not ready**: Endpoints only include pods that pass readiness probes. Check pod readiness.
   ```bash
   kubectl get pods -n <namespace> -o wide
   ```

3. **Port mismatch**: Ensure service `targetPort` matches the container port the application listens on.

4. **kube-proxy issues**: Restart kube-proxy if iptables rules are stale.
   ```bash
   kubectl rollout restart daemonset kube-proxy -n kube-system
   ```

---

## Ingress Not Working

### Symptoms
- External traffic does not reach services through ingress
- HTTP 404 or 503 from the ingress controller
- TLS certificate errors

### Diagnosis

```bash
# Check ingress resource
kubectl get ingress -n <namespace>
kubectl describe ingress <ingress-name> -n <namespace>

# Check Traefik controller pods
kubectl get pods -A -l app.kubernetes.io/name=traefik

# Check Traefik logs
kubectl logs -n <traefik-namespace> -l app.kubernetes.io/name=traefik --tail=100

# Verify backend service is working
kubectl port-forward svc/<backend-svc> -n <namespace> 8080:80
# Then test: curl http://localhost:8080

# Check TLS secret exists and is valid
kubectl get secret <tls-secret> -n <namespace>
```

### Resolution

1. **Ingress controller not running**: Restart the Traefik deployment.
   ```bash
   kubectl rollout restart deployment traefik -n <traefik-namespace>
   ```

2. **Missing IngressClass**: Ensure the ingress specifies the correct `ingressClassName`.
   ```bash
   kubectl get ingressclass
   ```

3. **Backend service 503**: The backend pods are not ready or the service has no endpoints.

4. **TLS errors**: Verify the TLS secret contains valid `tls.crt` and `tls.key`.
   ```bash
   kubectl get secret <tls-secret> -n <namespace> -o jsonpath='{.data.tls\.crt}' | \
     base64 -d | openssl x509 -noout -text | head -20
   ```

5. **Host/path mismatch**: Ensure the ingress rule's host and path match what you are requesting. Check for trailing slashes and path types (`Prefix` vs `Exact`).

---

## Network Policy Blocking Traffic

### Symptoms
- Pods suddenly cannot communicate after applying a NetworkPolicy
- Some pods can reach a service but others cannot
- Intermittent connectivity (some paths blocked)

### Diagnosis

```bash
# List network policies in the namespace
kubectl get networkpolicies -n <namespace>

# Inspect a specific policy
kubectl describe networkpolicy <policy-name> -n <namespace>

# Check if the pod matches any policy's podSelector
kubectl get pod <pod> -n <namespace> --show-labels

# Temporarily test by removing the policy (in dev only)
kubectl delete networkpolicy <policy-name> -n <namespace>
```

### Resolution

1. **Default deny policy blocking all traffic**: Add explicit allow rules for required communication.

2. **Missing egress rules**: If you have egress policies, ensure DNS (UDP 53 to kube-system) is allowed.
   ```yaml
   egress:
   - to:
     - namespaceSelector: {}
       podSelector:
         matchLabels:
           k8s-app: kube-dns
     ports:
     - protocol: UDP
       port: 53
   ```

3. **Label mismatch**: Verify that `namespaceSelector` and `podSelector` labels match the actual resources.
