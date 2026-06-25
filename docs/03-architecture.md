# Architecture Design — Real-Time Multiplayer Racing Game Cloud Backend

- **Client:** Game studio ("GC")
- **Date:** 2026-06-25
- **Version:** 1.0 (Draft for technical review)
- **Companion artifacts:** diagram
  [runracing-multiregion-architecture.drawio](runracing-multiregion-architecture.drawio)
  (and `.png` / `.svg` exports); scope and commercials in [02-sow.md](02-sow.md).
- **Basis:** All choices trace to the decisions log (D-1…D-18) and requirement IDs (BR/FR/NFR/DR/SC)
  in [01-requirements-and-architectural-implications.md](01-requirements-and-architectural-implications.md),
  which is the controlling document if any detail here diverges.

---

## 1. Overview

The backend is a multi-region, active-active AWS platform serving real-time 8-player races to iOS
and Android clients. It launches in North America (us-east-1) and Europe (eu-west-1) and is built so
an Asia-Pacific region can be added without redesign (BR-7). Shared platform services (identity,
profiles, payments, analytics) are designed for reuse across GC's future titles (BR-1). The design
favors managed services so a cloud-new team can operate it within the 8-month timeline (BR-2, D-2).

Design principles:

1. Managed-first to minimize operational load (D-2, D-5).
2. Stateless, horizontally scalable backend; session state lives in the game servers and data stores
   (BR-3, BR-4).
3. Player-proximate compute for latency (BR-5, D-8).
4. Residency-aware data: PII region-scoped, non-PII globally replicated (D-11).
5. Everything in Terraform on a governed landing zone (D-4, D-10).

---

## 2. Network and multi-region topology

Each region runs an independent VPC spanning three Availability Zones for in-region high
availability (NFR-1). Global entry for the API uses Amazon Route 53 latency-based routing with
health checks to the regional API Gateway custom domains, so players reach the nearest healthy
region and fail over automatically (NFR-5, D-12). Game-session placement across regional fleets is
handled by GameLift FlexMatch queues rather than a network-layer accelerator. AWS Global Accelerator
is not used here; it would apply only if a service were fronted by an NLB/EIP.

| Layer | Placement | Notes |
| --- | --- | --- |
| Global ingress | Route 53 latency routing (+ health checks) | Nearest-region API routing and failover |
| Edge delivery | CloudFront + WAF + Shield | Static assets, game updates, replay delivery; DDoS/L7 (SC-6) |
| Public subnets | ALB/NLB (for any container services), interface endpoints | No game servers here (GameLift is managed) |
| Private subnets (3 AZs) | ElastiCache, in-VPC Lambda, optional ECS/Fargate | No inbound from internet |
| VPC endpoints | S3 + DynamoDB gateway endpoints; interface endpoints for KMS, Secrets Manager, Kinesis | Avoids NAT Gateway data-processing cost |

Cost note: S3 and DynamoDB are reached through free gateway VPC endpoints, and other AWS APIs
through interface endpoints, so NAT Gateways are minimized (a known cost trap). Cross-AZ chatter is
kept low by colocating tightly coupled services.

GameLift fleets run on AWS-managed game-server infrastructure (not inside the customer VPC); clients
connect directly to the assigned game server over UDP for low-latency gameplay.

---

## 3. Edge and content delivery

CloudFront fronts S3 for game assets, client updates, and replay downloads, giving players
edge-cached, low-latency access globally (FR-7, DR-3). AWS WAF (managed rule groups plus rate-based
rules) and AWS Shield protect public HTTP(S) endpoints (SC-6). The CloudFront origin is the regional
S3 bucket; signed URLs or signed cookies gate access to player-private replays.

---

## 4. Identity and authentication

Amazon Cognito user pools provide player identity (email/password and social providers; methods to
be confirmed, A-7). Auth flow:

1. Client authenticates with Cognito and receives short-lived JWTs.
2. A neutral age gate runs at first launch; under-13 players are routed to a third-party verifiable
   parental-consent flow (k-ID / PRIVO) before account activation (SC-2, D-14).
3. Backend APIs authorize requests using the Cognito JWT via API Gateway authorizers.

Consent records and minor-account flags are stored as PII in the player's home region (D-11). Device
transfer and account recovery are supported through Cognito flows (FR-3).

---

## 5. Game session services

Real-time hosting uses Amazon GameLift (D-2):

- **Game build:** Unity dedicated Linux server, deployed as a GameLift build/script and run on
  per-region fleets.
- **Matchmaking:** GameLift FlexMatch rule sets group up to 8 players by skill rating and reported
  client latency, within a latency cap that supports the p95 < 50 ms target (FR-1, D-8).
- **Placement:** GameLift queues place sessions on the lowest-latency healthy regional fleet.
- **Scaling:** target-tracking on available game sessions; Spot fleets with on-demand fallback;
  scheduled scale-down in off-peak windows; quotas sized to burst to 5x the 100k peak (D-3, D-12,
  NFR-4).
- **Resilience:** a ~3-second in-race reconnect grace lets a brief client drop rejoin without ending
  the race (NFR-2, D-8).

Session flow: client requests a match through the backend API -> backend submits a FlexMatch ticket
-> FlexMatch + GameLift place and start the session -> client receives the game-server endpoint and
connects directly over UDP.

---

## 6. Backend API services

Player-facing APIs (profiles, matchmaking tickets, leaderboards, entitlements, support hooks) run
behind Amazon API Gateway with AWS Lambda handlers; container services on ECS/Fargate are used where
a long-lived or higher-throughput process fits better. Handlers are stateless and horizontally
scalable (BR-4), reading and writing the data stores in Section 7. In-VPC Lambdas (those needing
ElastiCache) use private subnets with VPC endpoints; the rest run outside the VPC for direct AWS API
access.

---

## 7. Data layer and data model

The primary store is Amazon DynamoDB. Per D-11, tables are split by residency:

| Table | Keys (PK / SK) | Replication | Class |
| --- | --- | --- | --- |
| Players (profile, stats, progression) | playerId / — | Region-scoped (home region) | PII |
| ConsentRecords (age, parental consent) | playerId / — | Region-scoped | PII |
| Entitlements (game + cosmetic IAP) | playerId / itemId | Region-scoped | PII-linked |
| PaymentRefs (PSP tokens, receipts) | playerId / txnId | Region-scoped | PII-linked |
| RaceHistory | playerId / raceTs | Region-scoped | PII-linked |
| MatchmakingMetadata | bucketId / ticketId | Global table | Non-PII |
| GameSessions | sessionId / — | Global table | Non-PII |
| Leaderboards (persisted) | seasonId / playerRef | Global table | Pseudonymous |

Notes:

- Non-PII, latency-sensitive data uses DynamoDB global tables (multi-region, multi-active) so either
  region can serve it (NFR-6). PII never leaves its home region (SC-1, D-11).
- Capacity is on-demand to absorb viral spikes without pre-provisioning (BR-4, D-3).
- We start with clear per-entity tables and well-chosen keys rather than a single-table design, which
  is powerful but easy to get wrong; single-table optimization can come later if access patterns
  demand it.
- **ElastiCache (Redis):** real-time leaderboards use Redis sorted sets for high-read, low-latency
  ranking (FR-4); periodic snapshots persist to the Leaderboards table.
- **Amazon S3:** race replays (~1 MB each) are written per race and expire on a 30-day lifecycle
  policy (DR-3); Intelligent-Tiering and compression manage the ~225 TB rolling footprint at ~1M DAU
  (D-7) and its cost (see SOW Section 8). A separate S3 data lake (Parquet, partitioned by date and
  region) backs analytics (DR-4).
- **Idempotency:** S3 event notifications and payment webhooks are at-least-once, so all consumers
  (replay ingestion, entitlement grants) are idempotent on a stable key.

---

## 8. Analytics and anti-cheat pipeline

Client and game-server events flow into a per-region streaming pipeline (FR-8, FR-9, FR-10, D-5,
D-9):

1. Events are ingested by Amazon Kinesis Data Streams.
2. A real-time branch runs Amazon Managed Service for Apache Flink applying rules and statistical
   anomaly detection for cheating/abnormal behavior; hits raise alerts via EventBridge/SNS and are
   written to a review store (FR-9).
3. A batch branch uses Kinesis Data Firehose to land events in the S3 data lake as partitioned
   Parquet.
4. AWS Glue catalogs the lake; Amazon Athena runs interactive and scheduled queries; Amazon
   QuickSight serves KPI dashboards (DAU/MAU, ARPU, retention, match completion, matchmaking time)
   (FR-10).

Athena now, with Redshift Serverless as a documented upgrade path if dashboard concurrency or
modeled-mart needs grow; the lake (S3) stays the source of truth so the upgrade is incremental
(D-5). PII is de-identified in the lake to limit erasure scope (D-18). The pipeline is anti-cheat
analytics only — no in-product ML platform at launch (D-9).

---

## 9. Payments and entitlements

Monetization is a one-time game purchase plus in-app purchases for cosmetic add-ons; no subscription
(D-17). Processing keeps the platform out of full PCI-DSS scope (D-6, SC-4):

- **Native store billing (Apple/Google):** the client completes the purchase; a Lambda performs
  server-side receipt validation and writes entitlements to DynamoDB.
- **Stripe (web/direct sales):** Stripe Checkout/PaymentIntents handle card data; the platform
  stores only Stripe customer and payment-method tokens and receipts. Stripe webhooks arrive at API
  Gateway -> Lambda, which verifies the signature and applies the entitlement idempotently.
- No raw card data (PAN) is ever stored (SC-4).

Financial records' source of truth is the PSP, which supports the RPO-0-for-financial-data target
through reconciliation (D-12).

---

## 10. Customer support integration

A dedicated internal support API (API Gateway + Lambda) lets Zendesk agents read player profile and
match history for issue investigation (FR-11). Access uses a least-privilege IAM role scoped to
support read patterns, and every data access is recorded via CloudTrail plus application-level access
logs for audit (SC-5). The API is private/authenticated and not exposed to players.

---

## 11. Security architecture

- **IAM:** least-privilege roles per service; no long-lived keys; CI/CD authenticates via GitHub
  OIDC to scoped deploy roles (D-13).
- **Encryption:** AWS KMS customer-managed keys for all data stores; TLS 1.3 in transit; mTLS for
  internal service-to-service where practical (SC-3).
- **Secrets:** Stripe keys and third-party credentials in AWS Secrets Manager.
- **Edge:** WAF managed + rate-based rules; Shield (SC-6).
- **Org guardrails (SCPs):** deny public S3, require encryption (S3/EBS), require IMDSv2, deny root
  access keys, restrict to approved regions, and deny disabling CloudTrail/Config/GuardDuty —
  applied through the Control Tower landing zone (D-10).
- **Threat detection:** GuardDuty, AWS Config, and CloudTrail enabled org-wide.

---

## 12. Observability and operations

CloudWatch (metrics, logs, alarms) and AWS X-Ray (tracing) provide native telemetry, with Datadog or
New Relic for unified APM across services (NFR-8). Core SLO dashboards: latency p95, uptime,
matchmaking time, error rate, GameLift fleet utilization, DynamoDB throttles, and cost. Alerts route
to an on-call tool (e.g., PagerDuty/Opsgenie); EventBridge-triggered Lambda runbooks provide
automated remediation for common faults. The operations model is client-staffed SREs with our
guidance and runbooks (D-16); 24/7 readiness depends on GC's SRE hiring (tracked risk).

---

## 13. Resilience and disaster recovery

The platform is active-active across NA and EU (NFR-5, D-12):

- **Traffic failover:** Route 53 latency records with health checks shift players to the healthy
  region within the 5-minute RTO; the stateless backend scales up in the survivor.
- **Non-PII data:** DynamoDB global tables are multi-active, so non-PII data is already present in
  both regions.
- **PII and residency tradeoff (important):** because EU PII is pinned to the EU (D-11), it is *not*
  replicated to NA. PII therefore has strong in-region availability (multi-AZ DynamoDB plus
  point-in-time recovery), but a *total* loss of a region is recovered within that same region, not
  by serving its PII from the other region. "Active-active" thus applies fully to gameplay and
  non-PII; PII is regionally highly available by design, not cross-region. This is the deliberate
  consequence of the residency decision and is called out so stakeholders accept the tradeoff.
- **RPO:** financial data RPO 0 via PSP reconciliation plus transactional writes; game-state RPO
  <= 5 minutes via streamed/snapshotted session state (D-12).
- **Backups:** DynamoDB PITR; S3 versioning/lifecycle; regular DR drills validate the RTO/RPO.

---

## 14. Scaling and capacity model

100k concurrent players is treated as a cost-optimized peak over a low baseline (D-3):

- GameLift fleets: target-tracking autoscaling, Spot-heavy with on-demand fallback, scheduled
  scale-down off-peak; service quotas raised to burst to 5x the 100k peak (D-12).
- DynamoDB on-demand; Lambda reserved concurrency on critical paths.
- Cost guardrails: AWS Budgets with alarms, Savings Plans for steady baseline, S3 lifecycle/tiering
  for replays and cold analytics (BR-6). The budget tension (Section 8 of the SOW) is the primary
  commercial risk.

---

## 15. Environments and landing zone

A greenfield AWS Organization with an AWS Control Tower landing zone provides governed,
multi-account isolation (D-10, NFR-9):

- Management account plus Security and Log Archive accounts.
- Workload accounts: dev, staging, production, and a limited-capacity beta account that mirrors
  production for the 10,000-tester program (FR-12).
- Baseline SCP guardrails (Section 11) applied across the organization.
- One parameterized Terraform codebase promotes the same modules across accounts and regions (D-4).

---

## 16. CI/CD and deployment

GitHub Actions drives CI/CD, authenticating to per-account deploy roles via OIDC (no static keys)
(D-13, NFR-7):

- Terraform plan/apply pipelines per environment.
- Blue-green for backend (Lambda aliases / weighted routing, or ECS blue-green) and GameLift (new
  fleet plus alias swap).
- Gradual per-region rollout during low-traffic windows, with automated rollback on alarm breach.
- Weekly content and monthly feature releases run through this path with minimal downtime (NFR-7).

---

## 17. Compliance mechanics

- **GDPR (SC-1, D-11, D-18):** self-service export and deletion; an erasure orchestration
  (Step Functions/Lambda) removes a player from Players, ConsentRecords, Entitlements, PaymentRefs,
  RaceHistory, and S3 replays, and triggers analytics de-identification. Requests are honored within
  one month (extendable by two months for complex cases). Backups age out on the PITR/lifecycle
  cycle with pending deletions re-applied on restore. A maintained data map ensures coverage.
- **COPPA (SC-2, D-14):** age gate plus third-party verifiable parental consent for under-13s;
  restricted data collection for minors; consent records retained.
- **Residency (D-11):** routing and account logic ensure EU players' PII is written to and read from
  eu-west-1 only; APAC PII pins to the APAC region at expansion.

---

## 18. Traceability

| Area | Requirements | Decisions |
| --- | --- | --- |
| Provider / regions | BR-7, NFR-6 | D-1, D-11 |
| Game hosting / matchmaking | FR-1, FR-2, NFR-2, NFR-3 | D-2, D-8 |
| Compute / API | BR-3, BR-4 | D-3 |
| Data model / storage | FR-4, FR-5, DR-1…DR-4 | D-7, D-11 |
| Payments | FR-6 | D-6, D-17 |
| Analytics / anti-cheat | FR-8, FR-9, FR-10 | D-5, D-9 |
| Support | FR-11 | — |
| Security / compliance | SC-1…SC-6 | D-11, D-14, D-18 |
| Reliability / DR | NFR-1, NFR-5 | D-12 |
| Scaling / cost | NFR-4, BR-6 | D-3, D-12 |
| Environments / IaC | NFR-7, NFR-9, FR-12 | D-4, D-10 |
| CI/CD / ops | NFR-7, NFR-8 | D-13, D-16 |

---

## 19. Deployable demo (single-region): scope, fidelity, and omissions

The single-region (us-east-1) demo (D-4) is deployed to validate the pattern end to end and mirrors
the production data plane and edge as closely as is deployable. It is deployed by a least-privilege
IAM user, not the account root (D-20), with remote state in S3 using native locking (D-19). Full
command-by-command evidence is in [04-deployment-log.md](04-deployment-log.md).

### Components deployed in the demo

| Layer | Resources |
| --- | --- |
| Networking | VPC, 2 public + 2 private subnets (2 AZs), IGW, 1 NAT gateway, S3 + DynamoDB gateway endpoints, security groups |
| Security | KMS customer-managed key + alias, Secrets Manager secret (payment placeholder) |
| Identity | Cognito user pool + app client |
| Data | DynamoDB players + leaderboards (CMK SSE, PITR), S3 replays/assets/data-lake, ElastiCache Redis (encryption at rest + in transit) |
| Compute | API Lambda (in VPC) + HTTP API Gateway + CloudWatch error alarm |
| Analytics | Kinesis stream, Firehose to the data lake, Glue database + crawler, Athena workgroup, consumer Lambda + event-source mapping |
| Edge | CloudFront distribution (OAC) + WAFv2 web ACL |

### Constraints and omissions (represented in the design, not instantiated)

| Component | Why not instantiated | Demo treatment |
| --- | --- | --- |
| GameLift fleet + FlexMatch | Requires the Unity dedicated-server build (a game binary) | Designed in Sections 5; not deployed |
| Managed Service for Apache Flink | Requires an application JAR artifact | The Kinesis **consumer Lambda** performs the real-time path |
| QuickSight dashboards | Requires an account-level QuickSight subscription (not cleanly Terraform-managed) | Glue + Athena provide the query layer; dashboards documented only |

### Demo-vs-production deltas (cost/scope simplifications)

- **Single region** (production: active-active multi-region with DynamoDB global tables, D-11/D-12).
- **One NAT gateway** (production: one per AZ for high availability).
- **ElastiCache single node** (production: multi-node with automatic failover).
- **Assets bucket uses SSE-S3** so CloudFront OAC can read it without a CloudFront-scoped KMS key
  policy; replays, data lake, DynamoDB, Kinesis, and Secrets use the CMK.
- **CloudWatch log groups use default encryption** (production: CMK with a logs-service key policy).
- **`force_destroy = true`** on demo buckets for clean teardown (production: `false` to protect data).

### Account prerequisite

The ElastiCache service-linked role (`AWSServiceRoleForElastiCache`) must exist in the account
(a one-time, per-account setup), and is created outside the stack.
