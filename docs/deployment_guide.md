# Guía Maestra de Despliegue de Extremo a Extremo (`portfolio-infra`)

Esta guía describe **paso a paso y con lujo de detalle** todas las acciones necesarias para aprovisionar, configurar, compilar y desplegar los **11 proyectos de la plataforma de Inteligencia de Mercados Financieros (`P-01` a `P-11`)** en Google Cloud Platform (GCP) bajo el presupuesto estricto de **< $10.00/mes**.

---

## Índice

1. [Visión General y Mapa de Workloads (`P-01` a `P-11`)](#1-visión-general-y-mapa-de-workloads)
2. [Paso 0: Preparación de Herramientas Locales](#paso-0-preparación-de-herramientas-locales)
3. [Paso 1: Configuración de Cuentas y Bases de Datos Gratuitas (Free Tier)](#paso-1-configuración-de-cuentas-y-bases-de-datos-gratuitas)
4. [Paso 2: Resolución de Contenedores Faltantes (`P-01`, `P-02`, `P-05`, `P-06`)](#paso-2-resolución-de-contenedores-faltantes)
5. [Paso 3: Terraform Fase 1 — Bootstrap del Bucket de Estado Remoto](#paso-3-terraform-fase-1--bootstrap-del-bucket-de-estado-remoto)
6. [Paso 4: Terraform Fase 2 — Despliegue de Cimientos de Plataforma](#paso-4-terraform-fase-2--despliegue-de-cimientos-de-plataforma)
7. [Paso 5: Inyección Fuera de Banda de los 6 Secretos Consolidados](#paso-5-inyección-fuera-de-banda-de-los-6-secretos-consolidados)
8. [Paso 6: Compilación y Push de Imágenes Iniciales a Artifact Registry](#paso-6-compilación-y-push-de-imágenes-iniciales-a-artifact-registry)
9. [Paso 7: Terraform Fase 2 — Despliegue Completo de Workloads y Monitoreo](#paso-7-terraform-fase-2--despliegue-completo-de-workloads-y-monitoreo)
10. [Paso 8: Verificación y Smoke Checks de la Plataforma](#paso-8-verificación-y-smoke-checks-de-la-plataforma)
11. [Paso 9: Automatización CI/CD con GitHub Actions y WIF](#paso-9-automatización-cicd-con-github-actions-y-wif)
12. [Paso 10: FinOps, Hibernación y Teardown](#paso-10-finops-hibernación-y-teardown)

---

## 1. Visión General y Mapa de Workloads

La plataforma consolida 11 repositorios en Google Cloud Platform (región `us-central1`, entorno `prod`):

| ID | Repositorio Local | Tipo en GCP | Nombre del Recurso | Imagen en Artifact Registry | Puertos / Triggers |
|:---:|:---|:---|:---|:---|:---|
| **P-01** | `financial-markets-pipeline` | Cloud Run Job | `p01-daily-etl` | `portfolio-apps/p01-daily-etl:latest` | Cron `0 22 * * 1-5` UTC |
| **P-02** | `crypto-analytics-platform` | Cloud Run Job | `p02-crypto-etl` | `portfolio-apps/p02-crypto-etl:latest` | Cron `0 1 * * *` UTC |
| **P-03** | `real-time-market-events` | Cloud Run Service | `p03-market-events` | `portfolio-apps/p03-market-events:latest` | HTTP `:8000`, `/health` |
| **P-04** | `financial-news-analysis-api` | Consolidado en P-08 | — (`ADR-002`) | Servido vía `p08-market-intel` y `p08-nlp-worker` | — |
| **P-05** | `market-intelligence-hub` | Cloud Run Service + Job | `p05-hub-api`<br>`p05-dbt-build` | `portfolio-apps/p05-hub-api:latest`<br>`portfolio-apps/p05-dbt-build:latest` | HTTP `:8000`, `/health`<br>Cron `0 2 * * *` UTC |
| **P-06** | `asset-anomaly-detection` | Cloud Run Service + Job | `p06-anomaly-api`<br>`p06-train-detect` | `portfolio-apps/p06-anomaly-api:latest`<br>`portfolio-apps/p06-train-detect:latest` | HTTP `:8000`, `/health`<br>Bajo demanda |
| **P-07** | `financial-documents-rag` | Cloud Run Service | `p07-docs-rag` | `portfolio-apps/p07-docs-rag:latest` | HTTP `:8000`, `/health` |
| **P-08** | `ai-powered-market-intelligence` | Cloud Run Service + Job | `p08-market-intel`<br>`p08-nlp-worker` | `portfolio-apps/p08-market-intel:latest`<br>`portfolio-apps/p08-nlp-worker:latest` | HTTP `:8000`, `/health`<br>Bajo demanda |
| **P-09** | `financial-research-agent` | Cloud Run Service | `p09-research-agent` | `portfolio-apps/p09-research-agent:latest` | HTTP `:8000`, `/health` |
| **P-10** | `autonomous-trading-analysis` | Cloud Run Service | `p10-trading-analyst` | `portfolio-apps/p10-trading-analyst:latest` | HTTP `:8080`, `/health` |
| **P-11** | `multi-agent-market-intelligence` | Cloud Run Service | `p11-multi-agent` | `portfolio-apps/p11-multi-agent:latest` | HTTP `:8000`, `/health` |

---

## Paso 0: Preparación de Herramientas Locales

Asegúrate de contar con las herramientas requeridas en tu sistema (Linux):

### 0.1 Instalar Google Cloud CLI (`gcloud`)
Si `which gcloud` devuelve vacío:
```bash
# Para distribuciones basadas en Debian/Ubuntu:
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update && sudo apt-get install -y google-cloud-cli

# Para distribuciones basadas en RHEL/Fedora:
# sudo dnf install -y google-cloud-cli
```

### 0.2 Autenticar `gcloud`
```bash
# Login interactivo con tu cuenta de Google
gcloud auth login

# Configurar Application Default Credentials (requerido por Terraform local)
gcloud auth application-default login
```

### 0.3 Validar herramientas instaladas
```bash
terraform -version   # Requiere >= 1.5.0 (instalado: 1.9.8)
docker --version      # Requiere Docker engine activo
gh --version          # Requiere GitHub CLI autenticado (gh auth status)
```

---

## Paso 1: Configuración de Cuentas y Bases de Datos Gratuitas

Para mantener el gasto en **$0.00/mes** en bases de datos y evitar Cloud SQL (~$35/mes) o Memorystore (~$35/mes), utilizamos los Always Free Tiers de tres proveedores gestionados.

### 1.1 Crear Proyecto en Google Cloud Platform
Elige un ID de proyecto único (ejemplo: `portfolio-platform-000000`):
```bash
export GCP_PROJECT_ID="portfolio-platform-$(openssl rand -hex 3)"
export GCP_REGION="us-central1"
export BILLING_ACCOUNT_ID="000000-000000-000000" # Reemplazar con tu ID de facturación

# Crear el proyecto en GCP
gcloud projects create "${GCP_PROJECT_ID}" --name="Portfolio Platform"

# Vincular la cuenta de facturación (necesario incluso para Free Tier)
gcloud billing projects link "${GCP_PROJECT_ID}" --billing-account="${BILLING_ACCOUNT_ID}"

# Configurar como proyecto por defecto
gcloud config set project "${GCP_PROJECT_ID}"
```

### 1.2 Neon Serverless PostgreSQL 16 + `pgvector` (Free Tier)
1. Regístrate en [neon.tech](https://neon.tech) (gratuito, 0.5 GB de almacenamiento).
2. Crea un proyecto llamado `portfolio-platform` con PostgreSQL 16 en región US (`aws-us-east-2` o `aws-us-east-1`).
3. En la pestaña **SQL Editor** de la consola de Neon, ejecuta el siguiente script idempotent para activar la extensión de vectores y aislar los esquemas de cada proyecto:
   ```sql
   -- 1. Activar extensión pgvector en el schema public
   CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

   -- 2. Crear schemas lógicos aislados por proyecto
   CREATE SCHEMA IF NOT EXISTS p01_market_etl;
   CREATE SCHEMA IF NOT EXISTS p03_market_events;
   CREATE SCHEMA IF NOT EXISTS p05_intel_hub;
   CREATE SCHEMA IF NOT EXISTS p06_anomaly;
   CREATE SCHEMA IF NOT EXISTS p07_docs_rag;
   CREATE SCHEMA IF NOT EXISTS p08_e2e_intel;
   CREATE SCHEMA IF NOT EXISTS p09_research;
   CREATE SCHEMA IF NOT EXISTS p10_trading;
   ```
4. Copia la cadena de conexión usando el endpoint con **pooler** (`-pooler`):
   ```text
   postgresql://portfolio_user:<PASSWORD>@ep-portfolio-pooler.us-east-2.aws.neon.tech/portfolio?sslmode=require
   ```

### 1.3 MongoDB Atlas M0 (Free Tier en GCP `us-central1`)
1. Regístrate en [mongodb.com/atlas](https://www.mongodb.com/cloud/atlas).
2. Crea un cluster gratuito **M0 Free** alojado específicamente en **Google Cloud / Iowa (`us-central1`)** para eliminar costos de transferencia de red hacia Cloud Run.
3. En **Database Access**: Crea un usuario `portfolio_app` con contraseña segura y rol `readWriteAnyDatabase`.
4. En **Network Access**: Agrega la entrada `0.0.0.0/0` (Allow Access from Anywhere) debido a que Cloud Run utiliza IPs de salida dinámicas.
5. Copia la URI de conexión:
   ```text
   mongodb+srv://portfolio_app:<PASSWORD>@cluster0.gcp.mongodb.net/portfolio?retryWrites=true&w=majority&maxPoolSize=10
   ```

### 1.4 Upstash Serverless Redis (Free Tier)
1. Regístrate en [upstash.com](https://upstash.com) (gratuito, 10,000 comandos/día).
2. Crea una base de datos Redis en la región **GCP / `us-central1`** con la opción **TLS Enabled**.
3. Copia la URL de conexión TLS (`rediss://`):
   ```text
   rediss://default:<TOKEN>@<endpoint>.upstash.io:6379
   ```

### 1.5 Claves de APIs Externas
Consigue o genera las siguientes claves:
- **LLMs**: OpenAI API Key (`sk-...`). *Nota*: Si deseas costo $0 inmediato en pruebas, la plataforma soporta `LLM_SMOKE_MODE=fake` sin invocar modelos de pago.
- **Mercados**:
  - Alpha Vantage API Key (gratuita en [alphavantage.co](https://www.alphavantage.co/support/#api-key))
  - CoinGecko API Key (gratuita Demo en [coingecko.com](https://www.coingecko.com/en/api))
  - Polygon.io API Key (gratuita en [polygon.io](https://polygon.io/))
- **Noticias & Social**:
  - NewsAPI Key (gratuita en [newsapi.org](https://newsapi.org/))
  - Reddit Client ID & Secret (gratuita en [reddit.com/prefs/apps](https://www.reddit.com/prefs/apps))
- **Firma de Tokens de Aplicación**:
  - Generar un secreto aleatorio para JWT: `openssl rand -hex 32`

---

## Paso 2: Resolución de Contenedores Faltantes

Antes de desplegar en Cloud Run, los repositorios deben contar con Dockerfiles que empaqueten el código ejecutable:

### 2.1 Ajustar `P-01` (`financial-markets-pipeline/Dockerfile`)
El Dockerfile original dependía de volúmenes en tiempo de desarrollo. Debe modificarse para copiar el código fuente en la imagen:
```dockerfile
FROM apache/airflow:2.10.5-python3.11

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

USER airflow
COPY --chown=airflow:root requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

# Copiar código fuente al contenedor de producción
COPY --chown=airflow:root src/ /opt/airflow/src/
COPY --chown=airflow:root dags/ /opt/airflow/dags/

ENV PYTHONPATH="/opt/airflow:/opt/airflow/src:${PYTHONPATH}"
WORKDIR /opt/airflow
```

### 2.2 Crear `P-02` (`crypto-analytics-platform/Dockerfile`)
Crea el archivo `Dockerfile` en la raíz de `crypto-analytics-platform`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    POLARS_MAX_THREADS=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir polars httpx pydantic google-cloud-bigquery google-cloud-storage pyarrow

COPY src/ /app/src/
ENV PYTHONPATH="/app:/app/src:${PYTHONPATH}"

CMD ["python", "-m", "src.extractors.coingecko"]
```

### 2.3 Crear `P-05` (`market-intelligence-hub/Dockerfile`)
Crea el archivo `Dockerfile` en la raíz de `market-intelligence-hub`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir fastapi uvicorn pydantic sqlalchemy asyncpg psycopg2-binary httpx

COPY src/ /app/src/
ENV PYTHONPATH="/app:/app/src:${PYTHONPATH}"

EXPOSE 8000
CMD ["uvicorn", "src.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 2.4 Crear `P-06` (`asset-anomaly-detection/Dockerfile`)
Crea el archivo `Dockerfile` en la raíz de `asset-anomaly-detection`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl libpq-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir fastapi uvicorn pydantic scikit-learn numpy pandas google-cloud-storage sqlalchemy

COPY src/ /app/src/
ENV PYTHONPATH="/app:/app/src:${PYTHONPATH}"

EXPOSE 8000
CMD ["uvicorn", "src.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Paso 3: Terraform Fase 1 — Bootstrap del Bucket de Estado Remoto

Terraform no puede usar un backend remoto en GCS antes de que el bucket exista. `infra/bootstrap/` se corre una única vez con estado local para crear el bucket versionado:

```bash
cd /home/alejandrocamerlengo/Projects/portfolio-infra/infra/bootstrap

terraform init
terraform apply -var="project_id=${GCP_PROJECT_ID}" -auto-approve
```

> **Resultado**: Se crea el bucket con versionamiento habilitado: `gs://${GCP_PROJECT_ID}-tfstate`.

---

## Paso 4: Terraform Fase 2 — Despliegue de Cimientos de Plataforma

Para evitar el error de Cloud Run buscando imágenes y secretos inexistentes, realizamos un despliegue **selectivo (targeted)** de los cimientos.

### 4.1 Configurar variables (`infra/platform/terraform.tfvars`)
Copia y personaliza el archivo de variables:
```bash
cd /home/alejandrocamerlengo/Projects/portfolio-infra
cp terraform.tfvars.example infra/platform/terraform.tfvars
```

Edita `infra/platform/terraform.tfvars` con tus datos reales:
```hcl
project_id         = "portfolio-platform-000000" # Tu GCP_PROJECT_ID
region             = "us-central1"
environment        = "prod"
billing_account_id = "000000-000000-000000"      # Tu ID de facturación
alert_email        = "tu-email@gmail.com"
github_owner       = "ale-camer"
monthly_budget_usd = 10

# Inicialmente en false hasta que los contenedores estén desplegados
enable_uptime_checks = false
log_retention_days   = 7

# Tags de imágenes por defecto
p01_image_tag = "latest"
p02_image_tag = "latest"
p03_image_tag = "latest"
p05_image_tag = "latest"
p06_image_tag = "latest"
p07_image_tag = "latest"
p08_image_tag = "latest"
p09_image_tag = "latest"
p10_image_tag = "latest"
p11_image_tag = "latest"
```

### 4.2 Inicializar Backend Remoto y Aplicar Cimientos
```bash
cd /home/alejandrocamerlengo/Projects/portfolio-infra/infra/platform

terraform init -backend-config="bucket=${GCP_PROJECT_ID}-tfstate"

# Aplicar ÚNICAMENTE los cimientos requeridos (APIs, Registro, Storage, BigQuery, Secret Shells y WIF)
terraform apply \
  -target=google_project_service.platform_apis \
  -target=google_billing_budget.monthly_cap \
  -target=google_monitoring_notification_channel.budget_email \
  -target=google_artifact_registry_repository.portfolio_apps \
  -target=google_storage_bucket.data_lake \
  -target=google_storage_bucket.artifacts \
  -target=google_bigquery_dataset.datasets \
  -target=google_secret_manager_secret.catalog \
  -target=google_iam_workload_identity_pool.github \
  -target=google_iam_workload_identity_pool_provider.github_oidc \
  -target=google_service_account.cicd_deployer \
  -target=google_service_account.infra_terraform \
  -auto-approve
```

---

## Paso 5: Inyección Fuera de Banda de los 6 Secretos Consolidados

Los 6 contenedores de secretos en Secret Manager ahora existen vacíos. Debemos inyectar una primera versión en cada uno para que Cloud Run pueda montarlos.

Ejecuta los siguientes comandos desde tu terminal (reemplazando los valores entre `<...>`):

```bash
# 1. Secreto de LLMs (portfolio-llm-api-key)
printf '{"OPENAI_API_KEY":"%s","ANTHROPIC_API_KEY":"","GOOGLE_API_KEY":""}' "<TU_OPENAI_API_KEY>" \
  | gcloud secrets versions add portfolio-llm-api-key \
      --project="${GCP_PROJECT_ID}" --data-file=-

# 2. Secreto de PostgreSQL Relacional (portfolio-postgres-url)
printf '%s' "postgresql://portfolio_user:<TU_PASSWORD_NEON>@ep-portfolio-pooler.us-east-2.aws.neon.tech/portfolio?sslmode=require" \
  | gcloud secrets versions add portfolio-postgres-url \
      --project="${GCP_PROJECT_ID}" --data-file=-

# 3. Secreto de APIs de Mercado Financiero (portfolio-market-api-keys)
printf '{"ALPHA_VANTAGE_API_KEY":"%s","COINGECKO_API_KEY":"%s","POLYGON_API_KEY":"%s","GLASSNODE_API_KEY":""}' \
  "<ALPHA_VANTAGE_KEY>" "<COINGECKO_KEY>" "<POLYGON_KEY>" \
  | gcloud secrets versions add portfolio-market-api-keys \
      --project="${GCP_PROJECT_ID}" --data-file=-

# 4. Secreto de Noticias y Redes Sociales (portfolio-news-social-keys)
printf '{"NEWSAPI_API_KEY":"%s","REDDIT_CLIENT_ID":"%s","REDDIT_CLIENT_SECRET":"%s"}' \
  "<NEWSAPI_KEY>" "<REDDIT_ID>" "<REDDIT_SECRET>" \
  | gcloud secrets versions add portfolio-news-social-keys \
      --project="${GCP_PROJECT_ID}" --data-file=-

# 5. Secreto de NoSQL y Caching (portfolio-nosql-cache-urls)
printf '{"MONGODB_URI":"%s","REDIS_URL":"%s"}' \
  "mongodb+srv://portfolio_app:<PASSWORD_ATLAS>@cluster0.gcp.mongodb.net/portfolio?retryWrites=true&w=majority&maxPoolSize=10" \
  "rediss://default:<TOKEN_UPSTASH>@<endpoint>.upstash.io:6379" \
  | gcloud secrets versions add portfolio-nosql-cache-urls \
      --project="${GCP_PROJECT_ID}" --data-file=-

# 6. Secreto de Firma y Autenticación de Servicios (portfolio-app-signing-keys)
printf '{"SECRET_KEY":"%s","API_SECRET_KEY":"%s"}' \
  "$(openssl rand -hex 32)" "$(openssl rand -hex 32)" \
  | gcloud secrets versions add portfolio-app-signing-keys \
      --project="${GCP_PROJECT_ID}" --data-file=-
```

> **Verificación**: Confirma que cada secreto tiene exactamente 1 versión activa:
> ```bash
> for s in portfolio-llm-api-key portfolio-postgres-url portfolio-market-api-keys \
>          portfolio-news-social-keys portfolio-nosql-cache-urls portfolio-app-signing-keys; do
>   echo -n "$s: "
>   gcloud secrets versions list "$s" --project="${GCP_PROJECT_ID}" --filter="state=ENABLED" --format="value(name)" | wc -l
> done
> ```

---

## Paso 6: Compilación y Push de Imágenes Iniciales a Artifact Registry

Configura Docker para autenticarse con el registro de GCP:
```bash
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
export REGISTRY="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps"
```

Compila y sube cada una de las imágenes requeridas:

```bash
# P-01: Financial Markets Pipeline (Job)
cd /home/alejandrocamerlengo/Projects/financial-markets-pipeline
docker build -t "${REGISTRY}/p01-daily-etl:latest" .
docker push "${REGISTRY}/p01-daily-etl:latest"

# P-02: Crypto Analytics Platform (Job)
cd /home/alejandrocamerlengo/Projects/crypto-analytics-platform
docker build -t "${REGISTRY}/p02-crypto-etl:latest" .
docker push "${REGISTRY}/p02-crypto-etl:latest"

# P-03: Real-Time Market Events (Service)
cd /home/alejandrocamerlengo/Projects/real-time-market-events
docker build -t "${REGISTRY}/p03-market-events:latest" .
docker push "${REGISTRY}/p03-market-events:latest"

# P-05: Market Intelligence Hub (Service + dbt Job)
cd /home/alejandrocamerlengo/Projects/market-intelligence-hub
docker build -t "${REGISTRY}/p05-hub-api:latest" .
docker push "${REGISTRY}/p05-hub-api:latest"
docker tag "${REGISTRY}/p05-hub-api:latest" "${REGISTRY}/p05-dbt-build:latest"
docker push "${REGISTRY}/p05-dbt-build:latest"

# P-06: Asset Anomaly Detection (Service + Job)
cd /home/alejandrocamerlengo/Projects/asset-anomaly-detection
docker build -t "${REGISTRY}/p06-anomaly-api:latest" .
docker push "${REGISTRY}/p06-anomaly-api:latest"
docker tag "${REGISTRY}/p06-anomaly-api:latest" "${REGISTRY}/p06-train-detect:latest"
docker push "${REGISTRY}/p06-train-detect:latest"

# P-07: Financial Documents RAG (Service)
cd /home/alejandrocamerlengo/Projects/financial-documents-rag
docker build -t "${REGISTRY}/p07-docs-rag:latest" .
docker push "${REGISTRY}/p07-docs-rag:latest"

# P-08: AI-Powered Market Intelligence (Service + Job)
cd /home/alejandrocamerlengo/Projects/ai-powered-market-intelligence
docker build -t "${REGISTRY}/p08-market-intel:latest" .
docker push "${REGISTRY}/p08-market-intel:latest"
docker tag "${REGISTRY}/p08-market-intel:latest" "${REGISTRY}/p08-nlp-worker:latest"
docker push "${REGISTRY}/p08-nlp-worker:latest"

# P-09: Financial Research Agent (Service)
cd /home/alejandrocamerlengo/Projects/financial-research-agent
docker build -t "${REGISTRY}/p09-research-agent:latest" .
docker push "${REGISTRY}/p09-research-agent:latest"

# P-10: Autonomous Trading Analyst (Service)
cd /home/alejandrocamerlengo/Projects/autonomous-trading-analysis
docker build -t "${REGISTRY}/p10-trading-analyst:latest" .
docker push "${REGISTRY}/p10-trading-analyst:latest"

# P-11: Multi-Agent Market Intelligence (Service)
cd /home/alejandrocamerlengo/Projects/multi-agent-market-intelligence
docker build -t "${REGISTRY}/p11-multi-agent:latest" .
docker push "${REGISTRY}/p11-multi-agent:latest"
```

---

## Paso 7: Terraform Fase 2 — Despliegue Completo de Workloads y Monitoreo

Ahora que **todas las imágenes existen en Artifact Registry** y **los 6 secretos tienen versiones válidas**, ejecuta el despliegue completo de la infraestructura:

```bash
cd /home/alejandrocamerlengo/Projects/portfolio-infra/infra/platform

terraform apply -auto-approve
```

Este comando aprovisionará:
- Los **8 Cloud Run Services** (`p03`, `p05`, `p06`, `p07`, `p08`, `p09`, `p10`, `p11`) con escala a cero (`min_instances = 0`).
- Los **5 Cloud Run Jobs** (`p01-daily-etl`, `p02-crypto-etl`, `p05-dbt-build`, `p06-train-detect`, `p08-nlp-worker`).
- Los **3 disparadores de Cloud Scheduler** (`p01`, `p02`, `p05`).
- Los tópicos y suscripciones con DLQ de **Pub/Sub** (`p03-market-events`).
- Las políticas de alertas y dashboard de **Cloud Monitoring**.

Una vez comprobado que los servicios responden, habilita los chequeos de uptime periódicos:
```bash
terraform apply -var="enable_uptime_checks=true" -auto-approve
```

---

## Paso 8: Verificación y Smoke Checks de la Plataforma

### 8.1 Verificar Servicios HTTP
Obtén las URLs públicas de cada servicio mediante las salidas de Terraform:
```bash
cd /home/alejandrocamerlengo/Projects/portfolio-infra/infra/platform

export P03_URL=$(terraform output -raw p03_market_events_service_url)
export P05_URL=$(terraform output -raw p05_hub_api_service_url)
export P06_URL=$(terraform output -raw p06_anomaly_api_service_url)
export P07_URL=$(terraform output -raw p07_docs_rag_service_url)
export P08_URL=$(terraform output -raw p08_market_intel_service_url)
export P09_URL=$(terraform output -raw p09_research_agent_service_url)
export P10_URL=$(terraform output -raw p10_trading_analyst_service_url)
export P11_URL=$(terraform output -raw p11_multi_agent_service_url)

for svc in P03 P05 P06 P07 P08 P09 P10 P11; do
  url_var="${svc}_URL"
  url="${!url_var}"
  echo -n "Probando $svc ($url/health)... "
  curl -s -o /dev/null -w "%{http_code}\n" --max-time 15 "${url}/health" || echo "Error"
done
```
> **Nota de arranque en frío**: La primera llamada puede tardar 2-5 segundos debido a que `min_instances = 0`. La respuesta esperada es `200`.

### 8.2 Ejecución de Prueba de Batch Jobs
Prueba la ejecución manual de un Job de Cloud Run:
```bash
gcloud run jobs execute p02-crypto-etl --region=us-central1 --wait
```

---

## Paso 9: Automatización CI/CD con GitHub Actions y WIF

Para que futuros cambios en los 11 repositorios se desplieguen automáticamente sin usar claves estáticas JSON:

### 9.1 Obtener Identificadores de WIF
```bash
cd /home/alejandrocamerlengo/Projects/portfolio-infra/infra/platform

terraform output -raw wif_provider_name
# Ejemplo: projects/123456789/locations/global/workloadIdentityPools/github-actions-pool/providers/github-oidc-provider

terraform output -raw cicd_deployer_sa_email
# Ejemplo: sa-cicd-deployer@portfolio-platform-000000.iam.gserviceaccount.com
```

### 9.2 Configurar Variables en los Repositorios de GitHub
En cada uno de los 11 repositorios de GitHub (`Settings -> Secrets and variables -> Actions -> Variables`):
- `GCP_PROJECT_ID`: El ID de tu proyecto.
- `WIF_PROVIDER`: El valor obtenido de `wif_provider_name`.
- `WIF_SERVICE_ACCOUNT`: El valor obtenido de `cicd_deployer_sa_email`.

El workflow centralizado reutilizable `.github/workflows/cd-cloud-run.yml` en `portfolio-infra` se encargará de compilar, pushear con el tag del commit SHA y actualizar la revisión de Cloud Run.

---

## Paso 10: FinOps, Hibernación y Teardown

Para garantizar que el costo mensual se mantenga en **`~$1.62/mes`** y nunca exceda los **`$10.00/mes`**:

### Modo 1: Hibernación en 10 Segundos (Costo ~$0.12/mes)
Si no vas a utilizar o demostrar la plataforma por varias semanas, pausa los cron jobs y uptime checks:
```bash
# 1. Pausar schedulers
for job in sched-p01-daily-etl sched-p02-crypto-etl sched-p05-dbt-build; do
  gcloud scheduler jobs pause "$job" --location=us-central1
done

# 2. Desactivar uptime probes para que Cloud Run quede en 0 instancias permanentemente
cd /home/alejandrocamerlengo/Projects/portfolio-infra/infra/platform
terraform apply -var="enable_uptime_checks=false" -auto-approve
```

### Modo 2: Teardown Completo (`$0.00/mes`)
Para destruir todos los recursos desplegados pero conservar el bucket de estado remoto:
```bash
cd /home/alejandrocamerlengo/Projects/portfolio-infra/infra/platform
terraform destroy -auto-approve
```

Consulta [`docs/teardown.md`](teardown.md) para el detalle de desmantelamiento total y checklist de auditoría de costos.
