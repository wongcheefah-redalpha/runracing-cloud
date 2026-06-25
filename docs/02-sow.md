# Statement of Work — Real-Time Multiplayer Racing Game Cloud Backend

- **Client:** Game studio ("GC") — 15 Unity developers, 2 incoming DevOps engineers
- **Prepared by:** Cloud consulting team ("CA")
- **Date:** 2026-06-25
- **Version:** 1.0 (Draft for client review)
- **Basis:** This SOW is built entirely on the requirements and decisions in
  [01-requirements-and-architectural-implications.md](01-requirements-and-architectural-implications.md).
  Requirement IDs (BR/FR/NFR/DR/SC) and decision IDs (D-1…D-18) are cited inline for traceability.

---

## 1. Executive summary

GC is launching its first title — a real-time, 8-player multiplayer mobile racing game on iOS and
Android — within an investor-mandated 8-month window (BR-1, BR-2). The game must support at least
100,000 concurrent players at launch in North America and Europe, expand to Asia within six months,
and deliver a crisp, low-latency experience that differentiates it from laggy competitors (BR-3,
BR-5, BR-7). GC's current Unity built-in networking does not scale, and the team is new to cloud
operations.

This engagement delivers a scalable, secure, multi-region cloud backend on **AWS** (D-1), using
managed services wherever possible so a small, cloud-new team can operate it within the timeline.
Real-time match hosting runs on **Amazon GameLift** (D-2); player and game data on **DynamoDB**
with a residency-aware data model (D-11); analytics on an **S3 + Athena** lake with a streaming
path for cheat detection (D-5, D-9). The whole platform is defined in Terraform (D-4) on a
greenfield AWS Organization landing zone (D-10), shipped through GitHub Actions CI/CD (D-13).

The design targets 99.9% uptime (NFR-1), active-active disaster recovery with a 5-minute RTO
(D-12), and server-side p95 latency under 50 ms (D-8), while staying cost-aware by treating 100,000
concurrent players as an autoscaled peak rather than a sustained load (D-3). Compliance with GDPR
and COPPA is designed in from the start (SC-1, SC-2, D-14, D-18). The single most important
commercial caveat is the tension between the first-year cloud budget of $200,000 and the cost of
serving ~1M DAU across multiple regions; this is addressed in Section 8 and tracked as a primary
risk.

---

## 2. Scope

### 2.1 In scope

- Multi-region AWS cloud backend for the racing game: networking, security, compute, storage, data,
  and analytics (covers FR-1…FR-12, NFR-1…NFR-9, DR-1…DR-5, SC-1…SC-6).
- Real-time game-server hosting and skill/latency matchmaking on Amazon GameLift (FR-1, FR-2, D-2).
- Player identity, profiles, leaderboards, stats, and entitlements (FR-3, FR-4, FR-5, DR-1, DR-2).
- Payments integration backend: native store billing plus Stripe, storing tokens/receipts only
  (FR-6, D-6, D-17).
- Replay and asset storage with CDN, designed to support future replay sharing and ghost races
  (FR-7, DR-3).
- Analytics pipeline (engagement, monetization, balance) and real-time cheat/anomaly detection
  (FR-8, FR-9, FR-10, D-5, D-9).
- Secure customer-support data APIs for Zendesk integration (FR-11).
- Greenfield AWS Organization / Control Tower landing zone with dev, staging, production, and beta
  environments (D-10, NFR-9, FR-12).
- Infrastructure as Code in Terraform: a full multi-region production stack plus a single-region
  deployable demo (D-4).
- CI/CD with GitHub Actions and blue-green / per-region rollout (D-13, NFR-7).
- Observability, alerting, and operational runbooks; knowledge transfer to GC's DevOps team
  (NFR-8, D-16).
- Internationalization-ready architecture (languages delivered post-launch) (D-15).

### 2.2 Out of scope

- Unity game-client development, gameplay logic, art, and the 120 fps client target (client-side;
  A-4).
- Game design, level/track design, and content authoring.
- Translation/localization content production (architecture is provided; languages are delivered
  later — D-15).
- Marketing and user-acquisition campaigns.
- In-product machine learning / AI features; the project's "AI" is AI-assisted delivery, not an
  in-game ML feature (D-9, scope note in the requirements doc).
- Procurement and contracts for third-party services (Stripe, parental-consent vendor, Zendesk,
  Datadog/New Relic).
- Recruitment and staffing of the SRE team (GC hires; CA advises — D-16).

---

## 3. Business objectives

| Objective | Target / success metric | Source |
| --- | --- | --- |
| Launch the first title on time | Production launch within 8 months | BR-2 |
| Support launch-scale concurrency | >= 100,000 concurrent players (autoscaled peak) | BR-3, D-3 |
| Differentiate on latency | Server-side p95 < 50 ms in-region; ~3 s in-race reconnect grace | D-8 |
| High availability | >= 99.9% uptime; RTO 5 min, RPO 0 financial / <= 5 min game state | NFR-1, D-12 |
| Global reach | Launch NA + EU; Asia within 6 months | BR-7 |
| Rapid, low-risk releases | Weekly content + monthly feature releases, minimal downtime | NFR-7 |
| Cost discipline | Operate toward the first-year cloud budget (see Section 8 caveat) | BR-6, D-3 |
| Regulatory compliance | GDPR and COPPA satisfied at launch | SC-1, SC-2, D-14, D-18 |
| Data-driven operations | KPI dashboards (DAU/MAU, ARPU, retention, match completion) and cheat detection | FR-8, FR-9, FR-10 |

---

## 4. Technical solution

### 4.1 Architecture overview

The platform is a multi-region, active-active AWS architecture. Players connect from iOS/Android
clients through a global edge layer to region-local backend services and GameLift game-server
fleets placed close to players to minimize latency. Shared platform services (identity, profiles,
payments, analytics) are reused across GC's planned future titles (BR-1). Launch regions are one in
North America and one in Europe, with an Asia-Pacific region added at expansion (BR-7); the data
model is residency-aware so EU player PII stays in the EU (D-11).

Request flow at a high level:

1. The client resolves the nearest healthy region via Amazon Route 53 latency-based routing to the
   regional API Gateway; game-session placement across regional fleets uses GameLift FlexMatch.
2. Static content, game assets, and replays are served through Amazon CloudFront; AWS WAF and
   Shield protect public endpoints (SC-6).
3. Authenticated API traffic terminates at Amazon API Gateway and is handled by regional backend
   services (Lambda and/or containers).
4. Matchmaking (GameLift FlexMatch) groups players by skill and latency, then places sessions on
   GameLift fleets; the race runs on the dedicated game server.
5. Game and player state is read/written to DynamoDB and ElastiCache; gameplay/telemetry events are
   streamed to the analytics and cheat-detection pipelines.

### 4.2 Core components (AWS services)

| Capability | AWS service | Notes / decision |
| --- | --- | --- |
| Global routing / failover | Route 53 (latency routing) | Nearest-region API routing + active-active failover (NFR-5, D-12) |
| Edge / CDN | CloudFront | Assets, game updates, replay delivery (FR-7, DR-3) |
| Edge security | WAF, Shield | DDoS and L7 protection for public endpoints (SC-6) |
| Game servers | Amazon GameLift (Spot + on-demand) | Managed session hosting, autoscaling (FR-2, D-2) |
| Matchmaking | GameLift FlexMatch | Skill- and latency-based (FR-1) |
| Identity / auth | Amazon Cognito | Email/password + social; age gate + parental consent (FR-3, D-14) |
| API layer | API Gateway + Lambda (containers where needed) | Stateless, autoscaled backend services (BR-4) |
| Operational data | DynamoDB | Global tables for non-PII; region-scoped PII (FR-5, NFR-6, D-11) |
| Low-latency cache | ElastiCache (Redis) | Leaderboards (sorted sets), session state (FR-4) |
| Object storage / lake | S3 | Replays (30-day lifecycle), assets, analytics lake (DR-3, DR-4) |
| Payments | Native store billing + Stripe | Tokens/receipts/entitlements only (FR-6, D-6, D-17) |
| Event streaming | Kinesis Data Streams / Firehose | Telemetry ingestion (FR-8, FR-9) |
| Real-time analytics | Managed Service for Flink + Lambda | Rules + statistical cheat detection (FR-9, D-9) |
| Warehouse / query | Athena + Glue Data Catalog | Athena now; Redshift Serverless later (FR-8, D-5) |
| Dashboards | QuickSight and/or Grafana | KPI and ops dashboards (FR-10) |
| Support APIs | API Gateway + Lambda, CloudTrail | Least-privilege Zendesk data access, audited (FR-11) |
| Observability | CloudWatch, X-Ray, Datadog/New Relic | APM, alerting, automated remediation (NFR-8) |
| Secrets / keys | Secrets Manager, KMS | Encryption and credential management (SC-3) |
| Landing zone | Control Tower, AWS Organizations | Multi-account, SCP guardrails (D-10, NFR-9) |
| CI/CD | GitHub Actions + OIDC | Blue-green, per-region rollout (D-13, NFR-7) |

### 4.3 Multi-region and data strategy

DynamoDB is the primary operational store. Non-PII, latency-sensitive data (matchmaking metadata,
leaderboards, session state) uses global tables for multi-region, multi-active access; player PII
(profiles, payment references, entitlements, consent records) is region-scoped to the player's home
region and is not replicated across regions, satisfying both NFR-6 ("globally distributed database")
and EU residency (SC-1, D-11). Replays and analytics data live in regional S3 buckets; the analytics
lake keeps de-identified/aggregated data to limit PII spread (DR-4, D-18).

### 4.4 Scaling and cost optimization

100,000 concurrent players is treated as an autoscaled peak over a low baseline, not a sustained
load (D-3). GameLift fleets use Spot capacity with on-demand fallback and scale toward zero in
off-peak windows; DynamoDB uses on-demand or autoscaling capacity; backend services are stateless
and horizontally scaled (BR-4, NFR-4). Autoscaling limits and quotas are sized to burst to 5x the
100,000 peak for seasonal/viral events (D-12). Cost guardrails include budget alarms, Savings Plans
for steady baseline, and S3 lifecycle/tiering for replays and cold analytics (BR-6).

### 4.5 Environments, CI/CD, and operations

A greenfield AWS Organization with a Control Tower landing zone provides separate dev, staging,
production, and beta accounts with baseline SCP guardrails (D-10, NFR-9). The beta environment
mirrors production at limited capacity for the 10,000-tester program (FR-12). CI/CD runs on GitHub
Actions authenticating to AWS via OIDC (no static keys), using blue-green deployments and gradual
per-region rollout during low-traffic windows, with automated rollback (D-13, NFR-7).

### 4.6 Analytics and anti-cheat

Game-client and server events are ingested through Kinesis into the S3 data lake for batch/interactive
analysis with Athena and Glue, feeding KPI dashboards (FR-8, FR-10, D-5). A parallel real-time path
(Kinesis + Managed Service for Flink / Lambda) applies rules and statistical anomaly detection to flag
cheating and abnormal behavior at launch, with the pipeline designed so an ML model can be added later
without rework (FR-9, D-9).

---

## 5. Security and compliance

### 5.1 Identity and access

Amazon Cognito handles player authentication (email/password and social providers, configurable). A
neutral age gate runs at signup; under-13 players require third-party verifiable parental consent
(D-14, SC-2). Internal and support APIs enforce least-privilege IAM, and all access to player data is
audited via CloudTrail and application access logs (FR-11, SC-5).

### 5.2 Encryption and secrets

All data is encrypted at rest with AWS KMS and in transit with TLS 1.3 (SC-3). Credentials and API
keys are stored in AWS Secrets Manager. No static cloud credentials are used in CI/CD (OIDC, D-13).

### 5.3 GDPR

EU player PII is pinned to the EU region (D-11, SC-1). Data-subject export and erasure requests are
honored without undue delay and within one month of receipt, extendable by two further months for
complex requests with notice in the first month (D-18, verified against current GDPR Art. 12(3) /
Art. 17). Erasure removes data from active stores immediately, de-identifies analytics data, and lets
backups age out on their retention cycle with deletions re-applied on restore. A data map maintains
coverage across all stores.

### 5.4 COPPA

Age verification and verifiable parental consent gate under-13 accounts; data collection and processing
for minors is restricted, and consent records are retained (SC-2, D-14).

### 5.5 Payments and PCI

Monetization is a one-time game purchase plus in-app purchases for cosmetic add-ons; no subscription
(D-17). Payments are processed through native store billing and Stripe; the platform stores only
receipts, entitlements, and PSP tokens — never raw card data — keeping it out of full PCI-DSS scope
(FR-6, SC-4, D-6).

### 5.6 Network protection and account guardrails

Public endpoints are fronted by WAF and Shield (SC-6). The Control Tower landing zone applies baseline
Service Control Policies across the organization (D-10). Recommended baseline SCPs:

- Deny public S3 bucket access (block public ACLs/policies org-wide).
- Require encryption for S3 and EBS; deny creation of unencrypted resources.
- Require IMDSv2 on EC2 / GameLift fleet instances.
- Deny root-account access keys and enforce MFA for privileged roles.
- Restrict resource creation to approved regions (NA, EU, and APAC at expansion).
- Deny disabling of CloudTrail, AWS Config, and GuardDuty.

GC does not currently have an organization, so these are delivered as part of the greenfield landing
zone (D-10).

---

## 6. Timeline and milestones

Eight months, phased, with critical-path items (DevOps onboarding, GameLift/Unity integration,
compliance) started early. Durations are indicative and run with parallel workstreams.

| Phase | Duration | Key outputs |
| --- | --- | --- |
| 1. Discovery and architecture | Weeks 1-4 | Requirements (done), architecture + diagram, landing zone design, security/compliance plan |
| 2. Foundation | Weeks 4-8 | Control Tower org, networking, Terraform modules, CI/CD, observability baseline |
| 3. Core backend | Weeks 8-20 | Auth/profiles, matchmaking + GameLift fleets, leaderboards, payments backend, analytics pipeline |
| 4. Integration and hardening | Weeks 16-24 | Client/backend integration, multi-region active-active, DR drills, security testing |
| 5. Testing and beta | Weeks 24-30 | Load test to 100k CCU, 10,000-player beta, performance tuning, compliance validation |
| 6. Launch readiness and go-live | Weeks 30-34 | Production cutover, blue-green rollout, launch-readiness sign-off, runbooks/training |
| Post-launch | Weeks 34+ | Stabilization, Asia-region expansion prep, KPI review |

Key milestones: architecture sign-off (end of Phase 1), foundation/landing zone ready (end of Phase
2), feature-complete backend (end of Phase 3), 100k-CCU load test passed and beta complete (end of
Phase 5), compliance validated and go-live (Phase 6).

---

## 7. Risks and mitigations

| # | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| R-1 | First-year budget vs ~1M DAU multi-region cost (BR-6, D-3) | Budget overrun | Cost-optimized peak, Spot, scale-to-low, S3 lifecycle/tiering, budget alarms; reforecast early and escalate budget if needed (Section 8) |
| R-2 | p95 < 50 ms aggressive on mobile last-mile (D-8) | Missed latency target | Latency-based matchmaking caps match RTT; more regional points of presence; define as server-side RTT; validate under load and relax if needed |
| R-3 | Team new to cloud operations | Delivery/ops risk | Managed services, IaC, runbooks, training, and CA guidance; phased knowledge transfer |
| R-4 | SRE hiring timeline (D-16) | 24/7 readiness at launch | Phased on-call, interim CA guidance, automated remediation; track hiring against launch date |
| R-5 | GameLift Spot interruptions | Match disruption | On-demand fallback, baseline reserved capacity, session resilience and reconnect grace (NFR-2) |
| R-6 | GDPR/COPPA gaps for global minors | Legal/financial | Early legal engagement, consent vendor (D-14), data map and erasure SLA (D-18), audits |
| R-7 | 8-month timeline is aggressive (BR-2) | Schedule slip | Phased MVP, parallel workstreams, managed services, early critical-path starts |
| R-8 | 5x burst-event cost and cross-region transfer (D-12) | Cost spikes | Event-scoped autoscaling, traffic locality, monitor cross-AZ/region transfer; bursts are demand/revenue-driven |

---

## 8. Cost and budget

The first-year cloud-infrastructure budget is $200,000, i.e. roughly $16,700 per month on average
(BR-6). The figures below are rough order-of-magnitude monthly ranges for planning only; a detailed
model using AWS pricing data is a design-phase deliverable.

| Cost area | Low baseline (off-peak) | Notes |
| --- | --- | --- |
| Game compute (GameLift, Spot-heavy) | 4,000 - 12,000 | Scales toward zero off-peak; spikes during events |
| DynamoDB (global + region-scoped) | 2,000 - 5,000 | On-demand/autoscaling |
| ElastiCache (leaderboards/session) | 1,000 - 3,000 | |
| S3 storage (replays ~225 TB rolling + assets + lake) | 5,000 - 8,000 | Major driver; optimize via tiering, compression, retention (DR-3) |
| CloudFront + data transfer | 2,000 - 5,000 | Includes cross-region transfer |
| Streaming + analytics (Kinesis/Flink/Athena/Glue) | 1,000 - 3,000 | |
| Edge security, Cognito, API/Lambda, observability | 1,000 - 3,000 | WAF/Shield, CloudWatch, etc. |
| Indicative monthly total (low baseline) | ~16,000 - 39,000 | Multi-region overhead adds ~20-40% |

Finding: at ~1M DAU (D-7) across multiple regions, even a cost-optimized design tends toward or above
the $200,000/year ceiling at the low end, and well above it during 5x events. Replay storage is a
notable single driver. Recommendation: treat $200,000 as a baseline-only target and either (a)
increase the cloud budget in line with realized DAU, (b) reduce replay retention or apply
compression/tiering, or (c) accept higher, demand-driven spend during growth periods. This is tracked
as risk R-1 and was flagged in D-3.

---

## 9. Roles, operations, and support

Operations follow the client-staffed model: GC recruits the three shift SREs while CA provides
runbooks, training, on-call/automation tooling design, and architecture guidance alongside GC's two
incoming DevOps engineers (D-16, NFR-8). Observability uses CloudWatch and X-Ray with Datadog or New
Relic for unified APM, plus automated remediation for common faults.

Indicative support tiers (refined during operational design):

| Tier | Scope | Target initial response |
| --- | --- | --- |
| P1 critical | Outage, payment failure, security incident | 15 minutes, 24/7 |
| P2 high | Matchmaking failures, severe latency, auth problems | 1 hour, 24/7 |
| P3 standard | Non-blocking bugs, individual account issues | 4 business hours |
| P4 maintenance | Scheduled changes, optimizations | Next business day |

---

## 10. Deliverables

- This SOW (`/sow/SOW.md` plus PDF export).
- Architecture design and diagram (`/architecture/diagram.png`).
- Terraform code (`/terraform/`): full multi-region production stack and a single-region deployable
  demo, organized into modules (networking, security, compute, storage, data, etc.) (D-4).
- Validation evidence (endpoint availability, storage access, baseline security checks).
- `README.md` with setup and deployment instructions.
- Operational runbooks and knowledge-transfer materials (NFR-8, D-16).

The single-region demo is deployed live (us-east-1) via a least-privilege IAM deployer with
S3-locked remote state (D-19, D-20). It mirrors the production data plane and edge as closely as is
deployable; three components are documented but not instantiated (GameLift, Managed Flink,
QuickSight). The full command-by-command run and a resource inventory are in
[04-deployment-log.md](04-deployment-log.md); demo scope and deltas are in architecture Section 19.

---

## 11. Assumptions and traceability

This SOW inherits the assumptions recorded in the requirements document (Section 8 there), notably:

- auth methods (email/password plus social) are design-ready and to be confirmed (A-7).
- the $200,000 figure covers cloud infrastructure only (A-8).
- the studio is 15 developers plus 2 incoming DevOps engineers (A-9).

Full requirement-to-decision traceability (BR/FR/NFR/DR/SC and D-1…D-18) lives in
[01-requirements-and-architectural-implications.md](01-requirements-and-architectural-implications.md),
which is the controlling document if any detail here and there diverge.
