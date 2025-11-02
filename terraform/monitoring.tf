resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prom-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "45.6.0" # use a stable chart version

  values = [
    file("../monitoring/values/prometheus-values.yaml")
  ]

  cleanup_on_fail = true
  atomic          = true
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "10.1.4" # example stable version

  values = [
    file("../monitoring/values/grafana-values.yaml")
  ]

  cleanup_on_fail = true
  atomic          = true
}
