# Kubernetes manifests for the Medium series

Paths in the articles are relative to the repository root. Review each example and adjust DNS names, storage classes, namespaces, and release names for your cluster before applying it. The examples use the chart versions from the series, which are historical.

| Article | Companion files |
| --- | --- |
| 13 · GitLab | [Helm values](gitlab/gitlab-values.yaml), [namespace and quotas](gitlab/gitlab-namespace.yaml), [Traefik routes](gitlab/gitlab-ingressroute.yaml), [deployment helper](gitlab/scripts/deploy-gitlab.sh) |
| 14 · GitLab Runner | [Helm values](gitlab/runner/runner-values.yaml), [namespace and RBAC](gitlab/runner/runner-rbac.yaml) |
| 17 · Argo CD | [Helm values](argocd/argocd-values.yaml), [Traefik route](argocd/argocd-ingress.yaml) |
| 18 · Observability | [Prometheus and Grafana values](monitoring/kube-prometheus-stack-values.yaml), [Loki values](monitoring/loki-values.yaml), [ServiceMonitors](monitoring/servicemonitors/), [alert rules](monitoring/alerting/), [Grafana dashboards](monitoring/dashboards/) |
| 19 · Velero | [Helm values](velero/velero-values.yaml), [backup schedules](velero/backup-schedules/), [restore examples](velero/restore-examples/) |
| 22 · Autoscaling | [Metrics Server values](cluster-autoscaler/metrics-server-values.yaml), [example HPA](cluster-autoscaler/hpa-examples/webapp-hpa.yaml), [metrics and alerts](cluster-autoscaler/servicemonitor.yaml), [Ansible autoscaler role](../../ansible/roles/cluster-autoscaler/) |

For Article 13, run from the repository root after adding the GitLab Helm repository. Use the fallback Traefik routes only if you need to replace the GitLab chart's built-in ingress.

```sh
kubectl apply -f Kubernetes/manifests/gitlab/gitlab-namespace.yaml
helm upgrade --install gitlab gitlab/gitlab --version 7.7.0 \
  --namespace gitlab --values Kubernetes/manifests/gitlab/gitlab-values.yaml \
  --timeout 15m --wait
```

For Article 14, supply the runner token through a private values override outside the checkout. The example uses the registration flow from the article and chart 0.60.0. For newer GitLab instances, use the runner authentication token flow supported by your chart.

For Article 19, create an S3-compatible backup bucket and a Secret named `velero-credentials` in the `velero` namespace. The Secret must contain a `cloud` key with an AWS-format credentials file for that bucket. Update the endpoint and bucket in the values file to match. The chart can create schedules from the values file. Review those alongside the standalone schedule examples before enabling both.
