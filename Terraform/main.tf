# Create A VPC 
resource "aws_vpc" "main_vpc" {
    cidr_block          =   "${var.VPC_CIDR}"
    instance_tenancy    =   "default"
    tags                = {
        Name            = "${var.app_name}-vpc"
    }
}

# Create IGW for Public Access 
resource "aws_internet_gateway" "gw" {
    vpc_id              = "${aws_vpc.main_vpc.id}"
    tags                = {
        Name            = "${var.app_name}-igw"
  }
}

#Creating one public subnet
resource "aws_subnet" "public-subnets" {

    vpc_id                      = "${aws_vpc.main_vpc.id}"
    cidr_block                  = "10.20.1.0/24"
    map_public_ip_on_launch     = true

    tags = {
        Name                    = "public subnet"
  }
}


# Create Route  for Public Subnet
resource "aws_route_table" "public-rt" {
    vpc_id                      = "${aws_vpc.main_vpc.id}"

    route {
      cidr_block                = "0.0.0.0/0"
      gateway_id                = "${aws_internet_gateway.gw.id}"
    }

    tags                        = {
        Name                    = "${var.app_name}-Public-RT"
    }
}



## Associate Public-Route table to Public Subnet
resource "aws_route_table_association" "public-assoc" {

    subnet_id                   = "${aws_subnet.public-subnets.id}"
    route_table_id              = "${aws_route_table.public-rt.id}"
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = "${aws_vpc.main_vpc.id}"

  ingress {
    # HTTP (change to whatever ports you need)
    from_port   = 80
    to_port     = 80
    protocol    = "-1"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]# add a CIDR block here
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

## Make Dynamic SSH keys
resource "null_resource" "make-ssh-keys" {
    provisioner "local-exec" {
        command                 = "ssh-keygen -q -t rsa -f wikimedia -N ''"
    }

}
module "pem_content" {
  source                        = "matti/outputs/shell"
  command                       = "cat wikimedia"
}

### Get PUB Content
module "pub_content" {
  source                        = "matti/outputs/shell"
  command                       = "cat wikimedia.pub"
}

resource "aws_key_pair" "wikimedia" {
  key_name                      = "wikimedia-key"
  public_key                    = "${module.pub_content.stdout}"
}


resource "aws_instance" "web" {
  count                         = 1
  ami                           = "ami-07d0cf3af28718ef8"
  instance_type                 = "t2.large"
  key_name                      = "${aws_key_pair.wikimedia.key_name}"
  vpc_security_group_ids        = ["${aws_security_group.allow_http.id}"]
  subnet_id                     = "${aws_subnet.public-subnets.id}"

  tags                          = {
      Name                      = "${var.app_name}-node"
  }

  provisioner "remote-exec" {
    connection {
      type                      = "ssh"
      user                      = "centos"
      private_key               = "${file("wikimedia")}"
      host                      = "${aws_instance.web.*.public_ip}"

    }

    inline                      = [
      "sudo apt-get update && sudo apt-get install docker.io -y",
      "sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl) && sudo chmod 755 ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl",
      "curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/",
      "minikube start --vm-driver=none"
    ]
  }

}
