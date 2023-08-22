# ----------------------- Declaração de dependências -------------------------
terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "5.13.1" }
    tls    = { source = "hashicorp/tls", version = "~> 3.0" }
    random = { source = "hashicorp/random", version = "3.5.1" }
  }
}

# ------------------------ Identificação do projeto --------------------------
resource "random_id" "_" {
  byte_length = 8
}

variable "region" {
  default = {
    homologacao = "us-east-1"
    producao    = "sa-east-1"
  }
}

locals {
  resource_name = "JoseCarlosNF-${random_id._.hex}"
  project_name  = "terraform-aws-101-${random_id._.hex}"
  common_tags = {
    Name    = local.resource_name
    Project = local.project_name
  }
}

# ------------------------ Configuração do provider --------------------------
provider "aws" {
  region = lookup(var.region, terraform.workspace)
}

# ---------------------- Obtem ami do ubuntu 22.04 LTS ------------------------
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-*"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# ----------------------- Definição da instância EC2 -------------------------
resource "aws_instance" "ubuntu_server" {
  instance_type   = "t4g.nano"
  ami             = data.aws_ami.ubuntu.id
  depends_on      = [tls_private_key.ssh_key]
  key_name        = aws_key_pair.ssh_key_generated.key_name
  security_groups = [aws_security_group.allow_http_ssh.name]
  tags            = local.common_tags
}

output "public_ip_adress" {
  value = aws_instance.ubuntu_server.public_ip
}

# ---------------------- Geração do par de chaves SSH ------------------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key_generated" {
  key_name   = "ssh_key_generated_by_terraform"
  public_key = tls_private_key.ssh_key.public_key_openssh

  provisioner "local-exec" {
    command = <<EOT
      echo '${tls_private_key.ssh_key.private_key_pem}' > ./ssh_key_aws.pem
      chmod 600 ssh_key_aws.pem
    EOT
  }
}

# ----------------------------- Security group -------------------------------
resource "aws_security_group" "allow_http_ssh" {
  name = local.project_name

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

/*
------------------ Permite tráfego interno no Security group ------------------

Dessa forma, o tráfego entre os recursos que estão usando o security group
declarado, aconteçera de forma livre.
*/
resource "aws_security_group_rule" "allow_traffic_inside_sg" {
  security_group_id = aws_security_group.allow_http_ssh.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  self              = true
}

# -------------------------------- Route 53 ----------------------------------
resource "aws_route53_zone" "josecarlosnf_tech" {
  name = "josecarlosnf.cloud"
  tags = local.common_tags
}

resource "aws_route53_record" "terraform-aws-101_josecarlosnf_tech" {
  zone_id = aws_route53_zone.josecarlosnf_tech.zone_id
  name    = "${local.project_name}.${aws_route53_zone.josecarlosnf_tech.name}"
  type    = "A"
  ttl     = 30
  records = [aws_instance.ubuntu_server.public_ip]
}

output "url" {
  value = "https://${aws_route53_record.terraform-aws-101_josecarlosnf_tech.name}"
}
