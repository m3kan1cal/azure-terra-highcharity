## Episode 1: Building a Basic Bastion/Worker Host Virtual Network

Episode 1 of this series is comprised of an Azure subscription, the free version of Terraform, and a virtual network with a public subnet hosting a bastion host for jumping to worker hosts deployed to a private subnet. It’s a basic start for an enterprise-y network with the intent of segmenting off networks for security.

## Getting your environment ready for deployment

If you don't know it already, get your Azure subscription id with the Azure CLI. Once you have that, you're going to set some environment variables, including your Azure subscription, tenant id, client id, and client secret in environment variables. You'll also create a Service Principal for role-based access so you don't have to keep manually logging in with `az login`.

```bash
# Get Azure subscription id.
az login
az account list --all --query "[].id"

# Set Azure subscription.
export SUBSCRIPTION_ID="<azure_subscription_id>"
az account set --subscription="${SUBSCRIPTION_ID}"

# Create service principal for role-based access. Note the output of the Service Principal
# command where the client id, client secret, and tenant ids are shown.
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}"

# Once you have your Azure Service Principal values, you need to set a few environment variables
# so you're not having to maintain them. For the below values, you should have noted them
# from the above steps.
echo "Setting environment variables for Terraform"
export ARM_SUBSCRIPTION_ID="${SUBSCRIPTION_ID}"
export ARM_CLIENT_ID="<azure_client_id>"
export ARM_CLIENT_SECRET="<azure_client_secret>"
export ARM_TENANT_ID="<azure_tenant_id>"

# Not needed for public, required for usgovernment, german, china.
export ARM_ENVIRONMENT=public
```

You're almost ready to start deploying. Now create some SSH keys for connecting to your bastion and worker VMs in your Azure resource group once deployed. You need to note your SSH public key values to reference in the Terraform `main` template. Once you have these values using the below commands, note the outputs in [Visual Studio Code](https://code.visualstudio.com/) and immediately change the `ssh_keys.key_data` values at **line 238** and **line 283** to reflect the outputs.

```bash
# Create for bastion host VM.
ssh-keygen -t rsa -b 4096 -C "fireteamosiris@withcbg.com" -f $HOME/.ssh/id_rsa_azurebstn -N ''

# Create for worker host VM.
ssh-keygen -t rsa -b 4096 -C "fireteamosiris@withcbg.com" -f $HOME/.ssh/id_rsa_azurewrkr -N ''

# Get the SSH public key value for bastion host.
cat ~/.ssh/id_rsa_azurebstn.pub

# Get the SSH public key value for worker host.
cat ~/.ssh/id_rsa_azurewrkr.pub
```

## Deploying your Azure stack

You're now almost ready to deploy your Azure stack with Terraform. Make sure you're good with the variable settings at the top of the `main.tf` and `files/nginx.yml`. Once you're solid, you're ready to move forward with initializing the project. This step ensures that Terraform has all the prerequisites to build your template in Azure.

```bash
# Initialize the Terraform stack to get the necessary plugins and providers.
terraform init
```

Once the Terraform project is initialized, the real action begins. Validate and deploy the stack. This step compares the requested resources to the state information saved by Terraform and then outputs the planned execution. Resources are not created in Azure, only output to the screen for you to validate visually.

```bash
# Validate and plan the resources.
terraform plan
```

If everything looks correct and you are ready to build the infrastructure in Azure, apply the template in Terraform.

```bash
# Apply and deploy the resources.
terraform apply -auto-approve
```

Once Terraform completes, your VM infrastructure is ready. With a little bit of luck, your basic virtual network is now deployed with a public subnet, private subnet, and bastion and worker hosts in place to provide a beginning for a very basic enterprise network with minimal network segmentation.

## Connecting to your bastion and worker hosts

Once your Terraform template has been applied and deployed, you're now ready to start connecting to your VMs to ensure resources were deployed properly and are secured.

First, you need to get the IP addresses for all VMs in your resource group. Note the private IP of the worker host and public IP of the bastion host that was created during deployment; you'll be using this for connecting via ssh.

Then you're going to copy the worker host SSH private key to the bastion host for connecting later to worker hosts from the bastion. Follow these steps to ensure connectivity to the newly created resources.

```bash
# Get IP addresses of all hosts, public and private.
az vm list-ip-addresses \
    --ids $(az vm list --resource-group cbghighcharity-rg --query "[].id" --output tsv)

# Copy worker host VM SSH private key to bastion host for connecting later to worker hosts.
scp -i ~/.ssh/id_rsa_azurebstn \
    ~/.ssh/id_rsa_azurewrkr fireteamosiris@<bastion_public_ip>:~/.ssh/id_rsa_azurewrkr

# Connect to bastion host in public subnet.
ssh fireteamosiris@<bastion_public_ip> -i ~/.ssh/id_rsa_azurebstn

# Check connectivity to worker host in private subnet.
ping cbghighcharity-wrkr-vm001
ping <worker_private_ip>

# Connect to worker host in private subnet from bastion host in public subnet.
ssh fireteamosiris@cbghighcharity-wrkr-vm001 -i ~/.ssh/id_rsa_azurewrkr
```

## In summary

Assuming everything went smooth for you, you have completed this walkthrough and you have an Azure subscription, Terraform, and a virtual network with a public subnet hosting a bastion host for jumping to worker hosts deployed to a private subnet to prove it.

![Cheers!](https://miro.medium.com/max/537/1*SLKe4WOSIc8ntoWJw2C_4A.png)
