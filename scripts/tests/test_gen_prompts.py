import importlib.util
import json
import locale
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPOSITORY_ROOT / "scripts" / "gen_prompts.py"


class PromptValidationCliTest(unittest.TestCase):
    def _write_inputs(self, directory: Path, cards: list[dict[str, str]]) -> tuple[Path, Path, Path]:
        template_path = directory / "template.txt"
        template_path.write_text(
            "swjdostyle, {subject}, centered composition, single subject, plain dark background, "
            "deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture\n",
            encoding="utf-8",
        )
        negative_path = directory / "negative.txt"
        negative_path.write_text("text, watermark, signature, letters\n", encoding="utf-8")
        prompts_path = directory / "cards_prompts.json"
        prompts_path.write_text(
            json.dumps({"schema_version": 1, "cards": cards}, ensure_ascii=False),
            encoding="utf-8",
        )
        return prompts_path, template_path, negative_path

    def _validate(self, prompts_path: Path, template_path: Path, negative_path: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "validate",
                "--input",
                str(prompts_path),
                "--template",
                str(template_path),
                "--negative",
                str(negative_path),
            ],
            capture_output=True,
            text=True,
            encoding=locale.getencoding(),
        )

    def test_validate_accepts_a_compliant_subject_without_ollama(self) -> None:
        """검증 전용 경로는 Ollama 없이 유효한 생성 결과를 통과시켜야 한다."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            prompts_path, template_path, negative_path = self._write_inputs(
                Path(temporary_directory),
                [
                    {
                        "id": "card_blade",
                        "subject": "curved bronze sword, curling crimson flames",
                        "prompt": "swjdostyle, curved bronze sword, curling crimson flames, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    }
                ],
            )

            result = self._validate(prompts_path, template_path, negative_path)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("검증 통과: 1개", result.stdout)

    def test_validate_lists_every_card_that_breaks_a_machine_rule(self) -> None:
        """규칙 위반을 한 장만 보고 중단하면 대량 검수가 다시 수작업이 된다."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            prompts_path, template_path, negative_path = self._write_inputs(
                Path(temporary_directory),
                [
                    {
                        "id": "card_word_limit",
                        "subject": "one two three four five six seven eight nine ten eleven twelve thirteen",
                        "prompt": "swjdostyle, one two three four five six seven eight nine ten eleven twelve thirteen, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    },
                    {
                        "id": "card_sentence",
                        "subject": "a warrior is holding a sword",
                        "prompt": "swjdostyle, a warrior is holding a sword, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    },
                    {
                        "id": "card_style_word",
                        "subject": "anime armored warrior, raised spear",
                        "prompt": "swjdostyle, anime armored warrior, raised spear, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    },
                    {
                        "id": "card_negative_word",
                        "subject": "bronze sword, text inscription",
                        "prompt": "swjdostyle, bronze sword, text inscription, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    },
                ],
            )

            result = self._validate(prompts_path, template_path, negative_path)

        self.assertNotEqual(result.returncode, 0)
        for card_id in ("card_word_limit", "card_sentence", "card_style_word", "card_negative_word"):
            self.assertIn(card_id, result.stderr)

    def test_validate_counts_repeated_words_and_requires_comma_separated_phrases(self) -> None:
        """집합으로 세거나 단일 구절을 허용하면 12단어·쉼표 계약을 우회할 수 있다."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            prompts_path, template_path, negative_path = self._write_inputs(
                Path(temporary_directory),
                [
                    {
                        "id": "card_repeated_words",
                        "subject": "sword sword sword sword sword sword sword, sword sword sword sword sword sword",
                        "prompt": "swjdostyle, sword sword sword sword sword sword sword, sword sword sword sword sword sword, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    },
                    {
                        "id": "card_no_comma",
                        "subject": "bronze sword",
                        "prompt": "swjdostyle, bronze sword, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    },
                ],
            )

            result = self._validate(prompts_path, template_path, negative_path)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("card_repeated_words", result.stderr)
        self.assertIn("card_no_comma", result.stderr)

    def test_validate_blocks_representative_style_era_artist_and_quality_terms(self) -> None:
        """한두 예시만 막으면 LLM이 다른 금지 범주 표현을 그대로 통과시킨다."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            prompts_path, template_path, negative_path = self._write_inputs(
                Path(temporary_directory),
                [
                    {
                        "id": "card_style_category",
                        "subject": "oil painting warrior, raised sword",
                        "prompt": "swjdostyle, oil painting warrior, raised sword, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    },
                    {
                        "id": "card_era_category",
                        "subject": "medieval warrior, steel shield",
                        "prompt": "swjdostyle, medieval warrior, steel shield, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    },
                    {
                        "id": "card_artist_category",
                        "subject": "picasso warrior, raised spear",
                        "prompt": "swjdostyle, picasso warrior, raised spear, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    },
                    {
                        "id": "card_quality_category",
                        "subject": "8k warrior, raised spear",
                        "prompt": "swjdostyle, 8k warrior, raised spear, centered composition, single subject, plain dark background, deep vermilion, jade green, ink black, muted gold, highly detailed, traditional pigment texture",
                    },
                ],
            )

            result = self._validate(prompts_path, template_path, negative_path)

        self.assertNotEqual(result.returncode, 0)
        for card_id in (
            "card_style_category",
            "card_era_category",
            "card_artist_category",
            "card_quality_category",
        ):
            self.assertIn(card_id, result.stderr)


class CardContextTest(unittest.TestCase):
    def test_context_derives_effects_and_reports_missing_description_field(self) -> None:
        """description 부재가 빈 문자열이 되면 LLM이 카드 이름만 보고 추측하게 된다."""
        spec = importlib.util.spec_from_file_location("gen_prompts", SCRIPT_PATH)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        context = module.build_card_context(
            {
                "id": "card_venom_verdict",
                "name": "독사의 판결",
                "type": "attack",
                "cost": 1,
                "effects": [
                    {"op": "damage", "value": 4},
                    {"op": "applyStatus", "status": "poison", "stacks": 3},
                ],
                "upgrade": {
                    "effects": [
                        {"op": "damage", "value": 7},
                        {"op": "applyStatus", "status": "poison", "stacks": 4},
                    ]
                },
            }
        )

        self.assertIn("설명(description) 필드 없음", context)
        self.assertIn("적에게 피해 4", context)
        self.assertIn("적에게 중독 3 부여", context)
        self.assertIn("강화 후 효과", context)


class GenerationDefaultsTest(unittest.TestCase):
    def test_default_model_stays_within_the_16gb_local_llm_range(self) -> None:
        """30B 기본값으로 되돌아가면 16GB 장비에서 파이프라인 시작 자체가 막힌다."""
        spec = importlib.util.spec_from_file_location("gen_prompts", SCRIPT_PATH)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        arguments = module.build_parser().parse_args(["generate"])

        self.assertEqual(arguments.model, "qwen3:8b")


if __name__ == "__main__":
    unittest.main()
