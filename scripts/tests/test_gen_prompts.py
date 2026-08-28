import contextlib
import importlib.util
import io
import json
import locale
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from urllib import error as urlerror
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

        self.assertEqual(arguments.base_url, "http://localhost:1234/v1")
        self.assertEqual(arguments.model, "qwen/qwen3.5-9b")
        self.assertEqual(arguments.temperature, 0.0)
        self.assertEqual(arguments.seed, 0)


class OpenAiCompatibleGenerationTest(unittest.TestCase):
    class _Response:
        def __init__(self, document: object) -> None:
            self._body = json.dumps(document, ensure_ascii=False).encode("utf-8")

        def __enter__(self) -> "OpenAiCompatibleGenerationTest._Response":
            return self

        def __exit__(self, exception_type: object, exception: object, traceback: object) -> None:
            return None

        def read(self) -> bytes:
            return self._body

    def _load_module(self) -> object:
        spec = importlib.util.spec_from_file_location("gen_prompts", SCRIPT_PATH)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_request_subject_parses_response_and_sends_deterministic_parameters(self) -> None:
        """서버별 SDK 차이로 seed가 빠지면 같은 입력의 재생성이 불가능해진다."""
        module = self._load_module()
        response = self._Response(
            {"choices": [{"message": {"content": "bronze sword, crimson flame"}}]}
        )
        with mock.patch.object(module.urlrequest, "urlopen", return_value=response) as urlopen:
            subject = module.request_subject(
                "http://localhost:1234/v1/",
                "qwen/qwen3.5-9b",
                "system contract",
                "card context",
                "card_blade",
                0.25,
                31415,
            )

        self.assertEqual(subject, "bronze sword, crimson flame")
        request = urlopen.call_args.args[0]
        self.assertEqual(request.full_url, "http://localhost:1234/v1/chat/completions")
        self.assertEqual(
            json.loads(request.data),
            {
                "model": "qwen/qwen3.5-9b",
                "messages": [
                    {"role": "system", "content": "system contract"},
                    {"role": "user", "content": "card context"},
                ],
                "temperature": 0.25,
                "seed": 31415,
                "max_tokens": 256,
                "chat_template_kwargs": {"enable_thinking": False},
            },
        )

    def test_reasoning_only_chat_response_explains_missing_final_content(self) -> None:
        """추론 토큰을 답으로 오해하면 length 원인을 보고도 재현 조건을 고칠 수 없다."""
        module = self._load_module()
        response = self._Response(
            {
                "choices": [
                    {
                        "message": {"content": "   ", "reasoning_content": "Thinking Process"},
                        "finish_reason": "stop",
                    }
                ]
            }
        )
        with mock.patch.object(module.urlrequest, "urlopen", return_value=response):
            with self.assertRaisesRegex(
                module.PipelineInputError,
                "finish_reason: stop.*reasoning_content만 있고 최종 대상 묘사 content가 없습니다",
            ):
                module.request_subject(
                    "http://localhost:1234/v1",
                    "qwen/qwen3.5-9b",
                    "system contract",
                    "card context",
                    "card_empty",
                    0.0,
                    0,
                )

    def test_length_limited_chat_response_names_the_token_limit(self) -> None:
        """빈 문자열과 length 절단은 후속 조치가 다르므로 오류 원인을 분리한다."""
        module = self._load_module()
        response = self._Response(
            {"choices": [{"message": {"content": "   "}, "finish_reason": "length"}]}
        )
        with mock.patch.object(module.urlrequest, "urlopen", return_value=response):
            with self.assertRaisesRegex(
                module.PipelineInputError,
                "finish_reason: length.*출력 토큰 한도에 도달해 최종 답이 잘렸습니다",
            ):
                module.request_subject(
                    "http://localhost:1234/v1",
                    "qwen/qwen3.5-9b",
                    "system contract",
                    "card context",
                    "card_empty",
                    0.0,
                    0,
                )

    def test_connection_refusal_explains_how_to_start_lm_studio(self) -> None:
        """서버가 꺼진 기본 환경에서는 다음 행동을 알려야 무의미한 재시도가 없다."""
        module = self._load_module()
        with mock.patch.object(
            module.urlrequest,
            "urlopen",
            side_effect=urlerror.URLError(ConnectionRefusedError("connection refused")),
        ):
            with self.assertRaisesRegex(module.PipelineInputError, "lms server start"):
                module.list_available_models("http://localhost:1234/v1")

    def test_missing_model_lists_the_models_reported_by_the_server(self) -> None:
        """모델 이름 오타를 서버 실행 실패처럼 보이게 하면 환경 진단이 늦어진다."""
        module = self._load_module()
        response = self._Response({"data": [{"id": "model-a"}, {"id": "model-b"}]})
        with mock.patch.object(module.urlrequest, "urlopen", return_value=response):
            with self.assertRaisesRegex(module.PipelineInputError, "model-a, model-b"):
                module.require_available_model("http://localhost:1234/v1", "missing-model")

    def test_generate_records_the_actual_server_and_deterministic_parameters(self) -> None:
        """결과물에 요청값이 없으면 나중에 같은 생성 조건을 복원할 수 없다."""
        module = self._load_module()
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            cards_path = directory / "cards.json"
            output_path = directory / "cards_prompts.json"
            cards_path.write_text(
                json.dumps(
                    [
                        {
                            "id": "card_blade",
                            "name": "검",
                            "effects": [{"op": "damage", "value": 4}],
                        }
                    ],
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            requests: list[object] = []

            def fake_urlopen(request: object, timeout: int) -> "OpenAiCompatibleGenerationTest._Response":
                requests.append(request)
                if request.get_method() == "GET":
                    return self._Response({"data": [{"id": "test-model"}]})
                return self._Response(
                    {"choices": [{"message": {"content": "bronze sword, crimson flame"}}]}
                )

            with (
                mock.patch.object(module.urlrequest, "urlopen", side_effect=fake_urlopen),
                contextlib.redirect_stdout(io.StringIO()),
                contextlib.redirect_stderr(io.StringIO()),
            ):
                result = module.main(
                    [
                        "generate",
                        "--cards",
                        str(cards_path),
                        "--output",
                        str(output_path),
                        "--base-url",
                        "http://example.test/v1",
                        "--model",
                        "test-model",
                        "--temperature",
                        "0.25",
                        "--seed",
                        "31415",
                    ]
                )

            document = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(result, 0)
        self.assertEqual(
            document["generation"],
            {
                "base_url": "http://example.test/v1",
                "model": "test-model",
                "temperature": 0.25,
                "seed": 31415,
            },
        )
        chat_request = next(request for request in requests if request.get_method() == "POST")
        self.assertEqual(json.loads(chat_request.data)["seed"], document["generation"]["seed"])

    def test_generate_uses_lm_studio_reasoning_off_with_a_bounded_output(self) -> None:
        """기본 Qwen은 사고 토큰만 쓰다 length로 끝날 수 있어 서버의 공식 추론 제어를 쓴다."""
        module = self._load_module()
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            cards_path = directory / "cards.json"
            output_path = directory / "cards_prompts.json"
            cards_path.write_text(
                json.dumps(
                    [{"id": "card_blade", "name": "검", "effects": [{"op": "damage", "value": 4}]}],
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            requests: list[object] = []

            def fake_urlopen(request: object, timeout: int) -> "OpenAiCompatibleGenerationTest._Response":
                requests.append(request)
                if request.full_url.endswith("/api/v1/models"):
                    return self._Response(
                        {
                            "models": [
                                {
                                    "key": "qwen/qwen3.5-9b",
                                    "capabilities": {
                                        "reasoning": {"allowed_options": ["off", "on"]}
                                    },
                                }
                            ]
                        }
                    )
                if request.full_url.endswith("/v1/models"):
                    return self._Response({"data": [{"id": "qwen/qwen3.5-9b"}]})
                return self._Response(
                    {"output": [{"type": "message", "content": "bronze sword, crimson flame"}]}
                )

            with (
                mock.patch.object(module.urlrequest, "urlopen", side_effect=fake_urlopen),
                contextlib.redirect_stdout(io.StringIO()),
                contextlib.redirect_stderr(io.StringIO()),
            ):
                result = module.main(
                    [
                        "generate",
                        "--cards",
                        str(cards_path),
                        "--output",
                        str(output_path),
                    ]
                )
            document = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(result, 0)
        native_request = next(request for request in requests if request.get_method() == "POST")
        self.assertEqual(native_request.full_url, "http://localhost:1234/api/v1/chat")
        native_payload = json.loads(native_request.data)
        self.assertEqual(native_payload["reasoning"], "off")
        self.assertEqual(native_payload["max_output_tokens"], 256)
        self.assertFalse(native_payload["store"])
        self.assertNotIn("seed", native_payload)
        self.assertIn("project-wide negative prompt", native_payload["system_prompt"])
        self.assertIn("armor", native_payload["system_prompt"])
        self.assertIsNone(document["generation"]["seed"])

    def test_generate_retries_a_negative_prompt_conflict_once(self) -> None:
        """방어 카드가 armor를 자연스럽게 고르면 실제 충돌 단어를 줘야 결과 검증까지 통과한다."""
        module = self._load_module()
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            cards_path = directory / "cards.json"
            output_path = directory / "cards_prompts.json"
            cards_path.write_text(
                json.dumps(
                    [{"id": "card_guard", "name": "수비", "effects": [{"op": "block", "value": 5}]}],
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            requests: list[object] = []
            chat_responses = iter(
                [
                    {"output": [{"type": "message", "content": "iron armor, armored guard, stance"}]},
                    {"output": [{"type": "message", "content": "iron shield, plated guard, defensive stance"}]},
                ]
            )

            def fake_urlopen(request: object, timeout: int) -> "OpenAiCompatibleGenerationTest._Response":
                requests.append(request)
                if request.full_url.endswith("/api/v1/models"):
                    return self._Response(
                        {
                            "models": [
                                {
                                    "key": "qwen/qwen3.5-9b",
                                    "capabilities": {
                                        "reasoning": {"allowed_options": ["off", "on"]}
                                    },
                                }
                            ]
                        }
                    )
                if request.full_url.endswith("/v1/models"):
                    return self._Response({"data": [{"id": "qwen/qwen3.5-9b"}]})
                return self._Response(next(chat_responses))

            with (
                mock.patch.object(module.urlrequest, "urlopen", side_effect=fake_urlopen),
                contextlib.redirect_stdout(io.StringIO()),
                contextlib.redirect_stderr(io.StringIO()),
            ):
                result = module.main(
                    ["generate", "--cards", str(cards_path), "--output", str(output_path)]
                )

            document = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(result, 0)
        chat_requests = [request for request in requests if request.get_method() == "POST"]
        self.assertEqual(len(chat_requests), 2)
        correction = json.loads(chat_requests[1].data)["input"]
        self.assertIn("armor", correction)
        self.assertEqual(document["cards"][0]["subject"], "iron shield, plated guard, defensive stance")


if __name__ == "__main__":
    unittest.main()
