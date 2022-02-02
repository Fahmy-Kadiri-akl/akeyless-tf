# Setup Akeyless Kubernetes Auth and Akeyless Webhook Injection using Terraform

This Terraform configuration will use the current configured kubernetes cluster of the kubeconfig file to create the service account and cluster role binding required to run the kubernetes authentication prerequisites on the target cluster as well as the kubernetes auth method and the kubernetes auth config on the Akeyless Gateway.

### Important Note
Make sure to add the access-id used in this example to the allowed access-ids list in your Akeyless gateway values file or in the ALLOWED_ACCESS_IDS as an environment variable for docker Gateway deployments.

## Setup

clone the repo or copy the files

Here are examples of how to set the environment variables for the Terraform variables required to configure the Kubernetes Auth Configuration. Each Terraform variable should have a detailed description on how to get the information required to set the variable inside the file.

```sh
export TF_VAR_access_id="p-w*******a1uy"
export TF_VAR_access_key="YpZ0ilF1JYJK************t6JGszsuH3ezHLJ39hE="
export TF_VAR_k8s_host="https://your-kubernetes-host-address.com"
export TF_VAR_k8s_issuer="https://container.googleapis.com/v1/projects/your-project/locations/us-east1/clusters/cluster-2"
export TF_VAR_api_gateway_address="https://your-gateway-api-8081-address.com"
export TF_VAR_k8s_auth_name="k8s-auth-tf"
export TF_VAR_k8s_auth_config_name="k8s-auth-config-tf"
```
Alternatively, you can set the values of the variables within a tfvars file that will be auto picked up like this.
```sh
cat << EOF >| variables.auto.tfvars
access_id = "p-w*******a1uy"
access_key = "YpZ0ilF1JYJK************t6JGszsuH3ezHLJ39hE = "
k8s_host = "https://your-kubernetes-host-address.com"
k8s_issuer = "https://container.googleapis.com/v1/projects/your-project/locations/us-east1/clusters/cluster-2"
api_gateway_address = "https://your-gateway-api-8081-address.com"
k8s_auth_name = "k8s-auth-tf"
k8s_auth_config_name = "k8s-auth-config-tf"
EOF
```
After setting the variables, you can run the following command to apply the changes using Terraform.
```sh
terraform init && terraform apply
```

## Tear Down
To tear down all the created resources you can run this command.
```sh
terraform destroy
```
