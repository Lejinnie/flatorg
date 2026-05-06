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

from services.translation_service import translate_issues

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
        if not isinstance(item.get("title"), str) or not isinstance(item.get("description"), str):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message=(f"Issue at index {idx} must have string 'title' and 'description' fields. Got: {item!r}"),
            )

    api_key = DEEPL_API_KEY.value
    if not api_key:
        # Secret is provisioned but empty — this is a misconfiguration.
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=("DEEPL_API_KEY secret is not configured. Run: firebase functions:secrets:set DEEPL_API_KEY"),
        )

    total_chars = sum(len(item["title"]) + len(item["description"]) for item in issues)

    try:
        translator = deepl.Translator(api_key)
        # deepl.Translator.translate_text is typed as returning
        # TextResult | list[TextResult] (single-string overload), but our
        # protocol correctly narrows to list[TextResult] for list input.
        translated = translate_issues(issues, translator)  # type: ignore[arg-type]
    except deepl.DeepLException:
        # Best-effort translation: fall back to originals so the user can
        # still send the email without waiting for a retry.
        logger.exception(
            "translate_issues_callable: DeepL API error. Falling back to original texts. flat_texts=%r",
            [item for issue in issues for item in (issue["title"], issue["description"])],
        )
        return {"issues": issues}

    logger.info(
        "translate_issues_callable: translated %d issue(s), %d characters consumed",
        len(issues),
        total_chars,
    )

    return {"issues": translated}
