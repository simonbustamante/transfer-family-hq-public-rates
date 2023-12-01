locals {
  profile_prd = "525196274797_AWSAdministratorAccess"
  region_prd = "us-east-1"
  server_name_tag_prd = "sftp_zeus_server_hq_public_rates_prd"
  role_prd = "arn:aws:iam::525196274797:role/svc-role-data-mic-development-integrations"
  
  suffixes_prd = ["hq", "hn", "gt", "bo", "cr", "co", "py", "pa", "ni","sv"]

  users_prd = [for s in local.suffixes_prd : {
    user_name       = "sftp_zeus_user_hq_public_rates_${s}"
    entry           = "/zeus_public_rates_sftp/public_rates_${s}"
    target          = "/s3-hq-raw-prd-refer/zeus_public_rates_sftp/public_rates_${s}"
    pub_prv_key     = "sftp_user_key_hq_public_rates_prd_${s}"
    email_pub_prv_key = "zeus-hq-public-rates-prd-${s}@millicom.com"
    password_pub_prv_key = "z3us-d3v3l0pm3nt2023-${s}!"
  }]
}

provider "aws" {
  alias   = "prd"
  profile = local.profile_prd
  region  = local.region_prd
}

resource "aws_transfer_server" "sftp_server_prd" {
  provider = aws.prd
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type          = "PUBLIC"
  protocols              = ["SFTP"]

  tags = {
    Name = local.server_name_tag_prd
    Environment = "prd"
  }
}

resource "aws_transfer_user" "sftp_user_prd" {
  for_each = { for user in local.users_prd : user.user_name => user }

  provider          = aws.prd
  server_id         = aws_transfer_server.sftp_server_prd.id
  role              = local.role_prd
  user_name         = each.value.user_name

  home_directory_type = "PATH"
  home_directory     = each.value.target

  tags = {
    Name    = "sftp_user_${each.key}"
    Purpose = "SFTP access to zeus_sftp folder in s3-hq-anl-prd-ntwrk"
  }

  depends_on = [aws_transfer_server.sftp_server_prd]
}

resource "null_resource" "generate_public_private_keys_prd" {
  for_each = { for user in local.users_prd : user.user_name => user }

  provisioner "local-exec" {
    command = "if [ -f ${each.value.pub_prv_key} ]; then rm -f ${each.value.pub_prv_key}* ; fi; ssh-keygen -t rsa -b 4096 -C ${each.value.email_pub_prv_key} -f ${each.value.pub_prv_key} -N ${each.value.password_pub_prv_key}"
  }
  triggers = {
    always_run = "${timestamp()}"
  }
  depends_on = [aws_transfer_server.sftp_server_prd]
}

locals {
  public_keys_prd = { for user in local.users_prd : user.user_name => null_resource.generate_public_private_keys[user.user_name].triggers.always_run != "" ? file("${user.pub_prv_key}.pub") : "" }
}

resource "aws_transfer_ssh_key" "ssh_key_prd" {
  for_each = { for user in local.users_prd : user.user_name => user }

  provider = aws.prd
  server_id = aws_transfer_server.sftp_server_prd.id
  user_name = each.value.user_name
  body      = local.public_keys_prd[each.key]

  depends_on = [null_resource.generate_public_private_keys]
}

resource "null_resource" "setstat_enable_prd" {
  provisioner "local-exec" {
    command = "aws transfer update-server --server-id ${aws_transfer_server.sftp_server_prd.id} --protocol-details SetStatOption=ENABLE_NO_OP --profile ${local.profile_prd}"
  }
  depends_on = [aws_transfer_server.sftp_server_prd]
}

resource "local_file" "user_csv_prd" {
  for_each = { for user in local.users_uat : user.user_name => user }

  filename = "${each.value.user_name}.csv"
  content  = "username,password\n${each.value.user_name},${each.value.password_pub_prv_key}"
  depends_on = [null_resource.generate_public_private_keys_uat]
}
