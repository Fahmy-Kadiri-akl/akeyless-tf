provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

variable "access_id" {
  type = string  
}

variable "access_key" {
  type = string  
}

resource "helm_release" "akeyless-gateway" {
  name = "fk-aks-gw"


  repository = "https://akeylesslabs.github.io/helm-charts"
  chart      = "akeyless-api-gateway"
  namespace  = "fk-aks-akeyless"
  values = [<<EOT
# Default values for akeyless-api-gateway.

replicaCount: 1

image:
  repository: akeyless/base
  pullPolicy: IfNotPresent
  tag: latest

containerName: "api-gateway"

deployment:
  annotations: {}

service:
  # Remove the {} and add any needed annotations regarding your LoadBalancer implementation
  annotations: {}
  #type: LoadBalancer // why did we replace LoadBalancer with ClusterIP
  type: ClusterIP

  # Here you can manage the list of ports you want to expose on the service (don't modify the port name):
  # 8000 - Configuration manager
  # 8080 - Akeyless Restful API
  # 8081 - Akeyless Restful API V2
  # 8200 - HVP vault proxy
  # 5696 - KMIP
  # 18888 - Akeyless UI
  ports:
    - name: web
      port: 18888
    - name: configure-app
      port: 8000
    - name: legacy-api
      port: 8080
    - name: api
      port: 8081
    - name: hvp
      port: 8200
    - name: kmip
      port: 5696


livenessProbe:
  initialDelaySeconds: 120
  periodSeconds: 60
  failureThreshold: 10

readinessProbe:
  initialDelaySeconds: 120 # Startup can take time
  periodSeconds: 10
  timeoutSeconds: 5

## Configure the ingress resource that allows you to access the
## akeyless-api-gateway installation. Set up the URL
## ref: http://kubernetes.io/docs/user-guide/ingress/
##
ingress:
  ## Set to true to enable ingress record generation
  ##
  enabled: true

  annotations:
  # Example for Nginx ingress
    # decide if you will use a namespace issuer or cluster issuer
    cert-manager.io/issuer: letsencrypt-prod
    #cert-manager.io/cluster-issuer: letsencrypt-prod
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-buffer-size: 8k
    nginx.ingress.kubernetes.io/proxy-buffers-number: "4"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"

  # Example for AWS ELB ingress
  #    annotations:
  #      kubernetes.io/ingress.class: alb
  #      alb.ingress.kubernetes.io/scheme: internet-facing

  rules:
    - servicePort: web
      hostname: gw.dnsname.local
    - servicePort: hvp
      hostname: gw-hvp.dnsname.local
    - servicePort: legacy-api
      hostname: gw-api.dnsname.local
    - servicePort: api
      hostname: gw-api-v2.dnsname.local
    - servicePort: configure-app
      hostname: gw-config.dnsname.local
    - servicePort: kmip
      hostname: gw-kmip.dnsname.local


  ## Path for the default host
  ##
  path: /

  ## Enable TLS configuration for the hostname defined at ingress.hostname parameter
  ## TLS certificates will be retrieved from a TLS secret with name: {{- printf "%s-tls" .Values.ingress.hostname }}
  ## or a custom one if you use the tls.existingSecret parameter
  ##
  tls: true

  ## Set this to true in order to add the corresponding annotations for cert-manager and secret name
  ##
  certManager: true

  ## existingSecret: name-of-existing-secret

resources: {}
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  # limits:
  #   cpu: 100m
  #   memory: 128Mi
  # requests:
  #   cpu: 100m
  #   memory: 128Mi

# Akeyless API Gateway application version
# version:

env: []

akeylessUserAuth:
  # adminAccessId is required field, supported types: access_key,password or cloud identity(aws_iam/azure_ad/gcp_gce)
  adminAccessId: ${var.access_id}
  adminAccessKey: ${var.access_key}
  adminPassword:
  clusterName:
  initialClusterDisplayName:
  # The key which is used to encrypt the API Gateway configuration. 
  # If left empty - the account’s default key will be used. 
  # This key can be determined on cluster bring-up only and cannot be modified afterwards
  configProtectionKeyName:
  # list of allowed access-ids from your account that can login to the Configuration Management WebUI
  allowedAccessIDs:
    - p-u91zmregsrwb
    - p-9h04hlmf5o02
    - p-282ijeav92ws email=fahmy.k@akeyless.io
  
# Customer Fragment is a critical component that allow customers to use a Zero-Knowledge Encryption.
# For more information: https://docs.akeyless.io/docs/implement-zero-knowledge
customerFragments: |
  {
      "customer_fragments": [
          {
              "id": "......replace....me.....",
              "value": ".........replace.....me.........************============",
              "description": "Customer Fragment"
          }
      ]
  }
# Specifies an existing secret to be used for API Gateway, must include:
#  - admin-access-id,
#  - admin-access-key
#  - admin-password
#  - allowed-access-ids
#  - customer-fragments
existingSecret: 

HPA:
  # Set the below to false in case you do not want to add Horizontal Pod AutoScaling to the StatefulSet (not recommended)
  # Note that metrics server must be installed for this to work:
  # https://github.com/kubernetes-sigs/metrics-server
  enabled: false
  minReplicas: 1
  maxReplicas: 14
  cpuAvgUtil: 50
  memAvgUtil: 50

EOT
  ]
}
