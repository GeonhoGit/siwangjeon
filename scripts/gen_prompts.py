"""카드 데이터에서 재현 가능한 아트 프롬프트를 생성하고 검증한다."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
ART_PIPELINE_ROOT = REPOSITORY_ROOT / "art-pipeline"
DEFAULT_CARDS_PATH = REPOSITORY_ROOT / "assets" / "data" / "cards.json"
DEFAULT_TEMPLATE_PATH = ART_PIPELINE_ROOT / "prompts" / "template.txt"
DEFAULT_NEGATIVE_PATH = ART_PIPELINE_ROOT / "prompts" / "negative.txt"
DEFAULT_SYSTEM_PROMPT_PATH = ART_PIPELINE_ROOT / "prompts" / "system_prompt.md"
DEFAULT_RULES_PATH = ART_PIPELINE_ROOT / "prompts" / "validation_rules.json"
DEFAULT_OUTPUT_PATH = ART_PIPELINE_ROOT / "prompts" / "cards_prompts.json"

# 기획서 §9.3의 RTX 5080 16GB 기준은 8B~14B 양자화 모델이다. qwen3:8b는 그 범위의
# 하한이라 다른 아트 도구와 VRAM을 공유해도 시작 가능하다. 이는 MODEL.md의 채택 결정이
# 아니라 --model로 바꿀 수 있는 실행 기본값이다.
DEFAULT_MODEL = "qwen3:8b"


class PipelineInputError(ValueError):
    """사용자가 고쳐야 하는 파일·도구 입력 문제를 나타낸다."""


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except FileNotFoundError as error:
        raise PipelineInputError(f"필수 파일을 찾을 수 없습니다: {path}") from error


def read_json(path: Path) -> Any:
    try:
        with path.open(encoding="utf-8") as source:
            return json.load(source)
    except FileNotFoundError as error:
        raise PipelineInputError(f"필수 파일을 찾을 수 없습니다: {path}") from error
    except json.JSONDecodeError as error:
        raise PipelineInputError(f"JSON 형식이 잘못되었습니다: {path} ({error.msg})") from error


def require_mapping(value: Any, label: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise PipelineInputError(f"{label}은(는) JSON 객체여야 합니다.")
    return value


def require_list(value: Any, label: str) -> Sequence[Any]:
    if not isinstance(value, list):
        raise PipelineInputError(f"{label}은(는) JSON 배열이어야 합니다.")
    return value


def _effect_amount(effect: Mapping[str, Any], value_key: str, tuning_key: str) -> str:
    if value_key in effect:
        return str(effect[value_key])
    if tuning_key in effect:
        return f"튜닝값({effect[tuning_key]})"
    raise PipelineInputError(f"효과에 {value_key} 또는 {tuning_key}가 없습니다: {effect}")


def _target_label(effect: Mapping[str, Any]) -> str:
    return "자신" if effect.get("target") == "self" else "적"


def describe_effect(effect: Mapping[str, Any]) -> str:
    """cards.json의 규칙 데이터를 LLM이 읽을 수 있는 한국어 근거로 바꾼다."""
    operation = effect.get("op")
    if not isinstance(operation, str):
        raise PipelineInputError(f"효과에 op 문자열이 없습니다: {effect}")

    if operation == "damage":
        amount = _effect_amount(effect, "value", "valueTuning")
        scaling = ""
        if effect.get("scaleWith") == "karma":
            scale = effect.get("scale")
            scaling = f" (업에 비례해 추가 증가, 배율 {scale})" if scale is not None else " (업에 비례해 추가 증가)"
        return f"적에게 피해 {amount}{scaling}"
    if operation == "block":
        return f"자신에게 방어도 {_effect_amount(effect, 'value', 'valueTuning')}"
    if operation == "applyStatus":
        status = effect.get("status")
        if not isinstance(status, str):
            raise PipelineInputError(f"상태 부여 효과에 status가 없습니다: {effect}")
        status_names = {
            "poison": "중독",
            "weak": "약화",
            "vulnerable": "취약",
            "grudge": "원한",
            "strength": "힘",
            "dexterity": "민첩",
        }
        stacks = _effect_amount(effect, "stacks", "stacksTuning")
        return f"{_target_label(effect)}에게 {status_names.get(status, status)} {stacks} 부여"
    if operation == "draw":
        return f"카드 {_effect_amount(effect, 'count', 'countTuning')}장 뽑기"
    if operation == "gainEnergy":
        return f"에너지 {_effect_amount(effect, 'amount', 'amountTuning')} 획득"
    if operation == "loseHp":
        return f"체력 {_effect_amount(effect, 'amount', 'amountTuning')} 잃기"
    if operation == "changeKarma":
        amount = _effect_amount(effect, "amount", "amountTuning")
        direction = "감소" if effect.get("negative") else "증가"
        return f"업 {amount} {direction}"
    if operation == "spendBlock":
        return f"방어도 {_effect_amount(effect, 'amount', 'amountTuning')} 소모"

    raise PipelineInputError(f"알 수 없는 효과 op입니다: {operation}")


def _describe_effects(value: Any, label: str) -> list[str]:
    effects = require_list(value, label)
    if not effects:
        raise PipelineInputError(f"{label}이(가) 비어 있습니다.")
    return [describe_effect(require_mapping(effect, label)) for effect in effects]


def build_card_context(card: Mapping[str, Any]) -> str:
    """LLM이 이름만 추측하지 않도록 카드 데이터의 현재 필드를 모두 노출한다."""
    card_id = card.get("id")
    name = card.get("name")
    if not isinstance(card_id, str) or not isinstance(name, str):
        raise PipelineInputError("카드에는 문자열 id와 name이 필요합니다.")

    lines = [
        f"카드 ID: {card_id}",
        f"카드 이름: {name}",
        "설명(description) 필드 없음: cards.json의 name·effects·upgrade·karma로 대상 묘사 근거를 만듭니다.",
    ]
    if isinstance(card.get("type"), str):
        lines.append(f"종류: {card['type']}")
    if "cost" in card:
        lines.append(f"비용: {card['cost']}")
    if "karma" in card:
        lines.append(f"고유 업 수치: {card['karma']}")

    lines.append("기본 효과:")
    lines.extend(f"- {description}" for description in _describe_effects(card.get("effects"), "effects"))

    upgrade = card.get("upgrade")
    if upgrade is not None:
        upgrade_mapping = require_mapping(upgrade, "upgrade")
        lines.append("강화 후 효과:")
        lines.extend(
            f"- {description}"
            for description in _describe_effects(upgrade_mapping.get("effects"), "upgrade.effects")
        )
    return "\n".join(lines)


def render_prompt(template: str, subject: str) -> str:
    if template.count("{subject}") != 1:
        raise PipelineInputError("프롬프트 템플릿에는 {subject} 플레이스홀더가 정확히 하나 있어야 합니다.")
    try:
        return template.format(subject=subject.strip())
    except KeyError as error:
        raise PipelineInputError(f"알 수 없는 템플릿 플레이스홀더입니다: {error.args[0]}") from error


def _word_tokens(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+(?:[-'][a-z0-9]+)*", text.lower())


def _words(text: str) -> set[str]:
    return set(_word_tokens(text))


def _contains_term(text: str, term: str) -> bool:
    pattern = rf"(?<![a-z0-9]){re.escape(term.lower())}(?![a-z0-9])"
    return re.search(pattern, text.lower()) is not None


def load_rules(path: Path) -> Mapping[str, Any]:
    rules = require_mapping(read_json(path), "검증 규칙")
    if not isinstance(rules.get("max_subject_words"), int):
        raise PipelineInputError("검증 규칙의 max_subject_words는 정수여야 합니다.")
    for key in ("sentence_verbs", "banned_terms"):
        values = rules.get(key)
        if not isinstance(values, list) or not all(isinstance(value, str) for value in values):
            raise PipelineInputError(f"검증 규칙의 {key}는 문자열 배열이어야 합니다.")
    return rules


def validate_subject(subject: str, rules: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    if not subject.strip():
        return ["subject가 비어 있습니다."]
    if "\n" in subject or "\r" in subject:
        errors.append("subject는 한 줄이어야 합니다.")
    word_count = len(_word_tokens(subject))
    maximum = rules["max_subject_words"]
    if word_count > maximum:
        errors.append(f"subject가 {word_count}단어입니다. 최대 {maximum}단어여야 합니다.")
    if any(mark in subject for mark in (".", "!", "?", ";", ":")):
        errors.append("subject에는 설명 문장을 나타내는 종결·연결 문장부호를 쓸 수 없습니다.")

    phrases = [phrase.strip() for phrase in subject.split(",")]
    if len(phrases) < 2:
        errors.append("subject는 쉼표로 구분한 명사구를 두 개 이상 포함해야 합니다.")
    if any(not phrase for phrase in phrases):
        errors.append("subject의 쉼표 사이에는 비어 있지 않은 명사구가 필요합니다.")
    elif not all(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9' -]*", phrase) for phrase in phrases):
        errors.append("subject는 쉼표로 나눈 영문 명사구만 사용할 수 있습니다.")

    subject_words = _words(subject)
    sentence_verbs = set(rules["sentence_verbs"])
    verbs = sorted(subject_words.intersection(sentence_verbs))
    if verbs:
        errors.append(f"subject에 설명 문장 표지 동사가 있습니다: {', '.join(verbs)}")

    banned_terms = [term for term in rules["banned_terms"] if _contains_term(subject, term)]
    if banned_terms:
        errors.append(f"subject에 금지된 화풍·시대·작가·품질 단어가 있습니다: {', '.join(banned_terms)}")
    return errors


def validate_prompt_document(
    document: Any,
    template: str,
    negative_prompt: str,
    rules: Mapping[str, Any],
) -> list[tuple[str, str]]:
    document_mapping = require_mapping(document, "프롬프트 문서")
    cards = require_list(document_mapping.get("cards"), "프롬프트 문서 cards")
    if not cards:
        return [("<문서>", "cards가 비어 있습니다.")]

    negative_words = _words(negative_prompt)
    issues: list[tuple[str, str]] = []
    for index, value in enumerate(cards, start=1):
        card = require_mapping(value, f"cards[{index}]")
        card_id = card.get("id")
        display_id = card_id if isinstance(card_id, str) and card_id else f"<cards[{index}]>"
        subject = card.get("subject")
        prompt = card.get("prompt")
        if not isinstance(subject, str):
            issues.append((display_id, "subject 문자열이 없습니다."))
            continue
        if not isinstance(prompt, str):
            issues.append((display_id, "prompt 문자열이 없습니다."))
            continue

        issues.extend((display_id, message) for message in validate_subject(subject, rules))
        expected_prompt = render_prompt(template, subject)
        if prompt != expected_prompt:
            issues.append((display_id, "prompt가 버전 관리되는 template.txt와 일치하지 않습니다."))
        conflicts = sorted(_words(prompt).intersection(negative_words))
        if conflicts:
            issues.append(
                (display_id, f"positive prompt에 네거티브 프롬프트 단어가 있습니다: {', '.join(conflicts)}")
            )
    return issues


def report_validation(issues: Sequence[tuple[str, str]], card_count: int) -> int:
    if not issues:
        print(f"검증 통과: {card_count}개 카드")
        return 0

    grouped: dict[str, list[str]] = {}
    for card_id, message in issues:
        grouped.setdefault(card_id, []).append(message)
    print(f"검증 실패: {len(grouped)}개 카드", file=sys.stderr)
    for card_id, messages in grouped.items():
        print(f"- {card_id}", file=sys.stderr)
        for message in messages:
            print(f"  - {message}", file=sys.stderr)
    return 1


def validate_file(input_path: Path, template_path: Path, negative_path: Path, rules_path: Path) -> int:
    document = read_json(input_path)
    template = read_text(template_path)
    negative_prompt = read_text(negative_path)
    rules = load_rules(rules_path)
    issues = validate_prompt_document(document, template, negative_prompt, rules)
    cards = require_list(require_mapping(document, "프롬프트 문서").get("cards"), "프롬프트 문서 cards")
    return report_validation(issues, len(cards))


def request_subject(model: str, system_prompt: str, card_context: str) -> str:
    instruction = f"{system_prompt}\n\n{card_context}"
    try:
        completed = subprocess.run(
            ["ollama", "run", model, instruction],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
    except FileNotFoundError as error:
        raise PipelineInputError(
            "Ollama를 찾을 수 없습니다. 생성에는 Ollama를 설치하거나, 기존 파일 검증에는 "
            "validate 명령을 사용하세요."
        ) from error
    if completed.returncode != 0:
        detail = completed.stderr.strip() or "출력 없음"
        raise PipelineInputError(f"Ollama 생성이 실패했습니다 ({model}): {detail}")
    lines = [line.strip() for line in completed.stdout.splitlines() if line.strip()]
    if not lines:
        raise PipelineInputError(f"Ollama가 카드 대상 묘사를 반환하지 않았습니다 ({model}).")
    return lines[-1]


def generate_prompts(arguments: argparse.Namespace) -> int:
    cards = require_list(read_json(arguments.cards), "cards.json")
    template = read_text(arguments.template)
    system_prompt = read_text(arguments.system_prompt)
    negative_prompt = read_text(arguments.negative)
    rules = load_rules(arguments.rules)

    missing_description_count = sum(
        1 for value in cards if isinstance(value, Mapping) and "description" not in value
    )
    if missing_description_count:
        print(
            f"정보: cards.json의 {missing_description_count}개 카드에 description 필드가 없습니다. "
            "name·effects·upgrade·karma를 LLM 근거로 사용합니다.",
            file=sys.stderr,
        )

    records: list[dict[str, str]] = []
    for index, value in enumerate(cards, start=1):
        card = require_mapping(value, f"cards.json[{index}]")
        card_id = card.get("id")
        if not isinstance(card_id, str) or not card_id:
            raise PipelineInputError(f"cards.json[{index}]에 id 문자열이 없습니다.")
        subject = request_subject(arguments.model, system_prompt, build_card_context(card))
        records.append(
            {
                "id": card_id,
                "subject": subject,
                "prompt": render_prompt(template, subject),
            }
        )

    document = {
        "schema_version": 1,
        "model": arguments.model,
        "template": str(arguments.template.relative_to(REPOSITORY_ROOT)),
        "negative_prompt": str(arguments.negative.relative_to(REPOSITORY_ROOT)),
        "cards": records,
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        json.dumps(document, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    issues = validate_prompt_document(document, template, negative_prompt, rules)
    return report_validation(issues, len(records))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="카드 아트 프롬프트 생성 및 검증")
    commands = parser.add_subparsers(dest="command", required=True)

    generate = commands.add_parser("generate", help="Ollama로 가변 대상 묘사를 생성하고 검증")
    generate.add_argument("--cards", type=Path, default=DEFAULT_CARDS_PATH)
    generate.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE_PATH)
    generate.add_argument("--negative", type=Path, default=DEFAULT_NEGATIVE_PATH)
    generate.add_argument("--system-prompt", type=Path, default=DEFAULT_SYSTEM_PROMPT_PATH)
    generate.add_argument("--rules", type=Path, default=DEFAULT_RULES_PATH)
    generate.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH)
    generate.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help="Ollama 모델 태그 (기본값: qwen3:8b; §9.3의 8B~14B급 범위)",
    )

    validate = commands.add_parser("validate", help="Ollama 없이 기존 프롬프트 파일만 검증")
    validate.add_argument("--input", type=Path, default=DEFAULT_OUTPUT_PATH)
    validate.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE_PATH)
    validate.add_argument("--negative", type=Path, default=DEFAULT_NEGATIVE_PATH)
    validate.add_argument("--rules", type=Path, default=DEFAULT_RULES_PATH)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = build_parser().parse_args(argv)
    try:
        if arguments.command == "generate":
            return generate_prompts(arguments)
        return validate_file(arguments.input, arguments.template, arguments.negative, arguments.rules)
    except PipelineInputError as error:
        print(f"오류: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
