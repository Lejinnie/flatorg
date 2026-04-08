"""Callable Cloud Function: translate issue titles and descriptions to German.

Uses the DeepL free-tier API. All texts are batched into a single API request
to minimise character consumption on the free tier (500k chars/month limit).

Secret setup (one-time, run on your machine):
    firebase functions:secrets:set DEEPL_API_KEY
"""

from __future__ import annotations

import logging
from typing import Any

import deepl
from firebase_functions import https_fn
from firebase_functions.params import SecretParam

logger = logging.getLogger(__name__)

# API key stored in Google Cloud Secret Manager — never embedded in the APK.
# Provision once with: firebase functions:secrets:set DEEPL_API_KEY
DEEPL_API_KEY = SecretParam("DEEPL_API_KEY")


@https_fn.on_call(secrets=[DEEPL_API_KEY])  # type: ignore[untyped-decorator, unused-ignore]
def translate_issues_callable(
    req: https_fn.CallableRequest[Any],
) -> dict[str, Any]:
    """Translate a list of issue objects to German using DeepL.

    Expected payload:
      issues — list of {"title": str, "description": str}

    Returns:
      {"issues": [{"title": str, "description": str}, ...]}

    Falls back to the original (untranslated) texts if the DeepL call fails,
    so a network or quota error never blocks the user from sending the email.

    Cost optimisation: titles and descriptions are interleaved into a single
    flat list and sent in one API call, halving the per-request overhead
    compared to translating each field separately.
    """
    data = req.data or {}
    issues: list[dict[str, str]] = data.get("issues", [])

    if not issues:
        return {"issues": []}

    # Validate payload — fail loudly so the client knows it sent bad data.
    for idx, item in enumerate(issues):
        if not isinstance(item.get("title"), str) or not isinstance(
            item.get("description"), str
        ):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message=(
                    f"Issue at index {idx} must have string 'title' and "
                    f"'description' fields. Got: {item!r}"
                ),
            )

    api_key = DEEPL_API_KEY.value
    if not api_key:
        # Secret is provisioned but empty — this is a misconfiguration.
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=(
                "DEEPL_API_KEY secret is not configured. "
                "Run: firebase functions:secrets:set DEEPL_API_KEY"
            ),
        )

    # Interleave: [title_0, desc_0, title_1, desc_1, ...]
    # One API call for all texts → minimum free-tier character usage.
    flat_texts: list[str] = []
    for item in issues:
        flat_texts.append(item["title"])
        flat_texts.append(item["description"])

    total_chars = sum(len(t) for t in flat_texts)

    try:
        translator = deepl.Translator(api_key)
        results = translator.translate_text(flat_texts, target_lang="DE")
    except deepl.DeepLException as exc:
        # Best-effort translation: fall back to originals so the user can
        # still send the email without waiting for a retry.
        logger.error(
            "translate_issues_callable: DeepL API error (%s). "
            "Falling back to original texts. flat_texts=%r",
            exc,
            flat_texts,
            exc_info=True,
        )
        return {"issues": issues}

    translated: list[dict[str, str]] = []
    for i in range(len(issues)):
        translated.append(
            {
                "title": results[i * 2].text,
                "description": results[i * 2 + 1].text,
            }
        )

    logger.info(
        "translate_issues_callable: translated %d issue(s), %d characters consumed",
        len(issues),
        total_chars,
    )

    return {"issues": translated}
