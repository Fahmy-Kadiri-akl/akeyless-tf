# Setup Akeyless Gateway through Helm using Terraform

Enter values directly into the values section of the main.tf or provide them as Terraform variables through environment variables

## Initialize the Terraform

```sh
terraform init
```

## Set a Terraform Variable through an Environment Variable
Useful for when you want to make sure you don't commit secrets into the Terraform git repo

```sh
export TV_VAR_api_access_key="32t3gfdgfs43543gfd3*************7gfdgfdgfd-="
```
You can utilize the Terraform variable's value like this:
https://gist.github.com/devorbitus/cd32935f5620ff16ca160ab714a28029#file-main-tf-L142 


## Run a Terraform plan

```sh
terraform plan
```

## Execute a Terraform apply

```sh
terraform apply
```
