# RunRacing Games — Cloud Backend

Cloud architecture and infrastructure-as-code for a real-time, 8-player multiplayer
mobile racing game backend on AWS. This repository is the full lifecycle artifact:
requirements, a Statement of Work, an architecture design with diagram, and working
Terraform with a live-validated deployment.

## Repository layout

```text
runracing-cloud/
├── README.md                      # this file
├── transcript/
│   └── Team 4 - project.txt       # authoritative CA<->GC discovery transcript (source of truth)
├── docs/
│   ├── 01-requirements-and-architectural-implications.md   # requirements + decisions log (D-1..D-20)
│   ├── 02-sow.md                                           # Statement of Work
│   ├── 02-sow.pdf                                          # Statement of Work (PDF export)
│   ├── 03-architecture.md                                  # architecture design (incl. demo scope/omissions)
│   ├── 04-deployment-log.md                                # clean-slate deploy run + resource inventory
│   ├── runracing-multiregion-architecture.drawio          # editable diagram source
│   ├── runracing-multiregion-architecture.drawio.png      # diagram (PNG)
│   ├── runracing-multiregion-architecture.drawio.svg      # diagram (SVG)
│   ├── runracing-production-multiregion-architecture.drawio      # detailed production diagram (source)
│   ├── runracing-production-multiregion-architecture.drawio.png  # detailed production diagram (PNG)
│   └── runracing-production-multiregion-architecture.drawio.svg  # detailed production diagram (SVG)
├── demo/
│   └── terraform/                 # the deployed single-region demo stack
│       ├── bootstrap/             # remote state backend (S3 bucket; run once)
│       ├── modules/               # networking, security, identity, data, compute, analytics, edge
│       ├── envs/demo/             # the single-region (us-east-1) demo composition
│       └── logs/                  # captured deployment/validation logs
└── terraform/                     # full multi-region production stack (validated, not deployed)
    ├── README.md                  # production-stack guide: topology, provider gaps, deploy steps
    ├── main.tf, versions.tf, ...  # NA + EU regional stacks, edge, global
    └── modules/                   # regional_stack, gamelift, global (reuses demo modules)
```

The full **multi-region active-active production** stack (decision D-4) is in
[`terraform/`](terraform/) — it passes `terraform validate` but is **not deployed**. It reuses
the demo modules per region via provider aliases and adds production-only modules (`gamelift`,
`global` for Route 53 routing + DynamoDB global tables). See
[`terraform/README.md`](terraform/README.md) for topology, provider gaps (e.g. FlexMatch), and
how it maps to the architecture.

## Deliverables — where to find them

| Deliverable | Location |
| --- | --- |
| Scope of Work (SOW) | [docs/02-sow.md](docs/02-sow.md) and PDF export [docs/02-sow.pdf](docs/02-sow.pdf) |
| Architecture design | [docs/03-architecture.md](docs/03-architecture.md) |
| Architecture diagram | [docs/runracing-multiregion-architecture.drawio.png](docs/runracing-multiregion-architecture.drawio.png) (editable [.drawio](docs/runracing-multiregion-architecture.drawio), vector [.svg](docs/runracing-multiregion-architecture.drawio.svg)) |
| Architecture diagram — detailed production (multi-region active-active, both regions) | [docs/runracing-production-multiregion-architecture.drawio.png](docs/runracing-production-multiregion-architecture.drawio.png) (editable [.drawio](docs/runracing-production-multiregion-architecture.drawio), vector [.svg](docs/runracing-production-multiregion-architecture.drawio.svg)) |
| Requirements + decisions log (D-1..D-20) | [docs/01-requirements-and-architectural-implications.md](docs/01-requirements-and-architectural-implications.md) |
| Deployment log, validation evidence, resource inventory | [docs/04-deployment-log.md](docs/04-deployment-log.md) |
| Terraform — deployed/validated single-region demo | [demo/terraform/](demo/terraform/) |
| Terraform — full multi-region production stack (validated, not deployed) | [terraform/](terraform/) ([README](terraform/README.md)) |
| Setup / deploy instructions | this file (see Deploy / Validate / Tear down below) |

Mapping to the exercise's expected submission layout: `/sow/SOW.md` + PDF -> `docs/02-sow.*`;
`/architecture/diagram.png` -> `docs/runracing-multiregion-architecture.drawio.png`;
`/terraform/` -> `demo/terraform/` (deployed) and `terraform/` (production); `/README.md` -> this file.

## What the demo deploys

A production-like single-region (us-east-1) backend (70 resources): VPC with public/private
subnets across 2 AZs, NAT gateway, and S3/DynamoDB gateway endpoints; a KMS customer-managed
key and Secrets Manager; Cognito; DynamoDB (players + leaderboards) and ElastiCache Redis; S3
(replays, assets, data lake); a VPC-bound API Lambda behind an HTTP API Gateway; a telemetry
pipeline (Kinesis -> Firehose -> data lake, plus a consumer Lambda) with Glue and Athena; and
a CloudFront distribution fronted by AWS WAF. See `docs/03-architecture.md` Section 19 for the
component list and the deliberate demo-vs-production deltas.

### Constraints and omissions

Three production components are designed but not instantiated in the demo because they need
external artifacts or subscriptions: **GameLift** (Unity dedicated-server build), **Managed
Service for Apache Flink** (application JAR — a consumer Lambda stands in), and **QuickSight**
(account subscription). Details in `docs/03-architecture.md` Section 19 and `docs/04-deployment-log.md`.

## Prerequisites

- Terraform >= 1.5 and AWS CLI v2.
- AWS credentials for the target account. The demo was deployed with a dedicated
  least-privilege IAM user (`runracing-deployer`), never the account root (decisions D-10, D-20).
  Use that profile or equivalent permissions.
- The ElastiCache service-linked role must exist once per account:

  ```bash
  aws iam create-service-linked-role --aws-service-name elasticache.amazonaws.com
  ```

- The S3 state bucket name in `demo/terraform/envs/demo/backend.tf` is account-specific
  (`runracing-tfstate-<account-id>`); change it for a different account.

## Deploy

State locking uses native S3 locking (`use_lockfile`, D-19) — no DynamoDB lock table.

```bash
export AWS_PROFILE=runracing-deployer AWS_REGION=us-east-1

# 1. One-time: create the remote state backend (S3 bucket)
cd demo/terraform/bootstrap
terraform init
terraform apply

# 2. Deploy the demo stack
cd ../envs/demo
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Key outputs include `api_health_url`, `cloudfront_domain`, the table/bucket names, and the
Redis endpoint (`terraform output`).

## Validate

```bash
# Endpoint + storage + streaming + secrets, end to end:
curl -s "$(terraform output -raw api_health_url)"
# Expect: {"status":"ok",...,"checks":{"dynamodb":"ok","s3":"ok","kinesis":"ok","secrets":"ok",...}}
```

A full validation transcript (encryption posture, public-access blocks, WAF, ElastiCache
encryption, CloudFront over TLS) and the resource inventory are in `docs/04-deployment-log.md`.

## Tear down

```bash
cd demo/terraform/envs/demo
AWS_PROFILE=runracing-deployer terraform destroy -auto-approve
```

Demo S3 buckets use `force_destroy = true`, so teardown removes them without manual emptying.
To also remove the state backend, destroy the `bootstrap` stack (its bucket is versioned and
must be emptied first).

## Decisions and traceability

All architecture, tooling, and scope decisions (D-1..D-20) — with justifications and revisit
triggers — are in `docs/01-requirements-and-architectural-implications.md`, which is the
controlling document if any detail elsewhere diverges.
