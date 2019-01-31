locals {
  naming_suffix                = "external-tableau-${var.naming_suffix}"
  naming_suffix_2018_vanilla   = "ext-tableau-2018-vanilla-${var.naming_suffix}"
  naming_suffix_linux          = "ext-tableau-linux-${var.naming_suffix}"
}

resource "aws_instance" "ext_tableau" {
  key_name                    = "${var.key_name}"
  ami                         = "${data.aws_ami.ext_tableau.id}"
  instance_type               = "r4.2xlarge"
  iam_instance_profile        = "${aws_iam_instance_profile.ext_tableau.id}"
  vpc_security_group_ids      = ["${aws_security_group.sgrp.id}"]
  associate_public_ip_address = false
  subnet_id                   = "${aws_subnet.subnet.id}"
  private_ip                  = "${var.dq_external_dashboard_instance_ip}"
  monitoring                  = true

  user_data = <<EOF
  <powershell>
  $tsm_user = aws --region eu-west-2 ssm get-parameter --name tableau_server_username --query 'Parameter.Value' --output text --with-decryption
  [Environment]::SetEnvironmentVariable("tableau_tsm_user", $tsm_user, "Machine")
  $tsm_password = aws --region eu-west-2 ssm get-parameter --name tableau_server_password --query 'Parameter.Value' --output text --with-decryption
  [Environment]::SetEnvironmentVariable("tableau_tsm_password", $tsm_password, "Machine")
  $s3_bucket_name = ${var.s3_archive_bucket_name}
  [Environment]::SetEnvironmentVariable("bucket_name", $s3_bucket_name, "Machine")
  $s3_bucket_sub_path = aws --region eu-west-2 ssm get-parameter --name tableau_ext_s3_prefix --query 'Parameter.Value' --output text --with-decryption
  [Environment]::SetEnvironmentVariable("bucket_sub_path", $s3_bucket_sub_path, "Machine")
  $password = aws --region eu-west-2 ssm get-parameter --name addomainjoin --query 'Parameter.Value' --output text --with-decryption
  $username = "DQ\domain.join"
  $credential = New-Object System.Management.Automation.PSCredential($username,$password)
  $instanceID = aws --region eu-west-2 ssm get-parameter --name ext_tableau_hostname --query 'Parameter.Value' --output text --with-decryption
  Add-Computer -DomainName DQ.HOMEOFFICE.GOV.UK -OUPath "OU=Computers,OU=dq,DC=dq,DC=homeoffice,DC=gov,DC=uk" -NewName $instanceID -Credential $credential -Force -Restart
  </powershell>
EOF

  tags = {
    Name = "ec2-${local.naming_suffix}"
  }

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      "user_data",
      "ami",
      "instance_type",
    ]
  }
}

resource "aws_instance" "ext_tableau_2018_vanilla" {
  key_name                    = "${var.key_name}"
  ami                         = "${data.aws_ami.ext_tableau.id}"
  instance_type               = "r4.2xlarge"
  iam_instance_profile        = "${aws_iam_instance_profile.ext_tableau.id}"
  vpc_security_group_ids      = ["${aws_security_group.sgrp.id}"]
  associate_public_ip_address = false
  subnet_id                   = "${aws_subnet.subnet.id}"
  private_ip                  = "${var.dq_external_dashboard_instance_2018_vanilla_ip}"
  monitoring                  = true

  user_data = <<EOF
  <powershell>
  $tsm_user = aws --region eu-west-2 ssm get-parameter --name tableau_server_username --query 'Parameter.Value' --output text --with-decryption
  [Environment]::SetEnvironmentVariable("tableau_tsm_user", $tsm_user, "Machine")
  $tsm_password = aws --region eu-west-2 ssm get-parameter --name tableau_server_password --query 'Parameter.Value' --output text --with-decryption
  [Environment]::SetEnvironmentVariable("tableau_tsm_password", $tsm_password, "Machine")
  $s3_bucket_name = "${var.s3_archive_bucket_name}"
  [Environment]::SetEnvironmentVariable("bucket_name", $s3_bucket_name, "Machine")
  $s3_bucket_sub_path = aws --region eu-west-2 ssm get-parameter --name tableau_ext_s3_prefix --query 'Parameter.Value' --output text --with-decryption
  [Environment]::SetEnvironmentVariable("bucket_sub_path", $s3_bucket_sub_path, "Machine")
  $password = aws --region eu-west-2 ssm get-parameter --name addomainjoin --query 'Parameter.Value' --output text --with-decryption
  $username = "DQ\domain.join"
  $credential = New-Object System.Management.Automation.PSCredential($username,$password)
  $instanceID = aws --region eu-west-2 ssm get-parameter --name ext_tableau_hostname --query 'Parameter.Value' --output text --with-decryption
  Add-Computer -DomainName DQ.HOMEOFFICE.GOV.UK -OUPath "OU=Computers,OU=dq,DC=dq,DC=homeoffice,DC=gov,DC=uk" -NewName $instanceID -Credential $credential -Force -Restart
  </powershell>
EOF

  tags = {
    Name = "ec2-${local.naming_suffix_2018_vanilla}"
  }

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      "user_data",
      "ami",
      "instance_type",
    ]
  }
}

resource "aws_instance" "ext_tableau_linux" {
  key_name                    = "${var.key_name}"
  ami                         = "${data.aws_ami.ext_tableau_linux.id}"
  instance_type               = "c5.4xlarge"
  iam_instance_profile        = "${aws_iam_instance_profile.ext_tableau.id}"
  vpc_security_group_ids      = ["${aws_security_group.sgrp.id}"]
  associate_public_ip_address = false
  subnet_id                   = "${aws_subnet.subnet.id}"
  private_ip                  = "${var.dq_external_dashboard_linux_instance_ip}"
  monitoring                  = true

  user_data = <<EOF
#!/bin/bash
set -e
#log output from this user_data script
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
echo "#Pull values from Parameter Store and save to profile"
touch /home/tableau_srv/env_vars.sh
echo "
export DATA_ARCHIVE_TAB_BACKUP_URL=`aws --region eu-west-2 ssm get-parameter --name data_archive_tab_ext_backup_url --query 'Parameter.Value' --output text`
export TAB_EXT_REPO_URL=`aws --region eu-west-2 ssm get-parameter --name tab_ext_repo_url --query 'Parameter.Value' --output text`
export TAB_EXT_REPO_HOST=`aws --region eu-west-2 ssm get-parameter --name tab_ext_repo_host --query 'Parameter.Value' --output text`
export TAB_EXT_REPO_PORT=`aws --region eu-west-2 ssm get-parameter --name tab_ext_repo_port --query 'Parameter.Value' --output text`
export TAB_SRV_USER=`aws --region eu-west-2 ssm get-parameter --name tableau_server_username --query 'Parameter.Value' --output text`
export TAB_SRV_PASSWORD=`aws --region eu-west-2 ssm get-parameter --name tableau_server_password --query 'Parameter.Value' --output text --with-decryption`
export TAB_ADMIN_USER=`aws --region eu-west-2 ssm get-parameter --name tableau_admin_username --query 'Parameter.Value' --output text`
export TAB_ADMIN_PASSWORD=`aws --region eu-west-2 ssm get-parameter --name tableau_admin_password --query 'Parameter.Value' --output text --with-decryption`
" > /home/tableau_srv/env_vars.sh
echo "#Load the env vars needed for this user_data script"
source /home/tableau_srv/env_vars.sh
echo "#Load the env vars when tableau_srv logs in"
echo "
source /home/tableau_srv/env_vars.sh
" >> /home/tableau_srv/.bashrc
echo "#Set password for tableau_srv"
echo $TAB_SRV_PASSWORD | passwd tableau_srv --stdin
echo "#Download SSH Key pair to allow us to log in to the GitLab repo"
aws --region eu-west-2 ssm get-parameter --name tableau_external_linux_ssh_private_key --query 'Parameter.Value' --output text --with-decryption > /home/tableau_srv/.ssh/id_rsa
aws --region eu-west-2 ssm get-parameter --name tableau_external_linux_ssh_public_key --query 'Parameter.Value' --output text --with-decryption > /home/tableau_srv/.ssh/id_rsa.pub
echo "#Add gitlab host to known_hosts"
ssh-keyscan -t rsa -p $TAB_EXT_REPO_PORT $TAB_EXT_REPO_HOST >>  /home/tableau_srv/.ssh/known_hosts
echo "#Change ownership and permissions of tableau_srv files"
chown -R tableau_srv:tableau_srv /home/tableau_srv/
chmod 0400 /home/tableau_srv/.ssh/id_rsa
chmod 0444 /home/tableau_srv/.ssh/id_rsa.pub
chmod 0644 /home/tableau_srv/env_vars.sh
echo "#Get latest code from git"
su -c "git clone $TAB_EXT_REPO_URL" - tableau_srv
echo "#Initialise TSM (finishes off Tableau Server install/config)"
/opt/tableau/tableau_server/packages/scripts.*/initialize-tsm --accepteula -f -a tableau_srv
echo "#sourcing tableau server envs - because this script is run as root not tableau_srv"
source /etc/profile.d/tableau_server.sh
echo "#TSM active license (trial) as tableau_srv"
tsm licenses activate --trial -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD
#tsm licenses activate --license-key <PRODUCT_KEY> -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD
echo "#TSM register user details"
tsm register --file /tmp/install/tab_reg_file.json -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD
echo "#TSM settings (add default)"
export CLIENT_ID=`aws --region eu-west-2 ssm get-parameter --name tableau_ext_openid_provider_client_id --query 'Parameter.Value' --output text`
export CLIENT_SECRET=`aws --region eu-west-2 ssm get-parameter --name tableau_ext_openid_client_secret --query 'Parameter.Value' --output text --with-decryption`
export CONFIG_URL=`aws --region eu-west-2 ssm get-parameter --name tableau_ext_openid_provider_config_url --query 'Parameter.Value' --output text`
export EXTERNAL_URL=`aws --region eu-west-2 ssm get-parameter --name tableau_ext_openid_tableau_server_external_url --query 'Parameter.Value' --output text`
export TAB_VERSION_NUMBER=`echo $PATH | awk -F customer '{print $2}' | cut -d \. -f2- | awk -F : '{print $1}'`
cat >/opt/tableau/tableau_server/packages/scripts.$TAB_VERSION_NUMBER/config-openid.json <<EOL
{
  "configEntities": {
    "openIDSettings": {
      "_type": "openIDSettingsType",
      "enabled": true,
      "clientId": "$CLIENT_ID",
      "clientSecret": "$CLIENT_SECRET",
      "configURL": "$CONFIG_URL",
      "externalURL": "$EXTERNAL_URL"
    }
  }
}
EOL
cat >/opt/tableau/tableau_server/packages/scripts.$TAB_VERSION_NUMBER/config-trusted-auth.json <<EOL
{
  "configEntities": {
    "trustedAuthenticationSettings": {
      "_type": "trustedAuthenticationSettingsType",
      "trustedHosts": [ "10.3.0.12" ]
    }
  }
}
EOL
tsm settings import -f /opt/tableau/tableau_server/packages/scripts.*/config.json
tsm settings import -f /opt/tableau/tableau_server/packages/scripts.*/config-openid.json
tsm settings import -f /opt/tableau/tableau_server/packages/scripts.*/config-trusted-auth.json
echo "#TSM apply pending changes"
tsm pending-changes apply
echo "#TSM initialise & start server"
tsm initialize --start-server --request-timeout 1800
##Maybe only required by tableau_srv, not root
#echo "#TSMCMD accept EULA"
#tabcmd --accepteula
echo "#TSMCMD - initial user"
tabcmd initialuser --server 'localhost:80' --username $TAB_ADMIN_USER --password $TAB_ADMIN_PASSWORD
echo "#Get most recent Tableau backup from S3"
export LATEST_BACKUP_NAME=`aws s3 ls $DATA_ARCHIVE_TAB_BACKUP_URL | tail -1 | awk '{print $4}'`
aws s3 cp $DATA_ARCHIVE_TAB_BACKUP_URL$LATEST_BACKUP_NAME /var/opt/tableau/tableau_server/data/tabsvc/files/backups/$LATEST_BACKUP_NAME
echo "#Restore latest backup to Tableau Server"
tsm stop -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD && tsm maintenance restore --file $LATEST_BACKUP_NAME -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD && tsm start -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD
###Publish the *required* workbook(s)/DataSource(s) - specified somehow...?
#tabcmd login -s localhost -u $TAB_ADMIN_USER -t DQDashboards -p $TAB_ADMIN_PASSWORD
#tabcmd publish /home/tableau_srv/tableau-dq/datasources/Accuracy/Field\ Level\ Scores\ by\ Field\ Aggregrated.tdsx -project "Accuracy" --overwrite
echo "#Mount filesystem - /var/opt/tableau/"
mkfs.xfs /dev/nvme2n1
mkdir -p /mnt/var/opt/tableau/
mount /dev/nvme2n1 /mnt/var/opt/tableau
rsync -a /var/opt/tableau/ /mnt/var/opt/tableau
echo '/dev/nvme2n1 /var/opt/tableau xfs defaults 0 0' >> /etc/fstab
umount /mnt/var/opt/tableau/
echo "#Mount filesystem - /var/log/"
mkfs.xfs /dev/nvme1n1
mkdir -p /mnt/var/log/
mount /dev/nvme1n1 /mnt/var/log
rsync -a /var/log/ /mnt/var/log
semanage fcontext -a -t var_t "/mnt/var" && semanage fcontext -a -e /var/log /mnt/var/log && restorecon -R -v /mnt/var
echo '/dev/nvme1n1 /var/log xfs defaults 0 0' >> /etc/fstab
umount /mnt/var/log/
reboot
EOF

  tags = {
    Name = "ec2-${local.naming_suffix_linux}"
  }

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      "user_data",
      "ami",
      "instance_type",
    ]
  }
}

resource "aws_subnet" "subnet" {
  vpc_id            = "${var.apps_vpc_id}"
  cidr_block        = "${var.dq_external_dashboard_subnet}"
  availability_zone = "${var.az}"

  tags {
    Name = "subnet-${local.naming_suffix}"
  }
}

resource "aws_route_table_association" "external_tableau_rt_association" {
  subnet_id      = "${aws_subnet.subnet.id}"
  route_table_id = "${var.route_table_id}"
}

resource "aws_security_group" "sgrp" {
  vpc_id = "${var.apps_vpc_id}"

  ingress {
    from_port = "${var.http_from_port}"
    to_port   = "${var.http_to_port}"
    protocol  = "${var.http_protocol}"

    cidr_blocks = [
      "${var.dq_ops_ingress_cidr}",
      "${var.acp_prod_ingress_cidr}",
      "${var.peering_cidr_block}",
    ]
  }

  ingress {
    from_port = "${var.RDP_from_port}"
    to_port   = "${var.RDP_to_port}"
    protocol  = "${var.RDP_protocol}"

    cidr_blocks = [
      "${var.dq_ops_ingress_cidr}",
      "${var.peering_cidr_block}",
    ]
  }

  ingress {
    from_port = "${var.SSH_from_port}"
    to_port   = "${var.SSH_to_port}"
    protocol  = "${var.SSH_protocol}"

    cidr_blocks = [
      "${var.dq_ops_ingress_cidr}",
    ]
  }

  ingress {
    from_port = "${var.TSM_from_port}"
    to_port   = "${var.TSM_to_port}"
    protocol  = "${var.http_protocol}"

    cidr_blocks = [
      "${var.dq_ops_ingress_cidr}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "sg-${local.naming_suffix}"
  }
}
