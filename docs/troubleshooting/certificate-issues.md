# Certificate Troubleshooting Guide

Common certificate-related problems in Kubernetes homelab clusters, including expired certificates, kubeadm cert renewal, TLS errors, Traefik ingress certificates, and webhook failures.

## Expired Kubernetes Certificates

### Symptoms
- `kubectl` commands fail with "x509: certificate has expired or is not yet valid"
- API server becomes unreachable after cluster has been running for ~1 year
- kubelet logs show certificate expiration errors
- etcd cluster communication failures

### Diagnosis

```bash
# Check all kubeadm-managed certificate expiration dates
sudo kubeadm certs check-expiration

# Check API server certificate directly
openssl s_client -connect 192.168.1.240:6443 -servername kubernetes 2>/dev/null | \
  openssl x509 -noout -dates

# Check kubelet client certificate
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates

# Check etcd certificates
openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -noout -dates

# Check all certificates in the PKI directory
for cert in /etc/kubernetes/pki/*.crt; do
  echo "=== $cert ==="
  openssl x509 -in "$cert" -noout -subject -dates
done
```

### Resolution

1. **Renew all kubeadm certificates**: This renews certificates for another year.
   ```bash
   # On the control plane node
   sudo kubeadm certs renew all

   # Restart control plane components to pick up new certs
   sudo systemctl restart kubelet

   # Wait for API server, controller-manager, and scheduler to restart
   # These run as static pods, so kubelet will restart them automatically
   sleep 30

   # Verify API server is responding
   kubectl get nodes
   ```

2. **Update kubeconfig files**: After cert renewal, regenerate admin kubeconfig.
   ```bash
   # Back up existing kubeconfig
   sudo cp /etc/kubernetes/admin.conf /etc/kubernetes/admin.conf.bak

   # Regenerate kubeconfig files
   sudo kubeadm kubeconfig user --client-name=admin --org system:masters > /tmp/admin.conf
   sudo cp /tmp/admin.conf /etc/kubernetes/admin.conf

   # Update local kubeconfig
   cp /etc/kubernetes/admin.conf ~/.kube/config
   sudo chown $(id -u):$(id -g) ~/.kube/config
   ```

3. **Renew a single certificate**: If only one certificate has expired.
   ```bash
   # Renew only the API server certificate
   sudo kubeadm certs renew apiserver

   # Restart kubelet to reload the static pod
   sudo systemctl restart kubelet
   ```

4. **Renew etcd certificates separately**: If etcd certs expired independently.
   ```bash
   sudo kubeadm certs renew etcd-server
   sudo kubeadm certs renew etcd-peer
   sudo kubeadm certs renew etcd-healthcheck-client

   # Restart etcd (runs as static pod)
   sudo systemctl restart kubelet
   ```

### Prevention
- Set a calendar reminder for certificate renewal 30 days before expiration
- Add a monitoring alert for certificate expiration (Prometheus cert-exporter)
- Enable kubelet certificate auto-rotation in kubelet config:
  ```yaml
  # /var/lib/kubelet/config.yaml
  rotateCertificates: true
  ```
- Consider running `kubeadm certs renew all` as part of routine maintenance playbooks

---

## Kubelet Certificate Rotation Failures

### Symptoms
- kubelet logs show "certificate rotation failed"
- Node goes NotReady after certificate expires
- "tls: bad certificate" errors in kubelet logs
- CSR (CertificateSigningRequest) stuck in Pending state

### Diagnosis

```bash
# Check kubelet logs for cert errors
ssh ubuntu@192.168.1.241 "sudo journalctl -u kubelet --since '1 hour ago' | grep -i cert"

# Check pending CSRs
kubectl get csr

# Check kubelet certificate rotation config
ssh ubuntu@192.168.1.241 "sudo cat /var/lib/kubelet/config.yaml | grep -i rotate"

# Check current kubelet certificate details
ssh ubuntu@192.168.1.241 "openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates -subject"
```

### Resolution

1. **Approve pending CSRs**: The controller-manager may not be auto-approving.
   ```bash
   # List pending CSRs
   kubectl get csr | grep Pending

   # Approve all pending CSRs
   kubectl get csr -o name | xargs -I {} kubectl certificate approve {}
   ```

2. **Enable certificate auto-rotation**: Ensure kubelet config has rotation enabled.
   ```bash
   # On the affected node, edit kubelet config
   ssh ubuntu@192.168.1.241 "sudo vi /var/lib/kubelet/config.yaml"
   # Ensure these settings:
   #   rotateCertificates: true
   #   serverTLSBootstrap: true

   ssh ubuntu@192.168.1.241 "sudo systemctl restart kubelet"
   ```

3. **Manual certificate bootstrap**: If automatic rotation is broken beyond repair.
   ```bash
   # On the control plane, generate a new bootstrap token
   sudo kubeadm token create

   # On the affected node, re-bootstrap kubelet
   ssh ubuntu@192.168.1.241 "sudo kubeadm join 192.168.1.240:6443 \
     --token <new-token> \
     --discovery-token-ca-cert-hash sha256:<hash> \
     --control-plane-endpoint 192.168.1.240:6443"
   ```

4. **Check controller-manager**: The cert signer must be running.
   ```bash
   kubectl get pods -n kube-system -l component=kube-controller-manager
   kubectl logs -n kube-system -l component=kube-controller-manager | grep -i sign
   ```

### Prevention
- Verify `rotateCertificates: true` is set in kubelet config during initial provisioning
- Include CSR auto-approval configuration in Ansible cluster setup
- Monitor CSR status as part of cluster health checks

---

## TLS Errors with Traefik Ingress

### Symptoms
- Browser shows "NET::ERR_CERT_AUTHORITY_INVALID" for ingress-served applications
- curl returns "SSL certificate problem: unable to get local issuer certificate"
- Traefik dashboard shows TLS configuration errors
- Mixed HTTP/HTTPS issues after enabling TLS

### Diagnosis

```bash
# Check Traefik pods and logs for TLS errors
kubectl get pods -n traefik
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=100 | grep -i tls

# Check TLS secret in the application namespace
kubectl get secrets -n <namespace> | grep tls
kubectl describe secret <tls-secret-name> -n <namespace>

# Inspect the certificate stored in the secret
kubectl get secret <tls-secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -text | head -30

# Check certificate dates and SANs
kubectl get secret <tls-secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -dates -subject -ext subjectAltName

# Check Traefik IngressRoute TLS configuration
kubectl get ingressroute -A -o yaml | grep -A 5 tls
```

### Resolution

1. **Create a self-signed certificate**: For homelab environments without a CA.
   ```bash
   # Generate a self-signed certificate
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout tls.key -out tls.crt \
     -subj "/CN=*.homelab.local" \
     -addext "subjectAltName=DNS:*.homelab.local,DNS:homelab.local,IP:192.168.1.240"

   # Create the TLS secret
   kubectl create secret tls homelab-tls \
     -n <namespace> \
     --cert=tls.crt \
     --key=tls.key

   # Clean up local files
   rm tls.key tls.crt
   ```

2. **Update expired TLS secret**: Replace the certificate data in an existing secret.
   ```bash
   # Delete and recreate the secret
   kubectl delete secret <tls-secret-name> -n <namespace>
   kubectl create secret tls <tls-secret-name> \
     -n <namespace> \
     --cert=new-tls.crt \
     --key=new-tls.key

   # Restart Traefik to pick up the new cert
   kubectl rollout restart deployment traefik -n traefik
   ```

3. **Configure Traefik default TLS certificate**: Set a cluster-wide default.
   ```yaml
   # In Traefik Helm values
   tlsStore:
     default:
       defaultCertificate:
         secretName: homelab-tls
   ```

4. **Fix certificate SAN mismatch**: The certificate must include the hostname being accessed.
   ```bash
   # Check what SANs the cert covers
   kubectl get secret <tls-secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | \
     base64 -d | openssl x509 -noout -ext subjectAltName
   ```

### Prevention
- Use wildcard certificates (`*.homelab.local`) to cover all subdomains
- Set certificate expiration reminders and automate renewal
- Document all TLS secrets and their associated ingress routes
- Consider deploying cert-manager for automated certificate lifecycle management

---

## Webhook Certificate Failures

### Symptoms
- `kubectl apply` fails with "x509: certificate signed by unknown authority" for admission webhooks
- Pod creation blocked by "failed calling webhook"
- Error: "Internal error occurred: failed to call webhook"
- Webhook endpoints returning TLS handshake errors

### Diagnosis

```bash
# List all validating and mutating webhooks
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations

# Check webhook details
kubectl describe validatingwebhookconfiguration <webhook-name>
kubectl describe mutatingwebhookconfiguration <webhook-name>

# Check the webhook service and endpoint
kubectl get svc -A | grep webhook
kubectl get endpoints -A | grep webhook

# Check webhook pod logs
kubectl logs -n <namespace> -l <webhook-pod-label> --tail=50

# Verify webhook CA bundle
kubectl get validatingwebhookconfiguration <webhook-name> -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | \
  base64 -d | openssl x509 -noout -dates -subject
```

### Resolution

1. **Delete and reinstall the webhook**: If the webhook was installed by Helm, reinstall.
   ```bash
   # Temporarily disable the webhook to unblock operations
   kubectl delete validatingwebhookconfiguration <webhook-name>

   # Reinstall the component that owns the webhook
   helm upgrade --install <release> <chart> -n <namespace>
   ```

2. **Update the CA bundle**: If the webhook's CA certificate has changed.
   ```bash
   # Get the current CA from the webhook service's TLS secret
   CA_BUNDLE=$(kubectl get secret <webhook-tls-secret> -n <namespace> \
     -o jsonpath='{.data.ca\.crt}')

   # Patch the webhook configuration
   kubectl patch validatingwebhookconfiguration <webhook-name> \
     --type='json' \
     -p="[{'op': 'replace', 'path': '/webhooks/0/clientConfig/caBundle', 'value': '${CA_BUNDLE}'}]"
   ```

3. **Set failure policy to Ignore**: As a temporary workaround to unblock operations.
   ```bash
   kubectl patch validatingwebhookconfiguration <webhook-name> \
     --type='json' \
     -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]'
   ```
   **Warning**: This bypasses validation. Restore to `Fail` after fixing the root cause.

4. **Restart webhook pods**: The webhook service may need to reload its certificates.
   ```bash
   kubectl rollout restart deployment <webhook-deployment> -n <namespace>
   ```

### Prevention
- Use cert-manager with a self-signed issuer for webhook certificates
- Include webhook health checks in cluster monitoring
- Document webhook dependencies for each installed component
- Test webhook functionality after any certificate rotation

---

## kubeconfig Certificate Issues

### Symptoms
- "Unable to connect to the server: x509: certificate has expired" when running kubectl
- kubectl works on the control plane node but not from a remote workstation
- "error: You must be logged in to the server (Unauthorized)" after cert renewal

### Diagnosis

```bash
# Check the certificate embedded in kubeconfig
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | \
  base64 -d | openssl x509 -noout -dates -subject

# Check if the kubeconfig CA matches the cluster CA
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | \
  base64 -d | openssl x509 -noout -dates -subject

# Test API server connectivity
curl -k https://192.168.1.240:6443/healthz

# Check if the kubeconfig server address is correct
kubectl config view -o jsonpath='{.clusters[0].cluster.server}'
```

### Resolution

1. **Copy updated kubeconfig from control plane**: After cert renewal on the cluster.
   ```bash
   # On the control plane node
   sudo cat /etc/kubernetes/admin.conf

   # On your workstation
   scp ubuntu@192.168.1.240:/etc/kubernetes/admin.conf ~/.kube/config
   chmod 600 ~/.kube/config

   # Update the server address if needed (use the external IP)
   kubectl config set-cluster kubernetes --server=https://192.168.1.240:6443
   ```

2. **Generate a new user certificate**: Create a fresh client certificate.
   ```bash
   # On the control plane node
   openssl genrsa -out user.key 2048
   openssl req -new -key user.key -out user.csr -subj "/CN=admin/O=system:masters"

   # Sign with the cluster CA
   sudo openssl x509 -req -in user.csr \
     -CA /etc/kubernetes/pki/ca.crt \
     -CAkey /etc/kubernetes/pki/ca.key \
     -CAcreateserial -out user.crt -days 365

   # Update kubeconfig
   kubectl config set-credentials admin \
     --client-certificate=user.crt \
     --client-key=user.key
   ```

3. **Use a service account token**: As an alternative to certificate-based auth.
   ```bash
   # Create a service account
   kubectl create serviceaccount admin-user -n kube-system

   # Create a cluster role binding
   kubectl create clusterrolebinding admin-user-binding \
     --clusterrole=cluster-admin \
     --serviceaccount=kube-system:admin-user

   # Get the token
   kubectl create token admin-user -n kube-system --duration=8760h
   ```

### Prevention
- Automate kubeconfig distribution with Ansible after cert renewal
- Keep a backup of the cluster CA certificate in a secure location
- Document the kubeconfig refresh procedure for all team members
- Use longer-lived certificates for admin kubeconfig (up to 1 year)
