###############################################################################
# IO-107 Lab 4 — Aurora Blue/Green Deployment via Terraform + Pipeline
#
# Initial state for the training-aurora cluster.
#
# Students modify ONLY two things in this file during the lab:
#   1. Bump `engine_version` from "15.4" to "15.5".
#   2. Add a `blue_green_update { enabled = true }` block.
#
# The cluster is pre-provisioned by the platform team — Terraform manages
# in-place changes against it, not creation or destruction. See the
# project README for the full upgrade path.
#
# Source: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster
###############################################################################

data "aws_db_subnet_group" "training" {
  name = var.db_subnet_group_name
}

data "aws_security_group" "training_db" {
  id = var.vpc_security_group_id
}

data "aws_kms_key" "training_rds" {
  key_id = var.kms_key_arn
}

resource "aws_rds_cluster" "training" {
  cluster_identifier          = "training-aurora"
  engine                      = "aurora-postgresql"
  engine_version              = "15.4"
  database_name               = "training"
  master_username             = "training_admin"
  manage_master_user_password = true

  db_subnet_group_name   = data.aws_db_subnet_group.training.name
  vpc_security_group_ids = [data.aws_security_group.training_db.id]

  db_cluster_parameter_group_name = "training-aurora-pg15-default"

  storage_encrypted = true
  kms_key_id        = data.aws_kms_key.training_rds.arn

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  skip_final_snapshot       = false
  final_snapshot_identifier = "training-aurora-final"

  # NOTE: No `blue_green_update` block here. Students add it during the lab
  # alongside the engine_version bump. See README "Upgrade path".

  tags = {
    Environment = var.environment
    Application = var.application
    Owner       = var.owner
    CostCenter  = var.cost_center
    DataClass   = "internal"
  }
}
