"""Pure translation service: batches issue texts and calls DeepL.

The core logic is isolated here so it can be tested without any Firebase SDK
or real network calls. The Cloud Function trigger is a thin wrapper that
injects the DeepL translator and handles the fallback on failure.
"""

from __future__ import annotations

from typing import Protocol


class TextResult(Protocol):
    """Duck-typed interface for a single DeepL translation result.

    Both ``deepl.TextResult`` (production) and test fakes satisfy this protocol.
    """

    @property
    def text(self) -> str: ...


class DeepLTranslatorProtocol(Protocol):
    """Subset of deepl.Translator used by this service.

    Defined as a Protocol so the service never imports deepl directly,
    keeping the module import-time dependencies minimal and test-friendly.
    """

    def translate_text(
        self,
        text: list[str],
        *,
        target_lang: str,
    ) -> list[TextResult]: ...


def translate_issues(
    issues: list[dict[str, str]],
    translator: DeepLTranslatorProtocol,
) -> list[dict[str, str]]:
    """Translate issue titles and descriptions to German using DeepL.

    All texts are interleaved into a single API call:
        [title_0, desc_0, title_1, desc_1, ...]
    This keeps free-tier character consumption to the absolute minimum — one
    network round-trip for any number of issues.

    Args:
        issues:     Non-empty list of {"title": str, "description": str} dicts.
                    Must not be empty; returns [] for empty input without
                    calling the API.
        translator: A DeepL-compatible translator instance (real or fake).

    Returns:
        List of translated {"title": str, "description": str} dicts,
        preserving the original order.

    Raises:
        deepl.DeepLException (or any exception from ``translate_text``) on
        API failure.  The caller is responsible for fallback handling.

    """
    if not issues:
        return []

    # Build interleaved flat list — one API call for all texts.
    flat_texts: list[str] = []
    for item in issues:
        flat_texts.append(item["title"])
        flat_texts.append(item["description"])

    results = translator.translate_text(flat_texts, target_lang="DE")

    return [
        {
            "title": results[i * 2].text,
            "description": results[i * 2 + 1].text,
        }
        for i in range(len(issues))
    ]
