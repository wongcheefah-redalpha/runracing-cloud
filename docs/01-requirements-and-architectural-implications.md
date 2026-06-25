# Requirements & Architectural Implications

- **Project:** Real-time multiplayer mobile racing game — cloud backend
- **Client:** Game studio ("GC"); Consultant ("CA")
- **Document purpose:** Extract every business/technical requirement from the discovery
  conversation and state the architectural implication of each, so the architecture design,
  SOW, and Terraform that follow are traceable to a real client statement.
- **Status:** Draft for client review — contains open questions (see §9).

---

## 0. Decisions log

Every decision is traceable to a requirement or open question and carries an explicit
justification. "Revisit trigger" states the condition under which
a decision should be reopened.

### D-1 — Cloud provider = AWS

- **Resolves:** Q1.
- **Decision:** Build on AWS as the single cloud provider for the architecture and Terraform.
- **Justification:** Every non-AWS service named in the transcript has a clean AWS equivalent
  (Cosmos DB to DynamoDB global tables; Google Cloud game servers to GameLift; BigQuery/Snowflake
  to Athena/Redshift; Datadog/New Relic remain usable on AWS), and two named services (GameLift,
  DynamoDB) are already AWS. One provider means one IAM, networking, compliance, and billing
  boundary — decisive for a 2-person DevOps team new to cloud and for a clean, single-provider
  Terraform deliverable. A second control plane would multiply governance and GDPR/COPPA surface.
- **Revisit trigger:** A committed multi-cloud strategy, or a needed capability with no adequate
  AWS equivalent.

### D-2 — Game-server hosting = Amazon GameLift (managed)

- **Resolves:** Q2.
- **Decision:** Host real-time game servers on Amazon GameLift with FlexMatch matchmaking.
- **Justification:** The studio is new to cloud with no Kubernetes experience, against an 8-month
  deadline. GameLift provides managed session placement, fleet autoscaling, Spot support, and
  skill-plus-latency matchmaking out of the box. Self-managed Agones on EKS would impose Kubernetes
  operational load the team cannot absorb in the timeline.
- **Revisit trigger:** Dedicated platform/Kubernetes expertise in-house, or a per-unit cost ceiling
  managed hosting cannot meet at scale.

### D-3 — Treat 100k CCU as a cost-optimized peak

- **Resolves:** Q4.
- **Decision:** Design for 100k concurrent players as a burst over a low baseline — aggressive
  autoscaling, Spot game-server fleets, scale-to-low in off-peak — rather than as sustained load.
- **Justification:** ~12,500 concurrent 8-player sessions at sustained 100k CCU across multiple
  regions 24/7 implies hundreds-to-thousands of game-server instances and would exceed the
  $200k/year infra budget on game compute alone (sustained game-server fleets at that scale
  annualize well past $1M). Modeling 100k as a peak keeps year-one infra within budget. The sustained-load option
  is preserved as a SOW risk requiring a larger budget.
- **Revisit trigger:** Confirmed sustained demand near 100k CCU, or a budget increase.

### D-4 — Two Terraform/IaC deliverables

- **Resolves:** Q16.
- **Decision:** Deliver (a) the full multi-region active-active production design plus its Terraform
  stack, and (b) a single-region deployment demo that actually stands up and validates.
- **Justification:** The exercise requires working, validatable Terraform within time and cost. The
  single-region demo proves the pattern and is demonstrable; the full multi-region stack is the
  production reference design. Splitting them avoids the cost and time of standing up full
  multi-region merely to demonstrate.
- **Revisit trigger:** Not applicable (deliverable structure).

### D-5 — Analytics warehouse = Amazon Athena now; Redshift Serverless as upgrade path

- **Resolves:** Q5.
- **Decision:** Use an S3 data lake queried by Amazon Athena for launch analytics. Keep real-time
  concerns out of the warehouse: cheat/anomaly detection and live counters go through Kinesis plus
  Managed Service for Flink; ops/technical metrics go through CloudWatch/Datadog and Grafana. Add
  Redshift Serverless later if warranted. Do not adopt Snowflake at this stage.
- **Justification:**
  - Athena is serverless with zero idle cost and queries the S3 lake (already the source of truth)
    in place. It is the lowest workload burden for a cloud-new 2-person DevOps team with no
    dedicated data engineer, and pay-per-query matches the cost-optimized philosophy (D-3). The only
    ongoing discipline is lake hygiene (Parquet, partitioning, compaction), which Firehose largely
    automates.
  - Athena's weakness (high-concurrency, sub-second interactive BI) does not bite, because the
    latency-sensitive paths are handled elsewhere: real-time cheat detection via streaming, live KPI
    dashboards via precomputed rollups, technical metrics via ops telemetry, and Zendesk support
    lookups (FR-11) against operational stores (DynamoDB / OpenSearch) rather than the warehouse.
  - Redshift Serverless is deferred, not rejected: it adds a second query engine to learn and tune
    for concurrency/performance benefits not yet needed. Because data stays in S3, adding it later
    (or Redshift Spectrum over the same lake) is incremental, not a migration.
  - Snowflake is not selected: although operationally light as a SaaS, it introduces a second
    control plane, a second GDPR/COPPA compliance boundary, separate billing/governance outside AWS
    cost tooling, and extra data-movement integration — net-new burden for a cloud-new team.
- **Revisit trigger (Redshift Serverless):** dashboard concurrency beyond internal users, stable
  modeled marts, dedicated data-engineering hires, or Athena query latency/cost pain on large joins.
- **Revisit trigger (Snowflake):** a committed multi-cloud strategy or a cross-org/marketplace
  data-sharing requirement.

### D-6 — Payments = native store billing + Stripe (tokens only)

- **Resolves:** Q3.
- **Decision:** Process in-app goods through native store billing (Apple App Store, Google Play);
  use Stripe (PSP) for any web/direct sales. Store only purchase receipts, entitlements, and PSP
  tokens — never raw card data.
- **Justification:** The app stores require their own billing for digital goods and handle card
  data; Stripe tokenization covers any direct sales. Storing tokens/receipts only keeps the platform
  out of full PCI-DSS scope (SC-4) while still satisfying FR-6 ("store player payment information").
- **Revisit trigger:** A requirement to store raw card data, or a payment channel neither the app
  stores nor Stripe can serve.

### D-7 — Planning scale = ~1M DAU / 3-5M registered, 100k peak CCU

- **Resolves:** Q6.
- **Decision:** Size storage, DynamoDB, and analytics for ~1M DAU and 3-5M registered players, with
  100k concurrent as the peak (D-3).
- **Justification:** Peak concurrency is typically ~5-10% of DAU, so 100k CCU implies ~1M DAU. This
  gives concrete sizing: replay store ~225 TB rolling (1M DAU x 7.5 races x 1 MB x 30-day
  retention), with DynamoDB and the analytics lake sized to match.
- **Revisit trigger:** Measured DAU/registered figures that diverge materially from this estimate.

### D-8 — Latency target = server-side p95 < 50 ms in-region, ~3 s reconnect grace

- **Resolves:** Q7.
- **Decision:** Design and load-test for server-side p95 < 50 ms within a player's region, with a
  ~3-second in-race reconnect grace so a brief drop does not end a race.
- **Justification:** A crisp competitive feel is the product's core differentiator (BR-5). Requires
  region-proximate game servers, latency-based matchmaking that caps match RTT, and additional
  regional points of presence.
- **Risk:** p95 < 50 ms end-to-end is aggressive on mobile, where last-mile variance alone can
  exceed it; the target is defined as server-side session RTT, and matchmaking must avoid matches
  that cannot meet it. Carry as a SOW risk and validate under load.
- **Revisit trigger:** Load tests showing the target is unattainable on target mobile networks.

### D-9 — Cheat detection = streaming rules now, ML deferred; project "AI" = AI-assisted delivery

- **Resolves:** Q9.
- **Decision:** Detect cheating/abnormal behavior with real-time streaming (Kinesis + Managed
  Service for Flink / Lambda) using rules and statistical anomaly detection at launch; defer any ML
  model. No in-product ML platform (e.g., SageMaker) at launch.
- **Justification:** This meets FR-9 without standing up an ML platform the cloud-new team would have
  to operate. Per client clarification, the exercise title "Cloud AI Infrastructure" refers to using
  AI to plan and deploy the infrastructure (this engagement), not an in-product AI feature — so no
  game-facing AI/ML is required beyond cheat detection.
- **Revisit trigger:** Cheat sophistication that rule/statistical detection cannot keep up with.

### D-10 — Landing zone = greenfield AWS Organization (Control Tower)

- **Resolves:** Q13.
- **Decision:** Build greenfield on a new AWS Organization with a Control Tower multi-account landing
  zone (separate dev, staging, production, and beta accounts) and baseline guardrails/SCPs.
- **Justification:** A clean multi-account baseline gives the strongest isolation and lets us apply
  the SOW's recommended SCP guardrails from day one — the right footing for a cloud-new team and the
  dev/staging/prod/beta separation (NFR-9, FR-12).
- **Revisit trigger:** A future need to integrate into another organization (e.g., acquisition).

### D-11 — Data residency = EU PII pinned to EU; per-region isolation

- **Resolves:** Q11 (residency portion).
- **Decision:** Keep EU player PII in the EU region (and APAC PII in APAC at expansion). Use DynamoDB
  global tables only for non-PII, latency-sensitive data (sessions, matchmaking, leaderboards);
  player PII (profiles, payment references) is region-scoped to the home region and not globally
  replicated.
- **Justification:** Strongest GDPR posture and the cleanest way to satisfy NFR-6's "globally
  distributed database" without spreading PII across regions. Reconciles NFR-6 with SC-1.
- **Related:** GDPR-deletion timeframe set by D-18 (1 month, extendable +2).
- **Revisit trigger:** A business need that genuinely requires cross-region PII.

### D-12 — DR & scaling targets = RTO 5 min, RPO 0 financial / ≤5 min state, plan 5× peak

- **Resolves:** Q8.
- **Decision:** Target RTO 5 minutes and RPO 0 for financial data / ≤5 minutes for game state, and
  size autoscaling/quotas to burst to 5× the 100k peak (up to ~500k CCU) for viral/seasonal events.
- **Justification:** Client needed to avoid downtime, hence aggressive recovery and burst-headroom
  targets (RTO 5 min; RPO 0 financial; 5× the 100k peak). Active-active multi-region (NFR-5) supports
  a 5-minute RTO; Spot fleets plus headroom handle 5× bursts.
- **Cost note:** 5× burst capacity and a tighter RTO raise peak-event and standing costs; bursts are
  demand-driven (and revenue-bearing), but flag the cost ceiling against D-3 in the SOW.
- **Revisit trigger:** 5× headroom or a 5-minute RTO proving cost-prohibitive in practice.

### D-13 — CI/CD = GitHub Actions with OIDC to AWS

- **Resolves:** Q15.
- **Decision:** Use GitHub Actions for CI/CD, authenticating to AWS via OIDC (no static IAM keys),
  driving blue-green and gradual per-region rollouts.
- **Justification:** The team is CI/CD-experienced; GitHub Actions with OIDC removes long-lived
  credentials (security) and integrates cleanly with the deployment model (NFR-7).
- **Revisit trigger:** The studio standardizing on a different platform (e.g., GitLab).

### D-14 — COPPA = age gate + third-party verifiable parental consent

- **Resolves:** Q10.
- **Decision:** Neutral age gate at signup; for under-13 players, verifiable parental consent via a
  specialist vendor (e.g., k-ID / PRIVO); restricted data collection/processing for minors; store
  consent records.
- **Justification:** Strongest COPPA posture with the least in-house compliance burden for a
  cloud-new team, and it keeps the under-13 audience (which the client expects) compliant rather than
  excluded.
- **Revisit trigger:** Vendor unavailability in a target market, or a decision to exclude under-13s.

### D-15 — Localization = i18n/CMS design-ready now, languages delivered post-launch

- **Resolves:** Q12.
- **Decision:** Put internationalization and a locale/content delivery architecture (externalized
  strings, locale assets via S3/CloudFront) in place at launch; add actual languages during/after the
  Asia expansion.
- **Justification:** Avoids translation/content scope pressure on the 8-month launch while making the
  Asia expansion a content exercise rather than a re-architecture. Matches the phased plan.
- **Revisit trigger:** A decision to launch multilingual on day one.

### D-16 — Operations model = client hires SREs; we advise

- **Resolves:** Q14.
- **Decision:** The client recruits and staffs the 3 shift SREs; we provide runbooks, training,
  on-call/automation tooling design, and architecture guidance alongside the 2 incoming DevOps
  engineers.
- **Justification:** The client's chosen model keeps recurring ops cost in-house and builds internal
  capability, consistent with upskilling the cloud-new team via our guidance.
- **Risk:** 24/7 coverage depends on the client's SRE hiring timeline — flag as a launch-readiness
  risk in the SOW.
- **Revisit trigger:** Hiring delays threatening 24/7 readiness for launch.

### D-17 — Monetization model = one-time game purchase + cosmetic IAP (no subscription)

- **Resolves:** Q3 (monetization-model sub-question).
- **Decision:** Monetization is a one-time purchase of the game plus in-app purchases for add-ons
  (e.g., limited-edition skins and other cosmetics). No subscription model.
- **Justification:** Matches the transcript (IAP, no subscription). Cosmetic-only IAP is the
  standard, low-risk monetization for competitive multiplayer (avoids pay-to-win). Processed via
  native store billing + Stripe (D-6); entitlements drive cosmetic ownership.
- **Revisit trigger:** A product decision to add subscriptions / battle-pass (the entitlement model
  already supports recurring grants).

### D-18 — GDPR data-subject request SLA = 1 month, extendable +2 months (Art. 12(3) / 17)

- **Resolves:** Q11 (deletion-timeframe sub-question).
- **Decision:** Honor erasure (Art. 17) and access/export requests **without undue delay and within
  one month of receipt**; may extend by **two further months** for complex or numerous requests,
  notifying the player within the first month. Provide self-service export/delete to meet this
  comfortably.
- **Justification:** Matches current GDPR — Art. 12(3) sets the one-month response window that
  applies to Art. 17 erasure (verified against gdpr-info.eu / ICO / EDPB, June 2026).
- **Implementation note:** Erase from active stores (DynamoDB profiles, S3 replays) on request;
  propagate to analytics by deleting/anonymizing PII (retain only de-identified/aggregated data);
  backups are excluded from active processing and age out on their retention cycle, with pending
  deletions re-applied on any restore. Note: US/California players may also fall under CCPA
  (45-day window) — confirm if US launch scope expands.
- **Revisit trigger:** A change in law, or expansion into a jurisdiction with a stricter window.

### D-19 — Terraform state locking = S3 native (use_lockfile), not DynamoDB

- **Resolves:** Implementation decision (state backend).
- **Decision:** Remote state in S3 with native S3 locking (`use_lockfile = true`); no DynamoDB
  lock table.
- **Justification:** The AWS provider deprecated the `dynamodb_table` lock parameter in favor of
  S3 conditional-write locking; this removes a resource and a service dependency. Validated in the
  demo deployment.
- **Revisit trigger:** Terraform dropping `use_lockfile` support (unlikely).

### D-20 — Live demo deployed via least-privilege IAM deployer; production-fidelity with documented omissions

- **Resolves:** Implementation decision (deploy approach).
- **Decision:** The single-region demo is deployed by a dedicated least-privilege IAM user
  (`runracing-deployer`), never the account root (D-10, SC). The demo mirrors the production data
  plane and edge as closely as is deployable. Three production components are represented but not
  instantiated because they need external artifacts/subscriptions: GameLift (Unity server build),
  Managed Service for Apache Flink (application JAR; a consumer Lambda stands in), and QuickSight
  (account subscription). See architecture Section 19 and the deployment log for the full list.
- **Justification:** Practices the "no root for daily operations" guardrail and maximizes
  production fidelity for the short-lived demo while being honest about non-instantiable parts.
- **Revisit trigger:** Availability of the game-server build, the Flink application, or a QuickSight
  subscription.

---

## 1. Sources & method

| Source | Role | How it is used |
| --- | --- | --- |
| `Team 4 - project.txt` (CA<->GC transcript) | **Authoritative** — the client's actual words | Every requirement below cites it. |
| `Cloud AI Infrastructure Project — Full Lifecycle Exercise.pdf` | Deliverable brief | Defines what we produce (SOW -> Architecture -> Terraform -> Validation) and the SOW section structure. |

> **Note on gaps.** Where this document relies on details the transcript never states (e.g., the
> exact scope of the $200k figure, the client's auth method, or client-side frame-rate targets),
> those are treated as **assumptions to confirm (§8)**, not requirements.

**Scope note on "AI".** Per client clarification, the exercise title "Cloud AI Infrastructure"
refers to using AI to plan and deploy the cloud infrastructure (this engagement), not an
in-product AI feature. The game needs no player-facing AI/ML beyond cheat detection (D-9).

---

## 2. Requirements legend

- **ID prefixes:** `BR` business, `FR` functional, `NFR` non-functional, `DR` data,
  `SC` security/compliance. (Operational concerns are captured within NFR-7/8/9.)
- **Source:** "T" = stated in transcript; "T(CA)" = proposed by us and accepted/unchallenged
  by the client; "E" = exercise brief.
- Architectural implications below use **AWS** service names: provider is **confirmed as AWS**
  (decision D-1, §0). The transcript named services from AWS (GameLift, DynamoDB), GCP (Google
  game servers, BigQuery) and Azure (Cosmos DB); all map to AWS equivalents.

---

## 3. Business requirements

| ID | Requirement | Source | Architectural implication |
| --- | --- | --- | --- |
| BR-1 | First title is a real-time multiplayer **racing game, 8 players per race**; it is the **first of several mobile games planned within a year**. | T | Treat the backend as a **reusable game platform**, not a one-off: shared identity/profile/analytics/payments services, with **per-title game-server fleets**. Avoid hard-coding game-specific logic into shared services. |
| BR-2 | **Launch within 8 months** (investor mandate). | T | Bias hard toward **managed services** (GameLift, DynamoDB, Cognito, Kinesis) over custom builds; everything in **IaC** for repeatable environments; minimize undifferentiated work. |
| BR-3 | Support **≥100,000 concurrent players at launch**. | T | Horizontally scalable, **stateless backend**; session-based game-server fleet sized to ~12,500 concurrent 8-player sessions; load-test to 100k before go-live. |
| BR-4 | Must **scale quickly if the game goes viral** (primary client concern). | T | Auto-scaling on game-server fleets and backend; serverless/elastic data stores (DynamoDB on-demand or autoscaling); pre-provisioned headroom + fast scale-out. |
| BR-5 | Win market share via **smooth, low-latency multiplayer** (differentiator vs laggy competitors). | T | **Multi-region, player-proximate** game servers; latency-aware matchmaking and routing are core, not optional. |
| BR-6 | Cloud-infra **budget ≈ $200,000 for year one**. | T | Strong cost guardrails: Spot for fault-tolerant game compute, **scale-to-low in off-peak**, Savings Plans for steady baseline, budget alarms. **Note:** sustained 100k CCU multi-region 24/7 will likely exceed $200k/yr — see §7 (cost tension) and §9 Q4. Resolved by D-3. |
| BR-7 | Launch in **North America + Europe**; **expand to Asia within 6 months**. | T | **Multi-region from day one** (NA + EU), with a clean path to add an APAC region; global traffic routing; EU triggers **data-residency** considerations (SC-1). |
| BR-8 | Players are on **iOS and Android phones**. | T | Mobile identity SDK, client telemetry ingestion, push/notification path, mobile-friendly auth. Client engine (Unity) frame rate is a **client-side** concern, out of cloud scope (confirm §8). |

---

## 4. Functional requirements

| ID | Requirement | Source | Architectural implication |
| --- | --- | --- | --- |
| FR-1 | **Matchmaking** grouping players by **skill and latency**. | T(CA) | Managed matchmaking (e.g., GameLift **FlexMatch**); requires a **skill-rating store** and per-player latency measurement to regions. |
| FR-2 | **Real-time game servers** running the actual 8-player races. | T(CA) | Session-based **dedicated game servers** (GameLift fleets, or Agones on EKS — §9 Q2); UDP/low-latency transport; per-session lifecycle. |
| FR-3 | **Player profiles & authentication**. | T(CA) | Managed identity (Cognito or equivalent) + profile store (DynamoDB). Auth method details are unspecified (§8). |
| FR-4 | **Leaderboards & stats**. | T(CA) | DynamoDB for durable stats + **in-memory store (ElastiCache/Redis sorted sets)** for real-time leaderboard reads at scale. |
| FR-5 | **Scalable database for player data**. | T(CA) | DynamoDB; per D-11 player **PII is region-scoped** (home region), non-PII may use **global tables**. Ties to NFR-6. |
| FR-6 | **In-app purchases**, including **storing player payment information**. | T | Per D-17 monetization = **one-time game purchase + cosmetic-add-on IAP** (no subscription). Per D-6: native store billing (Apple/Google) for in-app goods + **Stripe (PSP)** for web/direct sales; store only receipts, entitlements, and **PSP tokens** — never raw card data (keeps out of full PCI-DSS scope). Entitlement/wallet service. See SC-4 / D-6 / D-17. |
| FR-7 | **Future features: replay sharing & ghost races** — design storage/CDN now, build later. | T | **Object storage (S3) + CDN (CloudFront)** for replay files; event-driven replay ingestion; versioned replay schema so ghost-data can be derived later. Capacity reserved now, feature deferred. |
| FR-8 | **Analytics**: player engagement, monetization, game balance. | T | Event pipeline (Kinesis/Firehose -> S3 data lake -> warehouse) feeding BI. Warehouse choice open: **BigQuery vs Snowflake vs Redshift** (§9 Q5). |
| FR-9 | **Real-time detection of cheating / abnormal behavior**. | T | Per D-9: real-time streaming (Kinesis + Managed Service for Flink / Lambda) with **rules + statistical anomaly detection** at launch; ML deferred. The exercise's "AI" means AI-assisted delivery, not in-product ML. |
| FR-10 | **KPI tracking**: DAU/MAU, ARPU, retention, match-completion, matchmaking time, server performance; **real-time dashboards**. | T | Metrics pipeline + dashboards (QuickSight/Grafana); blends product analytics (FR-8) and ops telemetry (NFR-8). |
| FR-11 | **Customer support (Zendesk)** needs access to **player data & match history** via **secure APIs with logging**. | T | Internal, authenticated API (API Gateway + least-privilege IAM); **audit logging** (CloudTrail + app-level access logs) of all support data access. |
| FR-12 | **Beta program**: separate, limited-capacity, production-mirroring environment for **10,000 testers** across regions. | T | A dedicated **beta environment** (separate account/stack) built from the same IaC as prod but capacity-capped. |

---

## 5. Non-functional requirements

| ID | Requirement | Source | Architectural implication |
| --- | --- | --- | --- |
| NFR-1 | **≥99.9% uptime**. | T | Multi-AZ everywhere; **multi-region active-active**; health checks; no single points of failure. (≈43 min/month error budget.) |
| NFR-2 | **In-race connection drops beyond "a few seconds" are unacceptable**. | T | Resilient session transport, **hot failover**, fast client reconnection, low jitter; consider session-state resilience so a brief drop doesn't end a race. |
| NFR-3 | **Latency target for racing**. | T | Per D-8: **server-side p95 < 50 ms in-region, ~3 s reconnect grace.** Region-proximate servers + latency-based matchmaking that caps match RTT; more regional points of presence. Aggressive on mobile last-mile — load-test target and SOW risk. |
| NFR-4 | **Auto-scale for spikes; optimize cost in low-traffic periods**. | T | Target-tracking + scheduled scaling; **Spot** for game servers; scale game-server fleets toward zero off-peak. Plan headroom to **5× the 100k peak** (D-12). |
| NFR-5 | **Disaster recovery: active-active + hot failover**. | T(CA) | No cold standby; cross-region replication; Route 53 latency-routing failover. Per D-12: **RTO 5 min; RPO 0 (financial) / ≤5 min (game state)**. |
| NFR-6 | **Globally distributed database**. | T(CA) | Per D-11: DynamoDB **global tables** for non-PII, latency-sensitive data (sessions, matchmaking, leaderboards); **PII (profiles, payments) region-scoped** to the player's home region, not globally replicated. (AWS per D-1.) |
| NFR-7 | **Weekly content updates + monthly feature releases with minimal downtime**. | T | **Blue-green deployment**, gradual **per-region** rollout during low-traffic windows; CI/CD with rollback; feature flags. Pipeline on **GitHub Actions + OIDC** (D-13). |
| NFR-8 | **24/7 operations across multiple time zones**. | T | Full observability (CloudWatch + Datadog/New Relic APM); on-call; runbooks; **automated remediation** for common faults; ~3 SREs in shifts — per D-16 **client-hired, we advise**. |
| NFR-9 | **Three environments: dev, staging, production** (+ beta per FR-12). | T(CA) | Environment/account isolation; one IaC codebase parameterized per env; promotion pipeline. Greenfield **AWS Organization / Control Tower** landing zone with guardrails (D-10). |

---

## 6. Data requirements

| ID | Requirement | Source | Architectural implication |
| --- | --- | --- | --- |
| DR-1 | Per-player **stats, customizations, progression**. | T | Profile store (DynamoDB); deliberate key/access-pattern design. |
| DR-2 | **Race history, leaderboard positions**. | T | History table + leaderboard cache (FR-4). |
| DR-3 | **Replays ≈ 1 MB/race, 5–10 races/day/player, retain last 30 days**. | T | **S3 + 30-day lifecycle expiration**. Sized by D-7 (~1M DAU): 1M DAU × 7.5 races × 1 MB × 30 days ≈ **~225 TB** rolling. Drives storage cost and lifecycle policy. |
| DR-4 | **Historical data kept for analytics + seasonal events**. | T | S3 **data lake** + warehouse; tiered storage (Glacier/Intelligent-Tiering) for cold history. |
| DR-5 | **Store player payment information**. | T | Tokenize via PSP; encrypt; minimize what is stored (SC-4). |

---

## 7. Security & compliance requirements

| ID | Requirement | Source | Architectural implication |
| --- | --- | --- | --- |
| SC-1 | **GDPR** (EU players): data **export and deletion**. | T | Data-subject-request workflows; a **data map** so erasure/export can reach every store **including backups & analytics**; **EU data residency** enforced per **D-11** (EU PII pinned to EU). Response SLA per **D-18**: within **1 month** (extendable +2). |
| SC-2 | **COPPA** (players **under 13**): age verification + parental consent. | T | Per D-14: neutral **age gate** + **third-party verifiable parental consent** (e.g., k-ID/PRIVO); restricted data collection for minors; consent records. |
| SC-3 | **Encryption at rest and in transit**. | T(CA) | KMS-managed keys for all stores; TLS for all transport; mTLS for internal where feasible. |
| SC-4 | **Tokenization of payment data**. | T(CA) | PSP tokenization; **never store raw PAN**; keeps systems out of full PCI-DSS scope. |
| SC-5 | **Secure support APIs + logging**. | T(CA) | AuthN/Z on internal APIs; immutable audit trail of player-data access. |
| SC-6 | *(Implied)* Public game endpoints need **DDoS protection**. | Inferred | **AWS Shield + WAF** on CloudFront. Not stated by client — recommended; confirm (§8). |

### Cost tension (raise early)

At 100k CCU, ~12,500 concurrent 8-player sessions imply hundreds-to-thousands of game-server
instances. Running that **sustained, multi-region, 24/7** plausibly costs **well over $200k/year**
on game compute alone — sustained fleets at that scale annualize past **\$1M**. The $200k budget
is realistic **only** if 100k is a *peak* served by aggressive auto-scaling over a low baseline
(Spot, scale-to-low off-peak), not a sustained load. This must be resolved before sizing (see §9
Q4) and stated as a **risk** in the SOW.

---

## 8. Assumptions & defaults (confirm before relying on them)

| # | Assumption | Why it's only an assumption |
| --- | --- | --- |
| A-1 | Latency target — **superseded by D-8** (server-side p95 < 50 ms, ~3 s reconnect). | Was an open assumption; now a confirmed decision. |
| A-2 | DR targets — **superseded by D-12** (RTO 5 min; RPO 0 financial / ≤5 min game state). | Was an open assumption; now a confirmed decision. |
| A-3 | Viral/seasonal peak — **superseded by D-12** (plan 5× the 100k peak). | Was an open assumption; now a confirmed decision. |
| A-4 | **Client frame rate (e.g., 120 fps) is out of cloud scope**. | A Unity client-side concern, not backend; confirm it's out of cloud scope. |
| A-5 | Monetization model set by **D-17** (one-time game purchase + cosmetic IAP, no subscription); payment processing/storage by **D-6** (native billing + Stripe, tokens only). | Transcript said IAP, no subscription; no subscription model adopted (D-17). |
| A-6 | Localization — set by **D-15**: i18n/CMS design-ready now, languages delivered post-launch. | Transcript didn't mention it; confirmed design-ready approach. |
| A-7 | Auth = email/password + optional social/2FA/device-transfer. | Assumed defaults; transcript only says "authentication system." |
| A-8 | **$200k covers cloud infra only** (excludes labor, licenses, marketing). | Transcript says "for cloud infrastructure"; scope of the figure should be confirmed. |
| A-9 | Studio team = **15 Unity devs + 2 incoming DevOps**. | Transcript is authoritative. |

---

## 9. Open questions / gaps (for the client)

Grouped by impact. `(BLOCKER)` = blocks architecture sizing/design. `RESOLVED` items link to the
decision that closed them (see §0).

### Platform & scope

- **Q1** `RESOLVED -> D-1.` **Cloud provider** — AWS, GCP, or Azure? Decision: **AWS**.
- **Q2** `RESOLVED -> D-2.` **Game-server hosting** — managed GameLift vs self-managed Agones on EKS? Decision: **managed GameLift**.
- **Q3** `RESOLVED -> D-6, D-17.` **Monetization & payments** — Decision: **one-time game purchase + cosmetic IAP** (D-17), no subscription; native store billing + **Stripe (PSP)** for web/direct, store only receipts/entitlements and PSP tokens (D-6).
- **Q4** `RESOLVED -> D-3.` **Budget vs scale** — Is 100k CCU a *sustained* load or a *peak*? Does $200k/yr cover infra only? Decision: **cost-optimized peak**.

### Performance & capacity

- **Q5** `RESOLVED -> D-5.` **Analytics warehouse** — BigQuery, Snowflake, or Redshift? Decision: **Athena now, Redshift Serverless as upgrade path; not Snowflake**.
- **Q6** `RESOLVED -> D-7.` **User scale for sizing** — Decision: **~1M DAU / 3-5M registered**, 100k peak CCU.
- **Q7** `RESOLVED -> D-8.` **Latency target** — Decision: **server-side p95 < 50 ms in-region, ~3 s reconnect**.
- **Q8** `RESOLVED -> D-12.` **DR targets & viral peak** — Decision: **RTO 5 min; RPO 0 financial / ≤5 min game state; plan 5× the 100k peak**.

### Compliance & data

- **Q9** `RESOLVED -> D-9.` **Anti-cheat / AI scope** — Decision: **streaming rules + statistical anomaly detection now, ML deferred**; the project's "AI" is AI-assisted delivery, not in-product ML.
- **Q10** `RESOLVED -> D-14.` **COPPA** — Decision: **age gate + third-party verifiable parental consent** (under-13 supported, gated).
- **Q11** `RESOLVED -> D-11, D-18.` **Data residency & deletion SLA** — Decision: **EU PII pinned to EU; per-region isolation** (APAC at expansion); GDPR request SLA **1 month, extendable +2** (D-18).
- **Q12** `RESOLVED -> D-15.` **Localization** — Decision: **i18n/CMS design-ready now, languages delivered post-launch**.

### Operations

- **Q13** `RESOLVED -> D-10.` **AWS footprint** — Decision: **greenfield, new AWS Organization (Control Tower)** multi-account landing zone.
- **Q14** `RESOLVED -> D-16.` **SRE staffing** — Decision: **client hires the 3 SREs; we advise** (runbooks, training, guidance) alongside the 2 DevOps.
- **Q15** `RESOLVED -> D-13.` **CI/CD toolchain** — Decision: **GitHub Actions with OIDC to AWS**.

### Exercise deliverable

- **Q16** `RESOLVED -> D-4.` For the **Terraform** deliverable, full multi-region production design or a single-region deployable reference? Decision: **both** — full multi-region design/stack plus a single-region deployment demo.

---

## 10. Appendix — SOW outline (from the exercise brief)

The exercise mandates these SOW sections: *executive summary, in-scope / out-of-scope,
business objectives, technical solution, security & compliance, timeline, risks*. The SOW we
produce follows that spine, with a few value-add sections kept where they earn their place:

| SOW section | Status | Notes |
| --- | --- | --- |
| Executive summary | Exercise-required | Project overview, background, problem statement. |
| In-scope / out-of-scope | Exercise-required | Explicit scope boundaries. |
| Business objectives | Exercise-required | Business goals + expected outcomes. |
| Technical solution | Exercise-required | Functional + non-functional requirements; deliverables. |
| Security & compliance | Exercise-required | Dedicated section (GDPR/COPPA/PCI posture). |
| Timeline | Exercise-required | Milestones / project phases. |
| Risks & mitigations | Exercise-required | Dedicated section. |
| Cost & budget | Value-add | Budget-vs-scale tension (§7). |
| Roles & operations, Support & maintenance | Value-add | Ops model (D-16) and handover. |
