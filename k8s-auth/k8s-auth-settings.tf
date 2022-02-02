terraform {
  required_providers {
    akeyless = {
      version = ">= 1.0.0"
      source  = "akeyless-community/akeyless"
    }
  }
}
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Environment Variables example
# export TF_VAR_access_id="p-w*******a1uy"
# export TF_VAR_access_key="YpZ0ilF1JYJK************t6JGszsuH3ezHLJ39hE="
# export TF_VAR_k8s_host="https://your-kubernetes-host-address.com"
# export TF_VAR_k8s_issuer="https://container.googleapis.com/v1/projects/your-project/locations/us-east1/clusters/cluster-2"
# export TF_VAR_api_gateway_address="https://your-gateway-api-8081-address.com"
# export TF_VAR_k8s_auth_name="k8s-auth-tf"
# export TF_VAR_k8s_auth_config_name="k8s-auth-config-tf"

variable "access_id" {
  type        = string
  description = "value of the Akeyless API access id (This Access ID MUST be configured in the allowedAccessIDs of the Gateway or BE the adminAccessId for the Gateway)"
}

variable "access_key" {
  type        = string
  description = "value of the Akeyless API access key"
  sensitive   = true
}

variable "k8s_issuer" {
  type        = string
  description = <<-EOF
  You can get the cluster issuer a number of ways
  - exec into the pod running the Akeyless Gateway on the cluster and run this command:
    cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -d'.' -f2 | base64 --decode | jq -r '.iss'
  - run this kubectl command to create a pod and read the issuer
    kubectl run jwtr --image=smallstep/step-ca --restart=Never --attach --command -- cat /var/run/secrets/kubernetes.io/serviceaccount/token | step crypto jwt inspect --insecure | jq -r '.payload.iss' && kubectl delete pod jwtr 2>&1 >/dev/null
  EOF
}

variable "k8s_host" {
  type        = string
  description = <<-EOF
    The hostname of the Kubernetes API server.
    This can be an IP address or a hostname including schema.
    If you are running Kubernetes in a cluster,
    this should be the hostname of the API server.
    If you are running Kubernetes in a standalone mode,
    this should be the hostname of the Kubernetes master node.
    Examples:
    - https://your-kubernetes-hostname.com
  EOF
}

variable "k8s_auth_name" {
  type        = string
  description = "The name of the Akeyless k8s Auth Method"
}

variable "k8s_auth_config_name" {
  type        = string
  description = "The name of the Akeyless k8s Auth Config"
}

variable "api_gateway_address" {
  type        = string
  description = <<-EOF
    value of the Akeyless Gateway 8081 port address 
    Examples:
    - http://localhost:8081 if using port forwarding
    - http://your-gateway-ip-address:8081 if using a port
    - https://your-gateway-api-address.com that maps to the 8081 port
    EOF
}

variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/config"
  description = "The path to the kubeconfig file"
}

variable "reviewer_name" {
  type        = string
  default     = "gateway-token-reviewer"
  description = "The name of the kubernetes service account token reviewer"
}

variable "reviewer_namespace" {
  type        = string
  default     = "default"
  description = "The namespace of the kubernetes service account token reviewer"
}

provider "akeyless" {
  api_gateway_address = var.api_gateway_address

  api_key_login {
    access_id  = var.access_id
    access_key = var.access_key
  }

  # aws_iam_login {
  #   access_id = var.access_id
  # }

  # azure_ad_login {
  #   access_id = var.access_id
  # }

  # email_login {
  #   admin_email    = ""
  #   admin_password = ""
  # }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

resource "kubernetes_service_account_v1" "reviewer" {
  metadata {
    namespace = var.reviewer_namespace
    name      = var.reviewer_name
  }
}

resource "kubernetes_cluster_role_binding_v1" "reviewer_binding" {
  metadata {
    name = "${kubernetes_service_account_v1.reviewer.metadata[0].name}-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.reviewer.metadata[0].name
    namespace = kubernetes_service_account_v1.reviewer.metadata[0].namespace
  }
}

data "kubernetes_secret" "reviewer" {
  metadata {
    name      = kubernetes_service_account_v1.reviewer.default_secret_name
    namespace = kubernetes_service_account_v1.reviewer.metadata[0].namespace
  }
}

resource "akeyless_auth_method_k8s" "k8s_auth_method" {
  name = var.k8s_auth_name
}

resource "akeyless_k8s_auth_config" "k8s_auth_config" {
  name               = var.k8s_auth_config_name
  access_id          = akeyless_auth_method_k8s.k8s_auth_method.access_id
  signing_key        = akeyless_auth_method_k8s.k8s_auth_method.private_key
  token_reviewer_jwt = data.kubernetes_secret.reviewer.data.token
  k8s_issuer         = var.k8s_issuer
  k8s_host           = var.k8s_host
  k8s_ca_cert        = base64encode(data.kubernetes_secret.reviewer.data["ca.crt"])
}

resource "akeyless_role" "k8s-access-role" {
    name = "/k8s-role"

  assoc_auth_method {
    am_name = akeyless_auth_method_k8s.k8s_auth_method.name
    sub_claims = {
      "namespace" = "my-apps"
    }
  }
  rules {
    capability = ["read", "list"]
    path = "/k8s/*"
    rule_type = "item-rule"
  }
}

resource "helm_release" "k8s-secret-injection" {
  name = "fk-aks-k8sinjector"

  repository = "https://akeylesslabs.github.io/helm-charts"
  chart      = "akeyless-secrets-injection"
  namespace  = "k8sinjector"
  depends_on = [
    akeyless_k8s_auth_config.k8s_auth_config
  ]
  version = "1.2.9"
  values = [<<EOT
replicaCount: 1
minikube: false
openshiftEnabled: false
debug: false
tlsCertsSecretName: vault-secrets-webhook-tls-certs
image:
  repository: akeyless/k8s-webhook-server
  pullPolicy: Always
  tag: 0.20.7
serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  # name: ""
  # Optional additional annotations to add to the controller's ServiceAccount
  # annotations: {}
  # Automount API credentials for a Service Account.
  automountServiceAccountToken: true
service:
  name: secrets-webhook
  type: ClusterIP
  externalPort: 443
  internalPort: 8443
env:
  AKEYLESS_URL: ${var.api_gateway_address}
  AKEYLESS_AGENT_IMAGE:  "akeyless/k8s-secrets-sidecar:latest"
  AKEYLESS_ACCESS_ID: ${akeyless_auth_method_k8s.k8s_auth_method.access_id}
  AKEYLESS_ACCESS_TYPE: "k8s"  # azure_ad/aws_iam/api_key/k8s
  AKEYLESS_API_GW_URL: ${var.api_gateway_address}
 # AKEYLESS_POD_ACCESS_PATH: "<location-to-access-secrets-per-pod-name>"
 # AKEYLESS_NAMESPACE_ACCESS_PATH: "<location-to-access-secrets-per-namespace>"
 # AKEYLESS_SECRET_DIR_NAME: "/apps/jenkins"
 # AKEYLESS_API_KEY: "<api_key>"
 # AKEYLESS_CRASH_POD_ON_ERROR: "enable"
  AKEYLESS_K8S_AUTH_CONF_NAME: ${var.k8s_auth_config_name}
resources:
  limits:
    cpu: 0.5
    memory: 192Mi
  requests:
    cpu: 0.25
    memory: 128Mi
nodeSelector: {}
tolerations: []
affinity: |
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            app: {{ template "vault-secrets-webhook.name" . }}
            release: {{ .Release.Name }}
  EOT
  ]
}
