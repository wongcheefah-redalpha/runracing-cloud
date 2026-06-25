# GameLift module (production): build, fleet, alias, FlexMatch matchmaking, and a
# game-session queue (FR-1, FR-2, D-2). The build references a Unity dedicated-server
# zip in S3 (provided via variables) - the one production component that cannot be
# instantiated without that artifact (see Constraints & Omissions).

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_gamelift_build" "server" {
  name             = "${var.name_prefix}-build"
  operating_system = "AMAZON_LINUX_2023"
  version          = var.build_version

  storage_location {
    bucket   = var.build_s3_bucket
    key      = var.build_s3_key
    role_arn = var.build_role_arn
  }
}

resource "aws_gamelift_fleet" "racing" {
  name              = "${var.name_prefix}-fleet"
  build_id          = aws_gamelift_build.server.id
  ec2_instance_type = var.instance_type
  fleet_type        = "ON_DEMAND" # production also uses SPOT fleets for cost (D-3)

  runtime_configuration {
    server_process {
      concurrent_executions = var.concurrent_sessions_per_host
      launch_path           = "/local/game/RunRacingServer"
    }
  }

  ec2_inbound_permission {
    from_port = 7777
    to_port   = 7797
    ip_range  = "0.0.0.0/0"
    protocol  = "UDP"
  }
}

resource "aws_gamelift_alias" "racing" {
  name        = "${var.name_prefix}-alias"
  description = "Active fleet alias for blue-green fleet swaps"

  routing_strategy {
    type     = "SIMPLE"
    fleet_id = aws_gamelift_fleet.racing.id
  }
}

resource "aws_gamelift_game_session_queue" "racing" {
  name               = "${var.name_prefix}-queue"
  destinations       = [aws_gamelift_alias.racing.arn]
  timeout_in_seconds = 60
}

# NOTE: FlexMatch matchmaking (rule set + configuration) is intentionally NOT defined
# here. The Terraform AWS provider does not offer aws_gamelift_matchmaking_rule_set or
# aws_gamelift_matchmaking_configuration resources (a known provider gap). In production
# these are provisioned out-of-band (AWS CLI/SDK or CloudFormation) and target the queue
# above; the 8-player team and skill/latency rules are designed in docs/03-architecture.md.
