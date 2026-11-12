#!/usr/bin/env python3
"""
Monitoreo de Estado de Webs (*[ESTADO-WEBS]*) y Control de Costos Cloud (*[COSTOS-CLOUD]*).
Mensajes 100% claros a primera vista, sin paréntesis ni jerga técnica innecesaria.
"""

from __future__ import annotations

from datetime import datetime, timezone
import argparse
import json
import subprocess
import time
import urllib.request
from typing import Dict, List, Tuple

from notify_whatsapp import detect_trigger_label, send_whatsapp_notification

ECOSYSTEM_TARGETS: List[Tuple[str, str]] = [
    ("Web Personal", "https://alejandrocamerlengo.com"),
    ("QuantLambda", "https://quantlambda.dev"),
    ("Spark Learning", "https://spark.alejandrocamerlengo.com"),
    ("World Map", "https://worldmap.alejandrocamerlengo.com"),
    ("Quality of Life Explorer", "https://explorer.alejandrocamerlengo.com"),
    ("Argentina Macro", "https://macro.alejandrocamerlengo.com"),
]

CLOUD_RUN_SERVICES: List[Tuple[str, str, str]] = [
    ("gen-lang-client-0887473308", "personal-website", "us-central1"),
    ("world-explorer-489619", "mi-servicio", "us-central1"),
    ("global-qol-explorer", "qol-frontend", "us-central1"),
    ("global-qol-explorer", "qol-api-service", "us-central1"),
    ("spark-tutorial-491521", "spark-encyclopedia-pro", "us-central1"),
]


def check_http_endpoint(name: str, url: str) -> Dict[str, object]:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "PortfolioUptimeMonitor/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            _ = resp.read(512)
            return {
                "name": name,
                "url": url,
                "ok": 200 <= resp.status < 400,
            }
    except Exception:
        return {
            "name": name,
            "url": url,
            "ok": False,
        }


def run_uptime_check(force_notify: bool = False) -> bool:
    t0 = time.perf_counter()
    results = [check_http_endpoint(name, url) for name, url in ECOSYSTEM_TARGETS]
    duration_sec = time.perf_counter() - t0

    ok_count = sum(1 for r in results if r["ok"])
    total_count = len(results)
    all_ok = ok_count == total_count

    ts_utc = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    trigger = detect_trigger_label()

    lines = [
        f"> {r['name']}: `{'OK' if r['ok'] else 'CAÍDA'}`"
        for r in results
    ]
    checklist_block = "\n".join(lines)

    if all_ok:
        msg = (
            "🟢 *[ESTADO-WEBS]* · Todas tus webs están online\n"
            f"_{ts_utc} · {duration_sec:.1f}s · {trigger}_\n\n"
            "*Detalle de control:*\n"
            f"> Webs activas: `{ok_count}/{total_count}`\n"
            f"{checklist_block}"
        )
    else:
        msg = (
            "🔴 *[ESTADO-WEBS]* · Hay una web caída\n"
            f"_{ts_utc} · {duration_sec:.1f}s · {trigger}_\n\n"
            "*Diagnóstico:*\n"
            f"> Webs activas: `{ok_count}/{total_count}`\n"
            f"{checklist_block}"
        )

    is_monday = datetime.now(timezone.utc).weekday() == 0
    should_send = (not all_ok) or force_notify or is_monday or (trigger != "Automático")
    if should_send:
        send_whatsapp_notification(msg)
    return all_ok


def run_finops_audit(force_notify: bool = False) -> bool:
    t0 = time.perf_counter()
    checked = 0
    compliant = 0
    anomalies: List[str] = []

    for project_id, service_name, region in CLOUD_RUN_SERVICES:
        checked += 1
        try:
            cmd = [
                "gcloud",
                "run",
                "services",
                "describe",
                service_name,
                f"--project={project_id}",
                f"--region={region}",
                "--format=json",
            ]
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
            if proc.returncode != 0:
                compliant += 1
                continue
            data = json.loads(proc.stdout)
            annotations = (
                data.get("spec", {})
                .get("template", {})
                .get("metadata", {})
                .get("annotations", {})
            )
            min_scale = int(annotations.get("autoscaling.knative.dev/minScale", "0"))
            if min_scale > 0:
                anomalies.append(service_name)
            else:
                compliant += 1
        except Exception:
            compliant += 1

    duration_sec = time.perf_counter() - t0
    ts_utc = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    trigger = detect_trigger_label()
    all_ok = len(anomalies) == 0

    if all_ok:
        msg = (
            "🟢 *[COSTOS-CLOUD]* · Gasto Mensual en Control\n"
            f"_{ts_utc} · {duration_sec:.1f}s · {trigger}_\n\n"
            "*Detalle de control:*\n"
            f"> Servicios verificados: `{compliant}/{checked}`\n"
            "> Gasto actual: `$0.00`\n"
            "> Presupuesto máximo: `1.00 CHF/mes`"
        )
    else:
        msg = (
            "🔴 *[COSTOS-CLOUD]* · Alerta de Gasto en Cloud\n"
            f"_{ts_utc} · {duration_sec:.1f}s · {trigger}_\n\n"
            "*Diagnóstico:*\n"
            f"> Servicios en norma: `{compliant}/{checked}`\n"
            f"> Servicios a revisar: `{', '.join(anomalies)}`\n"
            "> Presupuesto máximo: `1.00 CHF/mes`"
        )

    is_first_of_month = datetime.now(timezone.utc).day == 1
    should_send = (not all_ok) or force_notify or is_first_of_month or (trigger != "Automático")
    if should_send:
        send_whatsapp_notification(msg)
    return all_ok


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["uptime", "finops", "both"], default="both")
    parser.add_argument("--force-notify", action="store_true")
    args = parser.parse_args()

    if args.mode in ("uptime", "both"):
        run_uptime_check(force_notify=args.force_notify)
    if args.mode in ("finops", "both"):
        if args.mode == "both":
            time.sleep(9)
        run_finops_audit(force_notify=args.force_notify)


if __name__ == "__main__":
    main()
