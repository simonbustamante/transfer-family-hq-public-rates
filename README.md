## README.md for Terraform Configuration

### Overview
This Terraform configuration sets up AWS Transfer for SFTP servers across three environments: development (dev), production (prd), and user acceptance testing (uat). It defines resources for server setup, user configuration, SSH key generation, and CSV file creation for user credentials.

### Environments
- **Development (dev):**
  - AWS Profile: `507964037226_AWSAdministratorAccess`
  - Region: `us-east-1`
  - Server Name: `sftp_zeus_server_hq_public_rates_dev`
  - IAM Role: `arn:aws:iam::507964037226:role/svc-role-data-mic-development-integrations`

- **Production (prd):**
  - AWS Profile: `525196274797_AWSAdministratorAccess`
  - Region: `us-east-1`
  - Server Name: `sftp_zeus_server_hq_public_rates_prd`
  - IAM Role: `arn:aws:iam::525196274797:role/svc-role-data-mic-development-integrations`

- **User Acceptance Testing (uat):**
  - AWS Profile: `350281604643_AWSAdministratorAccess`
  - Region: `us-east-1`
  - Server Name: `sftp_zeus_server_hq_public_rates_uat`
  - IAM Role: `arn:aws:iam::350281604643:role/svc-role-data-mic-development-integrations`

### Common Configuration
- **Suffixes:** `["hq", "hn", "gt", "bo", "cr", "co", "py", "pa", "ni", "sv"]`
- **Users:** Configured for each suffix, with specific paths, target directories, and keys.

### Resources
1. **AWS Transfer Server:** Configured for each environment with public endpoint and SFTP protocol.
2. **AWS Transfer User:** Users created for each suffix, linked to respective servers and roles.
3. **SSH Key Generation:** For each user, public/private SSH keys are generated using `ssh-keygen`.
4. **AWS Transfer SSH Key:** SSH public keys are attached to the respective SFTP users.
5. **Local File Creation:** Generates CSV files for each user containing usernames and passwords.
6. **Miscellaneous:** Includes resources like `null_resource` for enabling server options and updating user settings.

### Dependencies
- Terraform
- AWS CLI
- Access to specified AWS accounts with sufficient permissions

### Execution
1. Initialize Terraform workspace.
2. Review and apply the Terraform plan.
3. Monitor AWS resources for successful creation.

### Caution
- Ensure AWS credentials are securely handled.
- Verify IAM roles and permissions.
- Test in a controlled environment before production deployment.