# Issue 14: Provision Pub/Sub Streaming Replacement (or Local Demo Spec) and Bindings for P-03

**Branch**: `feature/issue-14-rollout-p03-market-events`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #14)
**Milestone**: M4 - Rollout

## Objective
Provision the serverless event-streaming and query API infrastructure for **P-03 (`real-time-market-events`)** in `infra/platform/p03_market_events.tf` using `infra/modules/pubsub` and `infra/modules/cloud-run-service` — replacing always-on Apache Kafka + Schema Registry in cloud production with a $0.00/month **Cloud Pub/Sub** topic + Dead-Letter Queue (`p03-market-events-raw` / `p03-market-events-raw-sub`) and a scale-to-zero **Cloud Run Service** (`p03-market-events`, `1 vCPU`, `512Mi`, `min=0`, `max=1`), bound to Neon PostgreSQL (`p03_market_events`) and Secret Manager (`portfolio-postgres-url`, `portfolio-market-api-keys`), alongside the hybrid Cloud Pub/Sub + local Docker Compose Kafka demo specification.

## Acceptance Criteria
- [x] `infra/platform/variables.tf` defines `p03_image_tag` (defaulting to `"latest"` or immutable release SHA override) for `p03-market-events`
- [x] `infra/platform/p03_market_events.tf` instantiates `module "p03_market_events"` (`source = "../modules/cloud-run-service"`) with `service_name = "p03-market-events"`, `repo_name = "real-time-market-events"`, `cpu = "1"`, `memory = "512Mi"`, `min_instance_count = 0`, `max_instance_count = 1`, `port = 8000`, `env_vars` merged with `local.workload_db_secret_bindings.p03.env_vars` + Pub/Sub topic/subscription identifiers, and `secret_env_vars` bound to `portfolio-postgres-url` and `portfolio-market-api-keys`
- [x] `infra/platform/p03_market_events.tf` instantiates `module "p03_market_events_pubsub"` (`source = "../modules/pubsub"`) provisioning `topic_name = "p03-market-events-raw"`, `subscription_name = "p03-market-events-raw-sub"`, `enable_dlq = true`, `max_delivery_attempts = 5`, and granting `roles/pubsub.publisher` + `roles/pubsub.subscriber` to `module.p03_market_events.service_account_email`
- [x] `infra/platform/outputs.tf` exports `p03_market_events_service_name`, `p03_market_events_service_url`, `p03_market_events_sa_email`, `p03_pubsub_topic_name`, and `p03_pubsub_subscription_name`
- [x] Rollout and hybrid streaming specification (`Cloud Pub/Sub` in GCP vs. multi-broker `Kafka + Schema Registry` in local `docker-compose.yml`) is documented in `docs/issue_14_rollout_p03_market_events.md`
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=14 NAME=rollout-p03-market-events
```

### 2. Provision `p03-market-events` Cloud Run Service, Pub/Sub Topic + DLQ & IAM Bindings (`infra/platform/variables.tf`, `infra/platform/p03_market_events.tf` & `infra/platform/outputs.tf`)
- **File**: `infra/platform/variables.tf`, `infra/platform/p03_market_events.tf`, `infra/platform/outputs.tf`
- **Change**: Add `p03_image_tag` variable to `infra/platform/variables.tf`. Create `infra/platform/p03_market_events.tf` invoking `../modules/cloud-run-service` (`p03-market-events`, `1 vCPU`, `512Mi`, `min=0`, `max=1`, port `8000`) and `../modules/pubsub` (`p03-market-events-raw` topic, `p03-market-events-raw-sub` pull subscription, and companion DLQ `p03-market-events-raw-dlq`), wiring `publisher_sa_emails` and `subscriber_sa_emails` to `module.p03_market_events.service_account_email` and injecting `STREAMING_BACKEND = "pubsub"`, `PUBSUB_TOPIC_ID = "p03-market-events-raw"`, `PUBSUB_SUBSCRIPTION_ID = "p03-market-events-raw-sub"`, `local.workload_db_secret_bindings.p03.env_vars`, and `secret_env_vars` (`DATABASE_URL`, `MARKET_API_KEYS`). Export P-03 service and Pub/Sub outputs in `infra/platform/outputs.tf`.

### 3. Document P-03 Cloud Pub/Sub Replacement, Local Kafka Demo & CD Rollout Specification (`docs/issue_14_rollout_p03_market_events.md`)
- **File**: `docs/issue_14_rollout_p03_market_events.md`
- **Change**: Add the concrete P-03 rollout and streaming architecture specification covering dual-adapter configuration (`STREAMING_BACKEND=pubsub` in Cloud Run vs. `STREAMING_BACKEND=kafka` in local `docker-compose.yml`), Dead-Letter Queue (`p03-market-events-raw-dlq`) poison-pill handling, and keyless GitHub Actions CD deployment (`gcloud run deploy p03-market-events`).

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=14 MSG="feat(p03): provision p03-market-events Cloud Run service, Pub/Sub DLQ and rollout spec"
```

## Decisions
- **Replace Managed Kafka ($150+/month) with Cloud Pub/Sub + DLQ ($0.00/month) in GCP (`ADR-004`)**: Provisioning `p03-market-events-raw` and `p03-market-events-raw-dlq` via `infra/modules/pubsub` fits 100% within the Cloud Pub/Sub 10 GB/month Free Tier while retaining at-least-once delivery, exponential backoff (`10s`–`300s`), and Dead-Letter Queue isolation after 5 failed delivery attempts; multi-broker Kafka + Schema Registry remains documented and runnable locally via `docker compose up` at zero cloud cost.
- **Scale-to-zero Cloud Run Service (`min=0`, `max=1`, `512Mi`)**: Ensures `p03-market-events` incurs `$0.00` when idle while exposing `/health`, `/metrics`, and event query/ingestion endpoints over public HTTPS.

---

## P-03 Streaming Replacement, Local Kafka Demo & CI/CD Specification (`real-time-market-events`)

### 1. Dual-Mode Streaming Architecture (`ADR-004`)
| Environment | Streaming Broker | Configuration Contract | Monthly Cost |
|---|---|---|---|
| **GCP Cloud Production (`prod`)** | **Cloud Pub/Sub + DLQ** | `STREAMING_BACKEND=pubsub`, `PUBSUB_TOPIC_ID=p03-market-events-raw`, `PUBSUB_SUBSCRIPTION_ID=p03-market-events-raw-sub`, `PUBSUB_DLQ_TOPIC_ID=p03-market-events-raw-dlq` | **$0.00/month** (10 GB/mo Always Free) |
| **Local Demo (`docker-compose.yml`)** | **Apache Kafka + Schema Registry** | `STREAMING_BACKEND=kafka`, `KAFKA_BOOTSTRAP_SERVERS=kafka:9092`, `SCHEMA_REGISTRY_URL=http://schema-registry:8081` (`market.events.raw`) | **$0.00/month** (local container runtime) |

### 2. Cloud Runtime & IAM Contract
- **Workload Name**: `p03-market-events` (`google_cloud_run_v2_service`)
- **Artifact Registry Image**: `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p03-market-events:<git-sha>`
- **Compute & Scaling Limits**: `1 vCPU`, `512Mi` RAM, `min_instance_count = 0`, `max_instance_count = 1`, `port = 8000`, `health_check_path = "/health"`
- **Runtime Identity**: `sa-run-p03-market-events@<project_id>.iam.gserviceaccount.com`
- **Scoped IAM & Secrets**:
  - `roles/pubsub.publisher` on `p03-market-events-raw` and `roles/pubsub.subscriber` on `p03-market-events-raw-sub`
  - `roles/secretmanager.secretAccessor` on `portfolio-postgres-url` (`DATABASE_URL`, schema `p03_market_events`) and `portfolio-market-api-keys` (`MARKET_API_KEYS`)

### 3. Keyless GitHub Actions CD Rollout (`ale-camer/real-time-market-events`)
1. Authenticate with GitHub OIDC via `google-github-actions/auth@v2` assuming `sa-cicd-deployer@<project_id>.iam.gserviceaccount.com`.
2. Build and push the container image tagged with `${{ github.sha }}` to `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p03-market-events:${{ github.sha }}`.
3. Deploy the Cloud Run v2 revision and verify `/health`:
   ```bash
   gcloud run deploy p03-market-events \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/p03-market-events:${GITHUB_SHA}"

   SERVICE_URL="$(gcloud run services describe p03-market-events --project="${GCP_PROJECT_ID}" --region="us-central1" --format='value(status.url)')"
   curl --fail --silent --show-error --max-time 20 "${SERVICE_URL}/health"
   ```

