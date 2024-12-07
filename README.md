## Terraform GCP n8n Infrastructure

This project uses Terraform to deploy and manage infrastructure on Google Cloud Platform (GCP) for an n8n server instance. The configuration is organized into modular files, making it easier to manage and extend.

### Prerequisites

- Terraform: Install Terraform
- Google Cloud SDK: Install the Google Cloud SDK
- Google Cloud Account: With permissions to create resources on the target GCP project.
- Service Account Key: Ensure that you have a Google Cloud service account with necessary permissions, and download the credentials as a JSON file.

### Getting Started

#### Clone the repository:

```
git clone https://github.com/OliverBojahrS24/integration-service-deployment.git)
cd integration-service-deployment
```

#### Set up Google Cloud credentials:

Place the downloaded JSON key file at the specified path in providers.tf or update the file path in providers.tf to match your credentials location:

```
provider "google" {
  credentials = file("<path-to-your-json-key>.json")
  project     = var.project_id
  region      = var.region
}
```

Optionally: Modify variables.tf: Update the default values or add environment-specific overrides for project_id, region, and zone.

#### File Structure

The Terraform configuration is organized as follows:

- variables.tf: Contains variable definitions.
- providers.tf: Defines the provider configuration.
- networking.tf: Sets up network resources, including static IP and firewall rules.
- service_account.tf: Manages service accounts and IAM roles.
- storage.tf: Configures storage resources, such as disks and snapshot policies.
- compute_instance.tf: Defines the Compute Engine instance and its associated startup script.
- outputs.tf: Outputs for debugging or integration purposes.

### Usage

Setting Up Terraform Locally

#### Initialize Terraform
In the project directory, run:
```
terraform init
```

This command initializes the Terraform workspace and downloads any required providers.

#### Format and Validate:
Format the configuration files:
```
terraform fmt
```

#### Validate the setup to ensure configuration correctness:
```
terraform validate
```

### Deploying

#### Plan the Infrastructure Changes
Run a plan to preview the changes Terraform will make:
```
terraform plan
```

#### Apply the Configuration:
Apply the configuration to deploy resources:
```
terraform apply
```

Type yes when prompted to confirm.

#### Access Outputs
After applying, Terraform will output the external IP address of the n8n instance and other relevant information, as defined in outputs.tf.

### Extending

To add more resources or configurations, follow the file structure:

1.	Add Variables: Define new variables in variables.tf as needed.
2.	Extend Configuration:
   - Network Changes: Add any additional networking resources to networking.tf.
   - Service Accounts or Roles: Modify or add to service_account.tf.
   - Additional Disks or Snapshots: Extend configurations in storage.tf.
   - Compute Resources: Add further configurations in compute_instance.tf to define new instances or adjust current settings.
3.	Plan and Apply Changes:
Run terraform plan to check the changes and terraform apply to deploy updates.

### Cleanup

To delete all resources managed by this configuration, use:

terraform destroy

This command will prompt for confirmation before deleting all resources.

### Outputs

- n8n_instance_external_ip: The external IP address of the n8n server instance, which you can use to access the service.

### Debugging

Watch the startup script
```
tail -f -n 10000 /var/log/syslog | grep startup-script
```

### Backup and recovery manually

Jump into the main container:

```
sudo docker exec -it n8n sh
```

inside cd to the .n8n folder. Insider there you might create backup folder.

```
cd .n8n
mkdir -p backup/latest/workflows
mkdir -p backup/latest/credentials
```

Backup like
```
n8n export:workflow --backup --output=backups/latest/workflows
n8n export:credentials --backup --output=backups/latest/credentials
```
Restore like
```
n8n import:workflow --separate --input=backups/latest/workflows
n8n import:credentials --separate --input=backups/latest/credentials
```