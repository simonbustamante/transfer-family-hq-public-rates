locals {
  profile_dev = "507964037226_AWSAdministratorAccess"
  region_dev = "us-east-1"
  server_name_tag_dev = "sftp_zeus_server_hq_public_rates_dev"
  role_dev = "arn:aws:iam::507964037226:role/svc-role-data-mic-development-integrations"
  
  suffixes = ["hq", "hn", "gt", "bo", "cr", "co", "py", "pa", "ni","sv"]

  users = [for s in local.suffixes : {
    user_name       = "sftp_zeus_user_hq_public_rates_${s}"
    entry           = "/zeus_public_rates_sftp/public_rates_${s}"
    target          = "/s3-hq-raw-dev-refer/zeus_public_rates_sftp/public_rates_${s}"
    pub_prv_key     = "sftp_user_key_hq_public_rates_dev_${s}"
    email_pub_prv_key = "zeus-hq-public-rates-dev-${s}@millicom.com"
    password_pub_prv_key = "z3us-d3v3l0pm3nt2023-${s}!"
  }]
}

provider "aws" {
  alias   = "dev"
  profile = local.profile_dev
  region  = local.region_dev
}

resource "aws_transfer_server" "sftp_server_dev" {
  provider = aws.dev
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type          = "PUBLIC"
  protocols              = ["SFTP"]

  tags = {
    Name = local.server_name_tag_dev
    Environment = "dev"
  }
}

resource "aws_transfer_user" "sftp_user" {
  for_each = { for user in local.users : user.user_name => user }

  provider          = aws.dev
  server_id         = aws_transfer_server.sftp_server_dev.id
  role              = local.role_dev
  user_name         = each.value.user_name

  home_directory_type = "PATH"
  home_directory     = each.value.target

  tags = {
    Name    = "sftp_user_${each.key}"
    Purpose = "SFTP access to zeus_sftp folder in s3-hq-anl-dev-ntwrk"
  }

  depends_on = [aws_transfer_server.sftp_server_dev]
}

resource "null_resource" "generate_public_private_keys" {
  for_each = { for user in local.users : user.user_name => user }

  provisioner "local-exec" {
    command = "if [ -f ${each.value.pub_prv_key} ]; then rm -f ${each.value.pub_prv_key}* ; fi; ssh-keygen -t rsa -b 4096 -C ${each.value.email_pub_prv_key} -f ${each.value.pub_prv_key} -N ${each.value.password_pub_prv_key}"
  }
  triggers = {
    always_run = "${timestamp()}"
  }
  depends_on = [aws_transfer_server.sftp_server_dev]
}

locals {
  public_keys = { for user in local.users : user.user_name => null_resource.generate_public_private_keys[user.user_name].triggers.always_run != "" ? file("${user.pub_prv_key}.pub") : "" }
}

resource "aws_transfer_ssh_key" "ssh_key" {
  for_each = { for user in local.users : user.user_name => user }

  provider = aws.dev
  server_id = aws_transfer_server.sftp_server_dev.id
  user_name = each.value.user_name
  body      = local.public_keys[each.key]

  depends_on = [null_resource.generate_public_private_keys]
}

resource "null_resource" "setstat_enable_dev" {
  provisioner "local-exec" {
    command = "aws transfer update-server --server-id ${aws_transfer_server.sftp_server_dev.id} --protocol-details SetStatOption=ENABLE_NO_OP --profile ${local.profile_dev}"
  }
  depends_on = [aws_transfer_server.sftp_server_dev]
}

resource "null_resource" "update_sftp_users_restricted" {
  for_each = { for user in local.users : user.user_name => user }

  provisioner "local-exec" {
    command = "aws transfer update-user --server-id ${aws_transfer_server.sftp_server_dev.id} --user-name ${each.value.user_name} --home-directory ${each.value.target} --role ${local.role_dev} --home-directory-type PATH --profile ${local.profile_dev}"
  }

  depends_on = [aws_transfer_user.sftp_user]
}

resource "local_file" "user_csv_dev" {
  for_each = { for user in local.users_uat : user.user_name => user }

  filename = "${each.value.user_name}.csv"
  content  = "username,password\n${each.value.user_name},${each.value.password_pub_prv_key}"
  depends_on = [null_resource.generate_public_private_keys_uat]
}
