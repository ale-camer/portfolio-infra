# External Serverless Free-Tier Databases (`ADR-005` & `ADR-006`)

To operate all 11 sibling repositories (`P-01` through `P-11`) under the **< $10.00/month** GCP platform budget ceiling, `portfolio-infra` replaces always-on GCP Cloud SQL (~$35/mo) and Memorystore for Redis (~$35/mo) with three managed, scale-to-zero external free-tier data stores at **$0.00/month**:

1. **Neon Serverless PostgreSQL 16 + `pgvector`** (`0.5 GB` Free Tier, transaction pooler)
2. **MongoDB Atlas M0** (`512 MB` Free Tier hosted on GCP `us-central1`)
3. **Upstash Serverless Redis** (`10,000 commands/day` Free Tier with TLS)

All database credentials are stored out-of-band in **Google Secret Manager** using two consolidated secret shells defined in `infra/platform/secrets.tf`:
- `portfolio-postgres-url`
- `portfolio-nosql-cache-urls`

No connection string, username, or password ever enters Terraform state (`.tfstate`) or Git history.

---

## 1. Engine-to-Workload Topology (`infra/platform/external_databases.tf`)

| Engine | Secret Manager Shell | Logical Schema / Namespace | Consuming Repositories | Key Capabilities & Pool Guardrails |
|---|---|---|---|---|
| **Neon PostgreSQL 16 (`pgvector`)** | `portfolio-postgres-url` | `p01_market_etl`, `p03_market_events`, `p05_intel_hub`, `p06_anomaly`, `p07_docs_rag`, `p08_e2e_intel`, `p09_research`, `p10_trading` | `P-01`, `P-03`, `P-05`, `P-06`, `P-07`, `P-08`, `P-09`, `P-10` | Pooled `-pooler` endpoint (`PgBouncer`), `sslmode=require`, `DB_POOL_SIZE=2`, `DB_MAX_OVERFLOW=3`, `vector` extension (`1536` / `384` dims) |
| **MongoDB Atlas M0** | `portfolio-nosql-cache-urls` | `p04_financial_news`, `p07_raw_filings` | `P-04`, `P-07` | Hosted on GCP `us-central1` (`0.00` cross-cloud latency), `mongodb+srv://` TLS 1.2+, `MONGODB_MAX_POOL_SIZE=10`, `minPoolSize=0` |
| **Upstash Serverless Redis** | `portfolio-nosql-cache-urls` | Key prefixes: `p01:`, `p04:`, `p07:`, `p08:` | `P-01`, `P-04`, `P-07`, `P-08` | `rediss://` TLS endpoint, `REDIS_MAX_CONNECTIONS=5`, rate limiting & NLP/RAG response caching |

---

## 2. Neon Serverless PostgreSQL 16 + `pgvector` Bootstrap

### 2.1 Pooled Endpoint & TLS Requirement
Cloud Run Services (`min_instance_count = 0`) and Cloud Run Jobs spin up ephemeral containers on demand. Always use Neon's **pooled connection host** (`ep-<name>-pooler.<region>.aws.neon.tech`) with `sslmode=require`:

```text
postgresql+psycopg://<role>:<secret>@ep-<project>-pooler.us-east-2.aws.neon.tech/portfolio?sslmode=require
```

### 2.2 Logical Schema & `pgvector` Initialization SQL
Run the following idempotent SQL once against the Neon `portfolio` database to isolate each repository's tables and enable `pgvector` for semantic/RAG workloads (`P-03`, `P-07`, `P-08`):

```sql
-- 1. Enable pgvector extension in public schema so all schemas can reference VECTOR(n)
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

-- 2. Create per-workload logical schemas
CREATE SCHEMA IF NOT EXISTS p01_market_etl;
CREATE SCHEMA IF NOT EXISTS p03_market_events;
CREATE SCHEMA IF NOT EXISTS p05_intel_hub;
CREATE SCHEMA IF NOT EXISTS p06_anomaly;
CREATE SCHEMA IF NOT EXISTS p07_docs_rag;
CREATE SCHEMA IF NOT EXISTS p08_e2e_intel;
CREATE SCHEMA IF NOT EXISTS p09_research;
CREATE SCHEMA IF NOT EXISTS p10_trading;
```

---

## 3. MongoDB Atlas M0 (`us-central1`) & Upstash Redis Configuration

1. **MongoDB Atlas M0**:
   - Provision the M0 Free Cluster in **Google Cloud / `Iowa (us-central1)`** to co-locate with Cloud Run and eliminate cross-region latency.
   - Enforce TLS (`mongodb+srv://`) with a dedicated least-privilege database user (`readWrite` on `p04_financial_news` and `p07_raw_filings`).
   - Because Cloud Run uses dynamic egress IPs (`INGRESS_TRAFFIC_ALL` without Paid Cloud NAT), configure Atlas Network Access for TLS-authenticated SCRAM-SHA-256 connections and cap per-container driver pools at `maxPoolSize=10&minPoolSize=0`.
2. **Upstash Serverless Redis**:
   - Provision a Free Tier database in `us-central1` with **TLS Enabled** (`rediss://default:<secret>@<endpoint>.upstash.io:6379`).
   - Prefix keys by workload (`p01:`, `p04:`, `p07:`, `p08:`) and set TTLs (`<= 86400s`) so storage remains well below the 256 MB Free Tier cap.

---

## 4. Out-of-Band Secret Manager Injection (`<= 6` Active Versions)

After `terraform apply` creates the empty Secret Manager shells in `infra/platform/secrets.tf`, populate the two database secret payloads from your workstation without writing credentials to disk or shell history:

```bash
# 1. Inject Neon PostgreSQL pooled DSN into portfolio-postgres-url
printf '%s' "postgresql://portfolio_app:<NEON_CREDENTIAL>@ep-portfolio-pooler.us-east-2.aws.neon.tech/portfolio?sslmode=require" \
  | gcloud secrets versions add portfolio-postgres-url \
      --project="${GCP_PROJECT_ID}" \
      --data-file=-

# 2. Inject MongoDB Atlas M0 and Upstash Redis TLS URIs into portfolio-nosql-cache-urls
printf '{"MONGODB_URI":"mongodb+srv://portfolio_app:<ATLAS_CREDENTIAL>@cluster0.gcp.mongodb.net/p04_financial_news?retryWrites=true&w=majority&maxPoolSize=10","REDIS_URL":"rediss://default:<UPSTASH_CREDENTIAL>@us1-portfolio.upstash.io:6379"}' \
  | gcloud secrets versions add portfolio-nosql-cache-urls \
      --project="${GCP_PROJECT_ID}" \
      --data-file=-
```

> **Free Tier Version Hygiene**: When rotating a database credential, destroy the previous Secret Manager version (`gcloud secrets versions destroy <prev_version> --secret=<secret_id>`) so total active secret versions across the GCP project remain `<= 6` (**$0.00/month**).
