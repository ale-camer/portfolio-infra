# Issue 10: Implement Reusable `infra/modules/pubsub` Terraform Module with Dead-Letter Queue (DLQ) Support

**Branch**: `feature/issue-10-tf-module-pubsub-dlq`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #10)
**Milestone**: M3 - Modules & Pilot

## Objective
Implement the reusable `infra/modules/pubsub/` Terraform module (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`) to provision serverless event-streaming topics, pull subscriptions, and Dead-Letter Queue (`DLQ`) topics/subscriptions for event-driven portfolio workloads (`P-11` `trading-signals-Kafka` via `ADR-005`) within the 10 GB/month GCP Pub/Sub Always Free tier (`$0.00/month`).

## Acceptance Criteria
- [x] `infra/modules/pubsub/versions.tf` locks `required_version = ">= 1.5.0"` and `hashicorp/google` (`~> 6.0`)
- [x] `infra/modules/pubsub/variables.tf` defines typed, documented, and validated inputs (`project_id`, `topic_name`, `repo_name`, `subscription_name`, `message_retention_duration`, `ack_deadline_seconds`, `max_delivery_attempts`, `enable_dlq`, `minimum_backoff`, `maximum_backoff`, `publisher_sa_emails`, `subscriber_sa_emails`, `labels`) enforcing `max_delivery_attempts >= 5 && max_delivery_attempts <= 20` and retention `<= 7 days` (`604800s`)
- [x] `infra/modules/pubsub/main.tf` provisions the primary `google_pubsub_topic.topic`, conditional DLQ `google_pubsub_topic.dlq` (`<topic_name>-dlq`) and `google_pubsub_subscription.dlq` (`<subscription_name>-dlq-sub`), primary `google_pubsub_subscription.subscription` with `dead_letter_policy`, `retry_policy`, and `expiration_policy { ttl = "" }`, plus least-privilege `roles/pubsub.publisher` and `roles/pubsub.subscriber` IAM bindings
- [x] `infra/modules/pubsub/outputs.tf` exports `topic_name`, `topic_id`, `subscription_name`, `subscription_id`, `dlq_topic_name`, `dlq_topic_id`, and `dlq_subscription_name` with descriptions
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=10 NAME=tf-module-pubsub-dlq
```

### 2. Define Module Provider Constraints & Validated Input Contract (`infra/modules/pubsub/versions.tf` & `variables.tf`)
- **File**: `infra/modules/pubsub/versions.tf`, `infra/modules/pubsub/variables.tf`
- **Change**: Create `versions.tf` locking Terraform `>= 1.5.0` and `hashicorp/google ~> 6.0`. Create `variables.tf` with validation blocks enforcing `ack_deadline_seconds >= 10 && ack_deadline_seconds <= 600`, `max_delivery_attempts >= 5 && max_delivery_attempts <= 20`, valid `topic_name` and `subscription_name` identifiers, and optional `publisher_sa_emails` / `subscriber_sa_emails` sets.

### 3. Implement Pub/Sub Topic, Pull Subscription, DLQ Topology, and IAM Bindings (`infra/modules/pubsub/main.tf` & `outputs.tf`)
- **File**: `infra/modules/pubsub/main.tf`, `infra/modules/pubsub/outputs.tf`
- **Change**: Provision `google_pubsub_topic.topic`, conditional `google_pubsub_topic.dlq` (`${var.topic_name}-dlq`) and `google_pubsub_subscription.dlq` (`${var.subscription_name}-dlq-sub`), `google_pubsub_subscription.subscription` (with `dead_letter_policy`, `retry_policy`, `retain_acked_messages = false`, and `expiration_policy { ttl = "" }`), and optional `google_pubsub_topic_iam_member.publishers` / `google_pubsub_subscription_iam_member.subscribers`. Export topic, subscription, and DLQ identifiers in `outputs.tf`.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=10 MSG="feat(modules): implement pubsub module with DLQ support"
```

## Decisions
- **Replace self-hosted Kafka (`P-11`) with managed GCP Pub/Sub + DLQ (`ADR-005`)**: Provisioning primary + DLQ topics (`p11-market-ticks`, `p11-trading-signals`, `p11-trading-signals-dlq`) with 24h–7d message retention and `retain_acked_messages = false` keeps streaming throughput well inside the 10 GB/month Pub/Sub Always Free tier (`$0.00/mo`).
- **Set `expiration_policy { ttl = "" }` on Terraform-managed subscriptions**: By default GCP Pub/Sub auto-deletes subscriptions after 31 days of inactivity, which would cause Terraform state drift on low-frequency showcase workloads; setting `ttl = ""` prevents subscription expiration while unacknowledged messages still expire after `message_retention_duration` (`86400s` default).
