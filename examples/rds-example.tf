# rds-example.tf
# ---------------------------------------------------------------------------
# STANDALONE EXAMPLE — not part of the qe_api stack, not wired to anything
# in it. Meant to be read, and optionally applied in its own throwaway
# directory/state, not dropped into the qe_api root.
#
# Shows a minimal Postgres RDS instance: subnet group, security group,
# the instance itself, and its connection details as outputs.
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "Existing VPC to launch the DB into. Every AWS account has a Default VPC unless someone deleted it."
  type        = string
}

variable "subnet_ids" {
  description = "At least 2 subnet IDs in 2 different AZs — RDS requires this even for a single-AZ instance."
  type        = list(string)
}

variable "db_password" {
  description = "Master password. Passed in, not hardcoded — see note below on Secrets Manager as the better alternative."
  type        = string
  sensitive   = true
}

resource "aws_db_subnet_group" "example" {
  name       = "example-postgres"
  subnet_ids = var.subnet_ids
}

# Controls what can reach the database over the network. Empty ingress here
# on purpose — nothing can connect until you add a rule allowing, e.g.,
# your Lambda's security group on port 5432.
resource "aws_security_group" "db" {
  name   = "example-postgres-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "example" {
  identifier     = "example-postgres"
  engine         = "postgres"
  engine_version = "16.4"

  # Smallest burstable instance class — fine for learning/dev, not for a
  # real workload. This is the thing that bills per hour regardless of
  # whether anything queries it — see the earlier cost discussion.
  instance_class = "db.t4g.micro"

  allocated_storage = 20    # GB, gp3 by default
  storage_encrypted = true

  db_name  = "exampledb"
  username = "postgres"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.example.name
  vpc_security_group_ids = [aws_security_group.db.id]

  # Single instance, no standby replica. Set to true for production —
  # doubles the hourly cost, but survives an AZ failure.
  multi_az = false

  # Skip the final snapshot on destroy — convenient for a throwaway example,
  # dangerous for anything you actually care about losing.
  skip_final_snapshot = true

  # Publicly accessible defaults to false; leaving it unset here so the
  # default holds — reachable only from inside the VPC, via the security
  # group above.
}

output "endpoint" {
  description = "host:port to connect to, e.g. from a Lambda in the same VPC."
  value       = aws_db_instance.example.endpoint
}

output "db_instance_id" {
  value = aws_db_instance.example.id
}
