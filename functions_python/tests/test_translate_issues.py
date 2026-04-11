"""BDD tests for translation_service.translate_issues().

All tests use a fake in-memory translator — no DeepL API calls are made and
no characters are consumed. The service is pure (no Firebase, no Firestore).

Naming: "Given <precondition>, when <action>, then <outcome>"
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from services.translation_service import TextResult, translate_issues

# ═══════════════════════════════════════════════════════════════════════════════
# Fake translator infrastructure
# ═══════════════════════════════════════════════════════════════════════════════


class _TextResult:
    """Minimal duck-typed stand-in for deepl.TextResult."""

    def __init__(self, text: str) -> None:
        self.text = text


class _FakeTranslator:
    """Simulates deepl.Translator.translate_text without any network call.

    By default prepends "[DE]" to every source text so tests can verify
    which strings were translated. Pass ``mapping`` for exact control.
    """

    def __init__(
        self,
        mapping: dict[str, str] | None = None,
        raise_exc: Exception | None = None,
    ) -> None:
        # mapping: source_text → translated_text
        self._mapping = mapping or {}
        self._raise_exc = raise_exc
        # Record every call so tests can assert batching behaviour.
        self.calls: list[tuple[list[str], str]] = []

    def translate_text(
        self,
        text: list[str],
        target_lang: str,
    ) -> list[TextResult]:
        self.calls.append((list(text), target_lang))
        if self._raise_exc is not None:
            raise self._raise_exc
        return [_TextResult(self._mapping.get(t, f"[DE]{t}")) for t in text]


def _translator(mapping: dict[str, str] | None = None) -> _FakeTranslator:
    """Return a fake translator with optional exact-match translations."""
    return _FakeTranslator(mapping=mapping)


def _failing_translator(exc: Exception) -> _FakeTranslator:
    """Return a fake translator that raises ``exc`` when called."""
    return _FakeTranslator(raise_exc=exc)


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 1: empty input
# ═══════════════════════════════════════════════════════════════════════════════


class TestEmptyInput:
    """Scenario: the caller passes an empty issue list.

    The service must return an empty list immediately without touching
    the translator — preserving free-tier characters.
    """

    def setup_method(self) -> None:
        self.translator = _translator()
        self.result = translate_issues([], self.translator)

    def test_returns_empty_list(self) -> None:
        """Given an empty issue list, then the result is []."""
        assert self.result == []

    def test_api_not_called(self) -> None:
        """Given an empty issue list, then the DeepL API is never called."""
        assert self.translator.calls == [], (
            "translate_text must not be called for empty input — every API call consumes free-tier characters."
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 2: single issue translated
# ═══════════════════════════════════════════════════════════════════════════════


class TestSingleIssue:
    """Scenario: exactly one issue is submitted for translation."""

    def setup_method(self) -> None:
        self.translator = _translator(
            {
                "Broken heater": "Defekte Heizung",
                "The heater makes a loud noise.": "Die Heizung macht ein lautes Geräusch.",
            }
        )
        self.result = translate_issues(
            [{"title": "Broken heater", "description": "The heater makes a loud noise."}],
            self.translator,
        )

    def test_returns_one_issue(self) -> None:
        """Given one issue, then the result contains exactly one entry."""
        assert len(self.result) == 1

    def test_title_is_translated(self) -> None:
        """Given one issue, then the title is translated to German."""
        assert self.result[0]["title"] == "Defekte Heizung"

    def test_description_is_translated(self) -> None:
        """Given one issue, then the description is translated to German."""
        assert self.result[0]["description"] == "Die Heizung macht ein lautes Geräusch."

    def test_exactly_one_api_call_made(self) -> None:
        """Given one issue, then exactly one API call is made."""
        assert len(self.translator.calls) == 1

    def test_target_language_is_german(self) -> None:
        """Given one issue, then the API is called with target_lang='DE'."""
        _, target_lang = self.translator.calls[0]
        assert target_lang == "DE"


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 3: batching — multiple issues in one API call
# ═══════════════════════════════════════════════════════════════════════════════


class TestBatchingTwoIssues:
    """Scenario: two issues are submitted — must be sent in a single API call.

    This is the core cost-optimisation: two issues produce four texts
    (title_0, desc_0, title_1, desc_1) but only ONE network request.
    """

    def setup_method(self) -> None:
        self.translator = _translator()
        self.issues = [
            {"title": "Heater", "description": "Too loud."},
            {"title": "Faucet", "description": "Drips at night."},
        ]
        self.result = translate_issues(self.issues, self.translator)

    def test_exactly_one_api_call(self) -> None:
        """Given two issues, then only one translate_text call is made."""
        assert len(self.translator.calls) == 1, (
            "All issues must be batched in a single API call to minimise free-tier character consumption."
        )

    def test_four_texts_sent_in_one_call(self) -> None:
        """Given two issues, then four texts are sent in the single call."""
        texts_sent, _ = self.translator.calls[0]
        assert len(texts_sent) == 4

    def test_texts_are_interleaved(self) -> None:
        """Given two issues, then the texts are interleaved as title0, desc0, title1, desc1."""
        texts_sent, _ = self.translator.calls[0]
        assert texts_sent == ["Heater", "Too loud.", "Faucet", "Drips at night."]

    def test_returns_two_issues(self) -> None:
        """Given two issues, then the result contains exactly two entries."""
        assert len(self.result) == 2

    def test_first_issue_title_translated(self) -> None:
        assert self.result[0]["title"] == "[DE]Heater"

    def test_first_issue_description_translated(self) -> None:
        assert self.result[0]["description"] == "[DE]Too loud."

    def test_second_issue_title_translated(self) -> None:
        assert self.result[1]["title"] == "[DE]Faucet"

    def test_second_issue_description_translated(self) -> None:
        assert self.result[1]["description"] == "[DE]Drips at night."


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 4: three issues — verify order preservation
# ═══════════════════════════════════════════════════════════════════════════════


class TestThreeIssuesOrderPreserved:
    """Scenario: three issues must be returned in the same order they were submitted."""

    def setup_method(self) -> None:
        self.translator = _translator(
            {
                "A": "Ä",
                "desc_a": "Beschr_a",
                "B": "B_de",
                "desc_b": "Beschr_b",
                "C": "C_de",
                "desc_c": "Beschr_c",
            }
        )
        self.result = translate_issues(
            [
                {"title": "A", "description": "desc_a"},
                {"title": "B", "description": "desc_b"},
                {"title": "C", "description": "desc_c"},
            ],
            self.translator,
        )

    def test_six_texts_batched(self) -> None:
        texts, _ = self.translator.calls[0]
        assert len(texts) == 6

    def test_result_order_matches_input(self) -> None:
        """Translated issues appear in the same order as the originals."""
        assert [r["title"] for r in self.result] == ["Ä", "B_de", "C_de"]

    def test_descriptions_match_their_titles(self) -> None:
        """Each description stays paired with its original title."""
        assert self.result[0]["description"] == "Beschr_a"
        assert self.result[1]["description"] == "Beschr_b"
        assert self.result[2]["description"] == "Beschr_c"


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 5: German-to-German (no-op DeepL behaviour)
# ═══════════════════════════════════════════════════════════════════════════════


class TestAlreadyGerman:
    """Scenario: the issue text is already in German.

    DeepL detects the source language and returns the text unchanged
    (or with minor normalisation). The service must pass through whatever
    DeepL returns without any special-casing.
    """

    def setup_method(self) -> None:
        german_text = "Heizung defekt"
        german_desc = "Macht laute Geräusche nachts."
        # Simulate DeepL returning the same text (German → German no-op).
        self.translator = _translator({german_text: german_text, german_desc: german_desc})
        self.result = translate_issues(
            [{"title": german_text, "description": german_desc}],
            self.translator,
        )

    def test_text_passed_through_unchanged(self) -> None:
        """Given already-German text, then the result contains the same strings."""
        assert self.result[0]["title"] == "Heizung defekt"
        assert self.result[0]["description"] == "Macht laute Geräusche nachts."

    def test_api_is_still_called(self) -> None:
        """Given German text, then the API is still called — no pre-filtering."""
        # We always call DeepL regardless of detected language; DeepL handles
        # the German→German case internally at negligible cost.
        assert len(self.translator.calls) == 1


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 6: DeepL API failure — exception propagates to caller
# ═══════════════════════════════════════════════════════════════════════════════


class TestDeepLApiFailure:
    """Scenario: the DeepL API raises an exception.

    translate_issues() must NOT swallow the exception — the trigger is
    responsible for the fallback.  This keeps the service side-effect-free.
    """

    def test_exception_propagates(self) -> None:
        """Given a DeepL failure, then the exception propagates to the caller."""
        import deepl

        failing = _failing_translator(deepl.DeepLException("quota exceeded"))

        with pytest.raises(deepl.DeepLException, match="quota exceeded"):
            translate_issues(
                [{"title": "Test", "description": "Test description."}],
                failing,
            )

    def test_generic_exception_propagates(self) -> None:
        """Given any unexpected error from translate_text, then it propagates."""
        failing = _failing_translator(ConnectionError("network unreachable"))

        with pytest.raises(ConnectionError, match="network unreachable"):
            translate_issues(
                [{"title": "Test", "description": "Test description."}],
                failing,
            )


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 7: result structure integrity
# ═══════════════════════════════════════════════════════════════════════════════


class TestResultStructure:
    """Scenario: the returned dicts always have exactly 'title' and 'description' keys."""

    def setup_method(self) -> None:
        self.translator = _translator()
        self.result = translate_issues(
            [
                {"title": "Issue one", "description": "Details one."},
                {"title": "Issue two", "description": "Details two."},
            ],
            self.translator,
        )

    def test_each_result_has_title_key(self) -> None:
        for r in self.result:
            assert "title" in r

    def test_each_result_has_description_key(self) -> None:
        for r in self.result:
            assert "description" in r

    def test_no_extra_keys_in_result(self) -> None:
        for r in self.result:
            assert set(r.keys()) == {"title", "description"}, (
                "Result dicts must contain exactly 'title' and 'description' — "
                "extra keys would confuse the Flutter client."
            )


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 8: empty strings inside an issue (edge case)
# ═══════════════════════════════════════════════════════════════════════════════


class TestEmptyStringsInIssue:
    """Scenario: title or description is an empty string.

    The service must not crash — it passes the empty strings to DeepL and
    returns whatever DeepL gives back.
    """

    def test_empty_title_does_not_crash(self) -> None:
        translator = _translator({"": "", "Some description.": "[DE]Some description."})
        result = translate_issues(
            [{"title": "", "description": "Some description."}],
            translator,
        )
        assert result[0]["title"] == ""
        assert result[0]["description"] == "[DE]Some description."

    def test_empty_description_does_not_crash(self) -> None:
        translator = _translator({"Real title": "[DE]Real title", "": ""})
        result = translate_issues(
            [{"title": "Real title", "description": ""}],
            translator,
        )
        assert result[0]["title"] == "[DE]Real title"
        assert result[0]["description"] == ""


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 9: large batch (9 issues) — one call, 18 texts
# ═══════════════════════════════════════════════════════════════════════════════


class TestLargeBatchNineIssues:
    """Scenario: the practical maximum — 9 issues (one per flat task).

    Verifies that the single-call batching holds for the realistic worst case
    and that all 18 texts (9 titles + 9 descriptions) are correct.
    """

    def setup_method(self) -> None:
        self.translator = _translator()
        self.issues = [{"title": f"Issue {i}", "description": f"Description {i}."} for i in range(9)]
        self.result = translate_issues(self.issues, self.translator)

    def test_exactly_one_api_call_for_nine_issues(self) -> None:
        assert len(self.translator.calls) == 1

    def test_18_texts_batched(self) -> None:
        texts, _ = self.translator.calls[0]
        assert len(texts) == 18

    def test_all_nine_results_returned(self) -> None:
        assert len(self.result) == 9

    def test_all_titles_present(self) -> None:
        for i, r in enumerate(self.result):
            assert r["title"] == f"[DE]Issue {i}"

    def test_all_descriptions_present(self) -> None:
        for i, r in enumerate(self.result):
            assert r["description"] == f"[DE]Description {i}."
