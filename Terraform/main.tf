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

