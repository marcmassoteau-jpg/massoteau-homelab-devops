# Security Audit Checklist

A detailed security checklist for Kubernetes homelab clusters with explanations and remediation steps for each finding.

**Automated assessment:** Run `scripts/assessment/security-audit.sh` for automated checks.

---

## 1. RBAC Configuration

### 1.1 Custom ClusterRoles

**What to check:** Verify custom ClusterRoles exist beyond the default system roles (admin, edit, view, cluster-admin).

**Why it matters:** Relying solely on default roles often means over-permissioning users and service accounts.

**How to verify:**
```bash
kubectl get clusterroles | grep -v -E '^system:|^admin$|^edit$|^view$|^cluster-admin$'
```

**Remediation:**
- Create purpose-specific ClusterRoles with minimum required permissions
- Use Roles (namespace-scoped) instead of ClusterRoles when possible
- Follow the principle of least privilege

### 1.2 Cluster-Admin Bindings

**What to check:** Ensure cluster-admin role is not bound to non-system accounts.

**Why it matters:** Cluster-admin grants unrestricted access to all resources in the cluster.

**How to verify:**
```bash
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[]'
```

**Remediation:**
- Remove unnecessary cluster-admin bindings
- Create scoped roles that grant only required permissions
- Use cluster-admin only for emergency break-glass access

### 1.3 Namespace-Level RoleBindings

**What to check:** All user namespaces should have RoleBindings defining who can access them.

**Why it matters:** Without RoleBindings, access control relies on cluster-level permissions which are too broad.

**How to verify:**
```bash
for ns in $(kubectl get ns --no-headers | awk '{print $1}'); do
  count=$(kubectl get rolebindings -n "$ns" --no-headers 2>/dev/null | wc -l)
  echo "$ns: $count rolebindings"
done
```

**Remediation:**
- Create RoleBindings in each namespace for the teams that need access
- Bind to custom Roles, not cluster-admin

---

## 2. Pod Security Standards

### 2.1 Pod Security Admission Labels

**What to check:** Namespaces should have Pod Security Admission labels that enforce security standards.

**Why it matters:** Pod Security Standards prevent containers from running with dangerous capabilities.

**How to verify:**
```bash
kubectl get namespaces -o json | jq '.items[] | {name: .metadata.name, enforce: .metadata.labels["pod-security.kubernetes.io/enforce"]}'
```

**Remediation:**
```bash
# Apply baseline enforcement to a namespace
kubectl label namespace <ns> pod-security.kubernetes.io/enforce=baseline
kubectl label namespace <ns> pod-security.kubernetes.io/warn=restricted
```

Levels:
- `privileged` - No restrictions (not recommended)
- `baseline` - Prevents known privilege escalations
- `restricted` - Heavily restricted, follows security best practices

### 2.2 Deprecated PodSecurityPolicies

**What to check:** No PodSecurityPolicies should exist (deprecated since K8s 1.25).

**Why it matters:** PSPs are removed and no longer enforced; relying on them creates a false sense of security.

**How to verify:**
```bash
kubectl get podsecuritypolicies 2>/dev/null
```

**Remediation:**
- Migrate to Pod Security Admission or a policy engine (OPA Gatekeeper, Kyverno)
- Remove all PodSecurityPolicy resources

---

## 3. Privileged Containers

### 3.1 Privileged Flag

**What to check:** No containers should run with `securityContext.privileged: true` unless absolutely required.

**Why it matters:** Privileged containers have full access to the host, effectively bypassing all container isolation.

**How to verify:**
```bash
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | "\(.metadata.namespace)/\(.metadata.name)"'
```

**Remediation:**
- Remove the privileged flag from container specs
- Use specific Linux capabilities instead of full privilege
- Exceptions: CNI plugins, storage drivers may legitimately need privilege

### 3.2 Running as Root

**What to check:** Containers should not run as UID 0.

**Why it matters:** If a container is compromised, running as root increases the blast radius.

**How to verify:**
```bash
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].securityContext.runAsUser == 0 or .spec.containers[].securityContext.runAsNonRoot == false) | "\(.metadata.namespace)/\(.metadata.name)"'
```

**Remediation:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
```

### 3.3 Linux Capabilities

**What to check:** Containers should drop all capabilities and add only those specifically needed.

**How to verify:**
```bash
kubectl get pods -A -o json | jq '.items[].spec.containers[].securityContext.capabilities'
```

**Remediation:**
```yaml
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE  # only if needed
```

---

## 4. Network Policies

### 4.1 NetworkPolicy Per Namespace

**What to check:** Every user namespace should have at least one NetworkPolicy.

**Why it matters:** Without NetworkPolicies, all pods can communicate with all other pods across namespaces.

**How to verify:**
```bash
for ns in $(kubectl get ns --no-headers | grep -v kube- | awk '{print $1}'); do
  count=$(kubectl get networkpolicies -n "$ns" --no-headers 2>/dev/null | wc -l)
  echo "$ns: $count policies"
done
```

**Remediation:**
```yaml
# Default deny ingress for a namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

### 4.2 Default-Deny Policies

**What to check:** A default-deny policy should exist in each namespace, with explicit allow rules for required traffic.

**Why it matters:** Default-deny ensures only explicitly allowed traffic flows, reducing attack surface.

**Remediation:** Apply a default-deny policy, then create specific allow policies for each service.

---

## 5. Secrets Management

### 5.1 Secrets as Environment Variables

**What to check:** Secrets should be mounted as volumes, not exposed as environment variables.

**Why it matters:** Environment variables appear in process listings, crash dumps, and container logs. Volume-mounted secrets are more secure and can be updated without pod restart.

**How to verify:**
```bash
kubectl get pods -A -o json | jq -r '.items[] | .spec.containers[] | select(.env[]?.valueFrom.secretKeyRef != null) | .name'
```

**Remediation:**
```yaml
# Instead of:
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: password

# Use volume mount:
volumes:
  - name: db-secret
    secret:
      secretName: db-secret
containers:
  - volumeMounts:
      - name: db-secret
        mountPath: /etc/secrets/db
        readOnly: true
```

### 5.2 Secret Encryption at Rest

**What to check:** Kubernetes secrets should be encrypted at rest in etcd.

**How to verify:**
```bash
# Check the API server encryption configuration
kubectl -n kube-system get pod kube-apiserver-* -o yaml | grep encryption-provider-config
```

**Remediation:** Configure EncryptionConfiguration for the API server.

---

## 6. Service Account Security

### 6.1 Default Service Account Usage

**What to check:** Pods should use dedicated service accounts, not the default.

**Why it matters:** The default service account may have permissions that are too broad for the workload.

**How to verify:**
```bash
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.serviceAccountName == "default" and .metadata.namespace != "kube-system") | "\(.metadata.namespace)/\(.metadata.name)"'
```

**Remediation:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
automountServiceAccountToken: false
```

### 6.2 Automount Token Disabled

**What to check:** Default service accounts should have `automountServiceAccountToken: false`.

**Why it matters:** Prevents automatic mounting of API credentials into pods that do not need them.

**How to verify:**
```bash
kubectl get sa default -n <namespace> -o yaml | grep automountServiceAccountToken
```

**Remediation:**
```bash
kubectl patch serviceaccount default -n <namespace> -p '{"automountServiceAccountToken": false}'
```

---

## 7. CIS Benchmark

### Running kube-bench

**What it is:** kube-bench runs the CIS Kubernetes Benchmark checks against your cluster.

**How to run:**
```bash
# If installed locally
kube-bench run --targets node

# As a Kubernetes job
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench
```

**Key areas checked:**
- Control plane configuration
- etcd security
- Control plane security
- Worker node security
- Kubernetes policies

**Remediation:** Address each FAIL finding according to the CIS benchmark recommendation output by kube-bench.

---

## Priority Matrix

| Priority | Category | Impact |
|----------|----------|--------|
| Critical | Privileged containers, cluster-admin bindings | Full cluster compromise |
| High | Missing RBAC, no NetworkPolicies, secrets as env vars | Lateral movement, data exposure |
| Medium | No PSA enforcement, default SA usage, root containers | Privilege escalation |
| Low | Missing CIS benchmark, audit logging gaps | Compliance, forensics |
