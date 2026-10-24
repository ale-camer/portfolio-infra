locals {
  postgres_secret_ref = {
    secret_id = google_secret_manager_secret.catalog["portfolio-postgres-url"].secret_id
    version   = "latest"
  }

  nosql_secret_ref = {
    secret_id = google_secret_manager_secret.catalog["portfolio-nosql-cache-urls"].secret_id
    version   = "latest"
  }

  neon_pool_env_vars = {
    PGSSLMODE       = "require"
    DB_POOL_SIZE    = "2"
    DB_MAX_OVERFLOW = "3"
    DB_POOL_TIMEOUT = "30"
  }

  atlas_pool_env_vars = {
    MONGODB_MAX_POOL_SIZE = "10"
    MONGODB_MIN_POOL_SIZE = "0"
    MONGODB_RETRY_WRITES  = "true"
  }

  upstash_pool_env_vars = {
    REDIS_SSL_CERT_REQS   = "required"
    REDIS_MAX_CONNECTIONS = "5"
  }

  # Canonical connectivity catalog for external serverless free-tier databases (ADR-005 & ADR-006).
  external_database_topology = {
    neon_postgres = {
      provider               = "neon-serverless-postgresql-16"
      tier                   = "free-tier-0.5gb"
      region                 = "aws-us-east-2"
      extensions             = ["vector"]
      connection_mode        = "pgbouncer-transaction-pooler"
      secret_id              = local.postgres_secret_ref.secret_id
      secret_resource_id     = google_secret_manager_secret.catalog["portfolio-postgres-url"].id
      monthly_cost_usd       = 0
      logical_schemas        = ["p01_market_etl", "p03_market_events", "p05_intel_hub", "p06_anomaly", "p07_docs_rag", "p08_e2e_intel", "p09_research", "p10_trading"]
      vector_enabled_schemas = ["p03_market_events", "p07_docs_rag", "p08_e2e_intel"]
      default_env_vars       = local.neon_pool_env_vars
    }
    mongodb_atlas_m0 = {
      provider           = "mongodb-atlas-m0"
      tier               = "free-tier-512mb"
      region             = "gcp-us-central1"
      protocol           = "mongodb+srv"
      secret_id          = local.nosql_secret_ref.secret_id
      secret_resource_id = google_secret_manager_secret.catalog["portfolio-nosql-cache-urls"].id
      monthly_cost_usd   = 0
      logical_databases  = ["p04_financial_news", "p07_raw_filings"]
      default_env_vars   = local.atlas_pool_env_vars
    }
    upstash_redis = {
      provider             = "upstash-serverless-redis"
      tier                 = "free-tier-10k-cmds-day"
      region               = "us-central1"
      protocol             = "rediss"
      secret_id            = local.nosql_secret_ref.secret_id
      secret_resource_id   = google_secret_manager_secret.catalog["portfolio-nosql-cache-urls"].id
      monthly_cost_usd     = 0
      logical_key_prefixes = ["p01:", "p04:", "p07:", "p08:"]
      default_env_vars     = local.upstash_pool_env_vars
    }
  }

  # Standardized per-workload database secret_env_vars and connection-pool env_vars (P-01..P-10).
  workload_db_secret_bindings = {
    p01 = {
      repo_name       = "financial-markets-pipeline"
      db_engines      = ["neon_postgres", "upstash_redis"]
      db_schema       = "p01_market_etl"
      env_vars        = merge(local.neon_pool_env_vars, local.upstash_pool_env_vars, { DB_SCHEMA = "p01_market_etl" })
      secret_env_vars = { DATABASE_URL = local.postgres_secret_ref, REDIS_URL = local.nosql_secret_ref }
    }
    p03 = {
      repo_name       = "real-time-market-events"
      db_engines      = ["neon_postgres"]
      db_schema       = "p03_market_events"
      env_vars        = merge(local.neon_pool_env_vars, { DB_SCHEMA = "p03_market_events", PGVECTOR_ENABLED = "true" })
      secret_env_vars = { DATABASE_URL = local.postgres_secret_ref }
    }
    p04 = {
      repo_name       = "financial-news-intelligence-api"
      db_engines      = ["mongodb_atlas_m0", "upstash_redis"]
      db_schema       = "p04_financial_news"
      env_vars        = merge(local.atlas_pool_env_vars, local.upstash_pool_env_vars, { MONGODB_DB_NAME = "p04_financial_news" })
      secret_env_vars = { MONGODB_URI = local.nosql_secret_ref, REDIS_URL = local.nosql_secret_ref }
    }
    p05 = {
      repo_name       = "market-intelligence-hub"
      db_engines      = ["neon_postgres"]
      db_schema       = "p05_intel_hub"
      env_vars        = merge(local.neon_pool_env_vars, { DB_SCHEMA = "p05_intel_hub" })
      secret_env_vars = { DATABASE_URL = local.postgres_secret_ref }
    }
    p06 = {
      repo_name       = "asset-anomaly-detection"
      db_engines      = ["neon_postgres"]
      db_schema       = "p06_anomaly"
      env_vars        = merge(local.neon_pool_env_vars, { DB_SCHEMA = "p06_anomaly" })
      secret_env_vars = { DATABASE_URL = local.postgres_secret_ref }
    }
    p07 = {
      repo_name       = "financial-documents-rag"
      db_engines      = ["neon_postgres", "mongodb_atlas_m0", "upstash_redis"]
      db_schema       = "p07_docs_rag"
      env_vars        = merge(local.neon_pool_env_vars, local.atlas_pool_env_vars, local.upstash_pool_env_vars, { DB_SCHEMA = "p07_docs_rag", PGVECTOR_ENABLED = "true", MONGODB_DB_NAME = "p07_raw_filings" })
      secret_env_vars = { DATABASE_URL = local.postgres_secret_ref, NOSQL_CACHE_URLS = local.nosql_secret_ref }
    }
    p08 = {
      repo_name       = "ai-powered-market-intelligence"
      db_engines      = ["neon_postgres", "upstash_redis"]
      db_schema       = "p08_e2e_intel"
      env_vars        = merge(local.neon_pool_env_vars, local.upstash_pool_env_vars, { DB_SCHEMA = "p08_e2e_intel", PGVECTOR_ENABLED = "true" })
      secret_env_vars = { DATABASE_URL = local.postgres_secret_ref, REDIS_URL = local.nosql_secret_ref }
    }
    p09 = {
      repo_name       = "financial-research-agent"
      db_engines      = ["neon_postgres"]
      db_schema       = "p09_research"
      env_vars        = merge(local.neon_pool_env_vars, { DB_SCHEMA = "p09_research" })
      secret_env_vars = { DATABASE_URL = local.postgres_secret_ref }
    }
    p10 = {
      repo_name       = "autonomous-trading-agent"
      db_engines      = ["neon_postgres"]
      db_schema       = "p10_trading"
      env_vars        = merge(local.neon_pool_env_vars, { DB_SCHEMA = "p10_trading" })
      secret_env_vars = { DATABASE_URL = local.postgres_secret_ref }
    }
  }
}
