#!/usr/bin/env python3
"""
Standardized 2-tier WhatsApp notification helper for portfolio-infra workflows:
  - *[ESTADO-WEBS]*
  - *[BASES-DE-DATOS]*
  - *[COSTOS-CLOUD]*
Supports TextMeBot (group JID `@g.us` or phone) and CallMeBot with automatic rate-limit retry.
"""

from __future__ import annotations

import json
import logging
import os
import time
import urllib.parse
import urllib.request

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("notify_whatsapp")


def detect_trigger_label() -> str:
    ev = os.getenv("GITHUB_EVENT_NAME", "").strip().lower()
    if ev == "schedule":
        return "Automático"
    return "Manual"


def send_whatsapp_notification(message: str, max_retries: int = 4) -> bool:
    """
    Send `message` via TextMeBot or CallMeBot using:
      - WHATSAPP_PHONE: WhatsApp Group JID (`120363...@g.us`) OR phone number (`+4177...`)
      - WHATSAPP_APIKEY: TextMeBot alphanumeric key or CallMeBot numeric key
    Automatically waits and retries if TextMeBot enforces its rate-limit window.
    """
    recipient = os.getenv("WHATSAPP_PHONE", "").strip()
    if not recipient:
        logger.info("WHATSAPP_PHONE not configured; skipping WhatsApp dispatch.")
        return False

    api_key = (
        os.getenv("WHATSAPP_APIKEY", "").strip()
        or os.getenv("WHATSAPP_CALLMEBOT_APIKEY", "").strip()
    )
    if not api_key:
        logger.warning("WHATSAPP_PHONE is set, but WHATSAPP_APIKEY was not found.")
        return False

    encoded_msg = urllib.parse.quote(message)

    if not api_key.isdigit():
        if "@g.us" in recipient:
            formatted_recipient = recipient
        else:
            clean_phone = recipient.lstrip("+").replace(" ", "").replace("-", "")
            formatted_recipient = urllib.parse.quote(f"+{clean_phone}")
        url = (
            f"https://api.textmebot.com/send.php?"
            f"recipient={formatted_recipient}&apikey={urllib.parse.quote(api_key)}"
            f"&text={encoded_msg}&json=yes"
        )
        provider_name = "TextMeBot"
    else:
        clean_phone = recipient.lstrip("+").replace(" ", "").replace("-", "")
        url = (
            f"https://api.callmebot.com/whatsapp.php?"
            f"phone={clean_phone}&text={encoded_msg}&apikey={api_key}"
        )
        provider_name = "CallMeBot"

    for attempt in range(1, max_retries + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=25) as resp:
                body = resp.read().decode("utf-8", errors="ignore").strip()
                if provider_name == "TextMeBot":
                    try:
                        parsed = json.loads(body)
                        ok = parsed.get("status") == "success"
                        comment = str(parsed.get("comment", ""))
                    except Exception:
                        ok = "Success" in body or "success" in body
                        comment = body
                    if not ok and ("wait" in comment.lower() or "limit" in comment.lower()) and attempt < max_retries:
                        logger.info("TextMeBot rate limit hit (attempt %d/%d); sleeping 9s...", attempt, max_retries)
                        time.sleep(9)
                        continue
                else:
                    ok = 200 <= resp.status < 300
                logger.info("WhatsApp notification via %s: HTTP %s (ok=%s) body=%s", provider_name, resp.status, ok, body[:140])
                return ok
        except Exception as exc:
            logger.error("Attempt %d/%d failed to send WhatsApp via %s: %s", attempt, max_retries, provider_name, exc)
            if attempt < max_retries:
                time.sleep(8)
    return False
