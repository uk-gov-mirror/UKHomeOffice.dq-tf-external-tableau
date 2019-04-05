locals {
  naming_suffix       = "external-tableau-${var.naming_suffix}"
  naming_suffix_linux = "ext-tableau-linux-${var.naming_suffix}"
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
#export DATA_ARCHIVE_TAB_BACKUP_URL=`aws --region eu-west-2 ssm get-parameter --name data_archive_tab_ext_backup_url --query 'Parameter.Value' --output text`$(curl http://169.254.169.254/latest/meta-data/instance-id)/
export DATA_ARCHIVE_TAB_BACKUP_URL=`aws --region eu-west-2 ssm get-parameter --name data_archive_tab_ext_backup_url --query 'Parameter.Value' --output text``aws --region eu-west-2 ssm get-parameter --name data_archive_tab_ext_backup_sub_directory --query 'Parameter.Value' --output text`/
export TAB_EXT_REPO_URL=`aws --region eu-west-2 ssm get-parameter --name tab_ext_repo_url --query 'Parameter.Value' --output text`
export TAB_EXT_REPO_HOST=`aws --region eu-west-2 ssm get-parameter --name tab_ext_repo_host --query 'Parameter.Value' --output text`
export TAB_EXT_REPO_PORT=`aws --region eu-west-2 ssm get-parameter --name tab_ext_repo_port --query 'Parameter.Value' --output text`
export TAB_EXT_REPO_NAME=`aws --region eu-west-2 ssm get-parameter --name tab_ext_repo_name --query 'Parameter.Value' --output text`
export TAB_SRV_USER=`aws --region eu-west-2 ssm get-parameter --name tableau_server_username --query 'Parameter.Value' --output text`
export TAB_SRV_PASSWORD=`aws --region eu-west-2 ssm get-parameter --name tableau_server_password --query 'Parameter.Value' --output text --with-decryption`
export TAB_ADMIN_USER=`aws --region eu-west-2 ssm get-parameter --name tableau_admin_username --query 'Parameter.Value' --output text`
export TAB_ADMIN_PASSWORD=`aws --region eu-west-2 ssm get-parameter --name tableau_admin_password --query 'Parameter.Value' --output text --with-decryption`
export TAB_PRODUCT_KEY=`aws --region eu-west-2 ssm get-parameter --name tableau_ext_product_key --query 'Parameter.Value' --output text --with-decryption`

#!!!
#export DATASOURCES_TO_PUBLISH='`aws --region eu-west-2 ssm get-parameter --name tableau_ext_publish_datasources --query 'Parameter.Value' --output text`'
#export WORKBOOKS_TO_PUBLISH='`aws --region eu-west-2 ssm get-parameter --name tableau_ext_publish_workbooks --query 'Parameter.Value' --output text`'
#export RDS_POSTGRES=`aws --region eu-west-2 ssm get-parameter --name rds_external_tableau_postgres_endpoint --query 'Parameter.Value' --output text`
#!!!

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

echo "#TSM active license (1x Product Key) as tableau_srv"
#tsm licenses activate --trial -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD
tsm licenses activate --license-key $TAB_PRODUCT_KEY -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD

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
      "trustedHosts": [ "${var.haproxy_private_ip2}" ]
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

echo "#TSMCMD accept EULA - only required for tableau_srv"
su -c "tabcmd --accepteula" - tableau_srv

echo "#TSMCMD - initial user"
tabcmd initialuser --server 'localhost:80' --username "$TAB_ADMIN_USER" --password "$TAB_ADMIN_PASSWORD"

echo "#Get most recent Tableau backup from S3"
export LATEST_BACKUP_NAME=`aws s3 ls $DATA_ARCHIVE_TAB_BACKUP_URL | tail -1 | awk '{print $4}'`
aws s3 cp $DATA_ARCHIVE_TAB_BACKUP_URL$LATEST_BACKUP_NAME /var/opt/tableau/tableau_server/data/tabsvc/files/backups/$LATEST_BACKUP_NAME

echo "#Restore latest backup to Tableau Server"
tsm stop -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD && tsm maintenance restore --file $LATEST_BACKUP_NAME -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD && tsm start -u $TAB_SRV_USER -p $TAB_SRV_PASSWORD

############## echo "#Publishing required DataSources and WorkBooks"
############## su -c "/home/tableau_srv/scripts/tableau-pub.py /home/tableau_srv/$TAB_INT_REPO_NAME DQDashboardsE" - tableau_srv

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

aws --region eu-west-2 ssm put-parameter --name data_archive_tab_ext_backup_sub_directory --overwrite --type "String" --value "$(curl http://169.254.169.254/latest/meta-data/instance-id)"
sed -i '/DATA_ARCHIVE_TAB_BACKUP_URL/d' /home/tableau_srv/env_vars.sh
echo "
export DATA_ARCHIVE_TAB_BACKUP_URL=`aws --region eu-west-2 ssm get-parameter --name data_archive_tab_int_backup_url --query 'Parameter.Value' --output text``aws --region eu-west-2 ssm get-parameter --name data_archive_tab_int_backup_sub_directory --query 'Parameter.Value' --output text`/
" >> /home/tableau_srv/env_vars.sh

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
