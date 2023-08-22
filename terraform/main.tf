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
    homologacao   = "us-east-1"
    producao = "sa-east-1"
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
  instance_type = "t4g.nano"
  ami           = data.aws_ami.ubuntu.id
  depends_on    = [tls_private_key.ssh_key]
  key_name      = aws_key_pair.ssh_key_generated.key_name
  tags = {
    Name    = "JoseCarlosNF-${random_id._.hex}"
    Project = "terraform-aws-101-${random_id._.hex}"
  }
}

output "public_ip_adress" {
  value = "${aws_instance.ubuntu_server.public_ip}"
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
