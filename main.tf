
resource "aws_efs_file_system" "default" {
  #bridgecrew:skip=BC_AWS_GENERAL_48: BC complains about not having an AWS Backup plan. We ignore this because this can be done outside of this module.
  # count                           = local.enabled ? 1 : 0
  tags                            = var.tags
  availability_zone_name          = var.availability_zone_name
  encrypted                       = var.encrypted
  kms_key_id                      = var.kms_key_id
  performance_mode                = var.performance_mode
  provisioned_throughput_in_mibps = var.provisioned_throughput_in_mibps
  throughput_mode                 = var.throughput_mode

  dynamic "lifecycle_policy" {
    for_each = var.transition_to_ia == "" ? [] : [1]
    content {
      transition_to_ia = var.transition_to_ia
    }
  }

  dynamic "lifecycle_policy" {
    for_each = var.transition_to_primary_storage_class == "" ? [] : [1]
    content {
      transition_to_primary_storage_class = var.transition_to_primary_storage_class
    }
  }
}

resource "aws_efs_mount_target" "default" {
  count          = length(var.subnets)
  file_system_id = aws_efs_file_system.default.id
  # ip_address     = var.mount_target_ip_address
  subnet_id      = var.subnets[count.index]
  security_groups = var.security_groups
  # security_groups = compact(
  #   (concat(
  #     [module.security_group.id],
  #     var.associated_security_group_ids
  #   ))
  # )
}

resource "aws_efs_access_point" "default" {
  for_each = var.access_points

  file_system_id = aws_efs_file_system.default.id

  dynamic "posix_user" {
    for_each = null != lookup(each.value, "posix_user", lookup(var.access_points_defaults, "posix_user", null)) ? [1] : []
    content {
      gid            = lookup(lookup(each.value, "posix_user", lookup(var.access_points_defaults, "posix_user", null)), "gid"
      uid            = lookup(lookup(each.value, "posix_user", lookup(var.access_points_defaults, "posix_user", null)), "uid")
      # secondary_gids = local.secondary_gids[each.key] != null ? split(",", local.secondary_gids[each.key]) : null
    }
  }

  root_directory {
    path = "/${each.key}"

    dynamic "creation_info" {
      for_each = null != lookup(each.value, "creation_info", lookup(var.access_points_defaults, "creation_info", null)) ? [1] : []

      content {
        owner_gid   = lookup(lookup(each.value, "creation_info", lookup(var.access_points_defaults, "creation_info", null)), "owner_gid")
        owner_uid   = lookup(lookup(each.value, "creation_info", lookup(var.access_points_defaults, "creation_info", null)), "owner_uid")
        permissions = lookup(lookup(each.value, "creation_info", lookup(var.access_points_defaults, "creation_info", null)), "permissions"
      }
    }
  }

  tags = var.tags
}

# module "security_group" {
#   source  = "cloudposse/security-group/aws"
#   version = "1.0.1"

#   enabled                       = local.security_group_enabled
#   security_group_name           = var.security_group_name
#   create_before_destroy         = var.security_group_create_before_destroy
#   security_group_create_timeout = var.security_group_create_timeout
#   security_group_delete_timeout = var.security_group_delete_timeout

#   security_group_description = var.security_group_description
#   allow_all_egress           = true
#   rules                      = var.additional_security_group_rules
#   rule_matrix = [
#     {
#       source_security_group_ids = local.allowed_security_group_ids
#       cidr_blocks               = var.allowed_cidr_blocks
#       rules = [
#         {
#           key         = "in"
#           type        = "ingress"
#           from_port   = 2049
#           to_port     = 2049
#           protocol    = "tcp"
#           description = "Allow ingress EFS traffic"
#         }
#       ]
#     }
#   ]
#   vpc_id = var.vpc_id

#   context = module.this.context
# }

# module "dns" {
#   source  = "cloudposse/route53-cluster-hostname/aws"
#   version = "0.12.2"

#   enabled  = local.enabled && length(var.zone_id) > 0
#   dns_name = var.dns_name == "" ? module.this.id : var.dns_name
#   ttl      = 60
#   zone_id  = try(var.zone_id[0], null)
#   records  = [local.dns_name]

#   context = module.this.context
# }

# resource "aws_efs_backup_policy" "policy" {
#   count = module.this.enabled ? 1 : 0

#   file_system_id = join("", aws_efs_file_system.default.*.id)

#   backup_policy {
#     status = var.efs_backup_policy_enabled ? "ENABLED" : "DISABLED"
#   }
# }