terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "gcs" {}
}

provider "cloudflare" {
  email = "${var.cloudflare_email}"
  token = "${var.cloudflare_token}"
}

provider "helm" {}

provider "kubernetes" {}

################################################################################
# [TBD] CREATE A KUBERNETES NAMESPACE
################################################################################

resource "kubernetes_namespace" "core" {
  metadata {
    name = "terraform-xk-core-namespace"
  }
}

################################################################################
# INSTALL CORE HELM CHARTS
################################################################################

resource "helm_release" "ingress_controller" {
  name       = "cluster-proxy"
  repository = "https://kubernetes-charts.storage.googleapis.com"
  chart      = "nginx-ingress"
  values     = "${file("${var.helm_values_ingress_controller}")}"

  provisioner "local-exec" {
    command = "sleep 15"
  }
}

resource "helm_release" "kube_lego" {
  name       = "cluster-tls"
  repository = "https://kubernetes-charts.storage.googleapis.com"
  chart      = "kube-lego"
  values     = "${file("${var.helm_values_kube_lego}")}"
  depends_on = ["helm_release.ingress_controller"]

  provisioner "local-exec" {
    command = "sleep 30"
  }
}

################################################################################
# [TBD] Create a CloudFlare DNS record for our DNS zone
################################################################################

resource "cloudflare_record" "web" {
  depends_on = ["helm_release.ingress_controller"]

  domain   = "${var.cloudflare_domain_zone}"
  name     = "*"
  value    = "${data.kubernetes_service.ingress_controller.load_balancer_ingress.0.ip}"
  type     = "A"
  proxied  = false
  priority = 0
}

data "kubernetes_service" "ingress_controller" {
  depends_on = ["helm_release.ingress_controller"]

  metadata {
    name = "cluster-proxy-nginx-ingress-controller"
  }
}