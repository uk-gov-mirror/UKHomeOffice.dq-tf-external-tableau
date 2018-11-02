data "aws_region" "current" {
  current = true
}

data "aws_ami" "ext_tableau" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "dq-ext-tableau-no1",
    ]
  }

  owners = [
    "self",
  ]
}

data "aws_ami" "ext_tableau_2018_02_vanilla" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "dq-ext-tableau-82*",
    ]
  }

  owners = [
    "self",
  ]
}

data "aws_ami" "ext_tableau_s3_backup_test" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "dq-ext-tableau-71*",
    ]
  }

  owners = [
    "self",
  ]
}
