# Production Stack — Multi-Region Active-Active (design / code only)

This is the full production Terraform for the RunRacing backend (decision D-4): two
active-active regions (North America + Europe), Asia-ready, with global routing, global
tables, and edge. It is **validated but not deployed** (`terraform validate` passes); the
live, applied artifact is the single-region demo under [../demo/terraform/](../demo/terraform/).

## Topology

- **North America** (`us-east-1`, default provider) and **Europe** (`eu-west-1`, aliased
  provider `aws.eu`) each run a full regional stack. A third region (Asia) is added by
  copying a regional module block with a new provider alias.
- CloudFront and the CLOUDFRONT-scoped WAF live in `us-east-1` (the default provider).

## Layout

```text
terraform/
├── versions.tf      # providers + region aliases (na default, eu)
├── variables.tf     # regions, name_prefix, GameLift build location, domain
├── main.tf          # module "na", module "eu", module "edge", module "global"
├── outputs.tf
└── modules/
    ├── regional_stack/   # one active-active region: reuses the demo modules + GameLift
    ├── gamelift/         # build + fleet + alias + session queue (production-only)
    └── global/           # Route 53 latency routing + non-PII DynamoDB global tables
```

The regional stack **reuses the demo modules** (`../demo/terraform/modules/{networking,
security,data,compute,analytics,edge}`) via relative module sources, so the demo and
production share one set of module designs.

## What it provisions

- **Per region:** VPC (multi-AZ, NAT, gateway endpoints), KMS CMK, Cognito, DynamoDB
  (region-scoped PII: players + leaderboards), ElastiCache Redis, S3 (replays/assets/data
  lake), VPC-bound API Lambda + HTTP API Gateway, the analytics pipeline (Kinesis ->
  Firehose -> data lake + Glue + Athena + consumer Lambda), and GameLift (build, fleet,
  alias, session queue).
- **Global:** Route 53 latency-based routing to the regional APIs; DynamoDB **global
  tables** for non-PII data (sessions, matchmaking) per D-11/NFR-6; CloudFront + WAF over
  the NA assets bucket.

## Constraints and provider gaps (production-specific)

- **FlexMatch matchmaking** (`aws_gamelift_matchmaking_rule_set` /
  `aws_gamelift_matchmaking_configuration`) is **not supported by the Terraform AWS
  provider**. The fleet/alias/queue are managed here; the rule set + matchmaking
  configuration are provisioned out-of-band (AWS CLI/SDK or CloudFormation) and target the
  queue. The 8-player team and skill/latency rules are designed in
  [../docs/03-architecture.md](../docs/03-architecture.md).
- **GameLift build** requires the Unity dedicated-server zip; set
  `gamelift_build_s3_bucket`, `gamelift_build_s3_key`, and `gamelift_build_role_arn` before
  apply.
- **Managed Service for Apache Flink** (real-time cheat detection) needs an application
  JAR; the consumer Lambda in the analytics module stands in, as in the demo.
- **QuickSight** dashboards need an account subscription and are not Terraform-managed.
- **Route 53** records point at the regional API hostnames to express latency routing;
  production fronts each region with an API Gateway custom domain.
- **Global Accelerator** is not included: the HTTP API uses Route 53 latency routing and
  GameLift uses native session placement; GA applies to NLB/EIP-fronted endpoints if added.

## Validate

```bash
cd terraform
terraform init -backend=false
terraform validate
```

## Deploy (not performed here)

Deployment requires: GameLift build variables set; a remote state backend and credentials;
acceptance of multi-region, always-on cost (NAT per region, ElastiCache, CloudFront,
two full regional stacks). Then:

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

All decisions (D-1..D-20) with justifications are in
[../docs/01-requirements-and-architectural-implications.md](../docs/01-requirements-and-architectural-implications.md).
