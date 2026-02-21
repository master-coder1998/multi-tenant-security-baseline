# modules/network-isolation/main.tf
# VPC and network security for a single tenant — private subnets,
# default-deny security groups, VPC endpoints, and flow logs.

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name   = "${var.tenant_name}-vpc"
    Tenant = var.tenant_name
  })
}

# ---------------------------------------------------------------------------
# Subnets — private only; public subnets added only if ALB is needed
# ---------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-private-${var.availability_zones[count.index]}"
    Type = "private"
  })
}

# ---------------------------------------------------------------------------
# Internet Gateway + NAT Gateway (egress only)
# ---------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  count  = var.enable_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-igw"
  })
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-nat-eip"
  })
}

resource "aws_subnet" "public_nat" {
  count             = var.enable_nat_gateway ? 1 : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, length(var.availability_zones))
  availability_zone = var.availability_zones[0]

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-nat-subnet"
    Type = "nat-only"
  })
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_nat[0].id

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-nat-gw"
  })

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------------
# Route Tables
# ---------------------------------------------------------------------------

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---------------------------------------------------------------------------
# VPC Endpoints — private connectivity to AWS services (no internet required)
# ---------------------------------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-ssmmessages-endpoint"
  })
}

data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------

# Default-deny security group for workloads
resource "aws_security_group" "default_deny" {
  name        = "${var.tenant_name}-default-sg"
  description = "Default deny all ingress. Workloads only permitted explicit egress."
  vpc_id      = aws_vpc.main.id

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
    description     = "HTTPS to S3 via VPC endpoint"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS to VPC endpoints (SSM, etc.)"
  }

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-default-sg"
  })
}

# Security group for VPC interface endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.tenant_name}-vpc-endpoints-sg"
  description = "Allow HTTPS from tenant VPC to interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from tenant VPC"
  }

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-vpc-endpoints-sg"
  })
}

# Network ACL — additional subnet-level guardrail
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-private-nacl"
  })
}
