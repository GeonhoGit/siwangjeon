"""카드 데이터에서 재현 가능한 아트 프롬프트를 생성하고 검증한다."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence
from urllib import error as urlerror
from urllib import request as urlrequest


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
ART_PIPELINE_ROOT = REPOSITORY_ROOT / "art-pipeline"
DEFAULT_CARDS_PATH = REPOSITORY_ROOT / "assets" / "data" / "cards.json"
DEFAULT_TEMPLATE_PATH = ART_PIPELINE_ROOT / "prompts" / "template.txt"
DEFAULT_NEGATIVE_PATH = ART_PIPELINE_ROOT / "prompts" / "negative.txt"
DEFAULT_SYSTEM_PROMPT_PATH = ART_PIPELINE_ROOT / "prompts" / "system_prompt.md"
DEFAULT_RULES_PATH = ART_PIPELINE_ROOT / "prompts" / "validation_rules.json"
DEFAULT_OUTPUT_PATH = ART_PIPELINE_ROOT / "prompts" / "cards_prompts.json"

# 기획서 §9.3의 RTX 5080 16GB 기준은 8B~14B 양자화 모델이다. 이 값은 그 범위의
# 로컬 실행 기본값일 뿐이며, MODEL.md의 채택 결정이나 라이선스 판단이 아니다.
DEFAULT_BASE_URL = "http://localhost:1234/v1"
DEFAULT_MODEL = "qwen/qwen3.5-9b"
DEFAULT_TEMPERATURE = 0.0
DEFAULT_SEED = 0
REQUEST_TIMEOUT_SECONDS = 60
# 대상 묘사는 계약상 12단어 이내라 256토큰이면 충분하다. 추론 모델은 이 상한 안에서
# 사고 과정만 길게 쓰고 최종 답을 못 낼 수 있으므로, LM Studio가 지원하면 추론을 끈다.
MAX_OUTPUT_TOKENS = 256
# 공통 계약만으로는 카드 맥락에 따라 네거티브 단어가 섞일 수 있다. 실제 충돌 단어를 한 번
# 되돌려 주되 무한 재시도로 생성 결과와 실행 시간을 불확실하게 만들지는 않는다.
MAX_SUBJECT_ATTEMPTS = 2


class PipelineInputError(ValueError):
    """사용자가 고쳐야 하는 파일·도구 입력 문제를 나타낸다."""


class LlmResponseError(PipelineInputError):
    """OpenAI 호환 서버가 기대한 JSON 응답을 반환하지 않았음을 나타낸다."""


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


def _endpoint_url(base_url: str, path: str) -> str:
    return f"{base_url.rstrip('/')}/{path.lstrip('/')}"


def _lm_studio_native_chat_endpoint(base_url: str, model: str) -> str | None:
    """추론을 끌 수 있는 LM Studio 모델에만 네이티브 chat 경로를 사용한다."""
    normalized_base_url = base_url.rstrip("/")
    if not normalized_base_url.endswith("/v1"):
        return None

    lm_studio_base_url = normalized_base_url[: -len("/v1")]
    models_endpoint = _endpoint_url(lm_studio_base_url, "api/v1/models")
    request = urlrequest.Request(models_endpoint, headers={"Accept": "application/json"}, method="GET")
    try:
        response = _read_json_response(request, base_url)
    except PipelineInputError:
        # 다른 OpenAI 호환 서버는 이 비표준 경로를 제공하지 않을 수 있으므로 기존 경로를 쓴다.
        return None

    if not isinstance(response, Mapping) or not isinstance(response.get("models"), list):
        return None
    for available_model in response["models"]:
        if not isinstance(available_model, Mapping) or available_model.get("key") != model:
            continue
        capabilities = available_model.get("capabilities")
        reasoning = capabilities.get("reasoning") if isinstance(capabilities, Mapping) else None
        allowed_options = reasoning.get("allowed_options") if isinstance(reasoning, Mapping) else None
        if isinstance(allowed_options, list) and "off" in allowed_options:
            # LM Studio의 OpenAI 호환 경로는 chat_template_kwargs를 무시할 수 있다. 네이티브
            # 경로의 reasoning=off는 모델 메타데이터로 지원 여부를 확인한 뒤에만 보낸다.
            return _endpoint_url(lm_studio_base_url, "api/v1/chat")
    return None


def _connection_error(base_url: str) -> PipelineInputError:
    return PipelineInputError(
        f"OpenAI 호환 서버에 연결할 수 없습니다: {base_url}. "
        "LM Studio를 사용한다면 `lms server start`로 로컬 서버를 시작한 뒤 다시 실행하세요."
    )


def _read_json_response(request: urlrequest.Request, base_url: str) -> Any:
    try:
        with urlrequest.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            payload = response.read()
    except urlerror.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace").strip() or error.reason
        raise PipelineInputError(
            f"OpenAI 호환 서버 요청이 실패했습니다 ({error.code}, {request.full_url}): {detail}"
        ) from error
    except urlerror.URLError as error:
        raise _connection_error(base_url) from error
    except TimeoutError as error:
        raise _connection_error(base_url) from error

    try:
        return json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise LlmResponseError(f"서버 응답이 JSON 형식이 아닙니다: {request.full_url}") from error


def list_available_models(base_url: str) -> list[str]:
    endpoint = _endpoint_url(base_url, "models")
    response = _read_json_response(
        urlrequest.Request(endpoint, headers={"Accept": "application/json"}, method="GET"),
        base_url,
    )
    if not isinstance(response, Mapping) or not isinstance(response.get("data"), list):
        raise LlmResponseError(f"모델 목록 응답 형식이 잘못되었습니다: {endpoint}")

    model_ids = [
        model["id"]
        for model in response["data"]
        if isinstance(model, Mapping) and isinstance(model.get("id"), str) and model["id"]
    ]
    if not model_ids:
        raise LlmResponseError(f"사용 가능한 모델을 찾을 수 없습니다: {endpoint}")
    return model_ids


def require_available_model(base_url: str, model: str) -> None:
    available_models = list_available_models(base_url)
    if model not in available_models:
        raise PipelineInputError(
            f"요청한 모델이 서버에 없습니다: {model}. "
            f"사용 가능한 모델: {', '.join(available_models)}"
        )


def _empty_subject_error(
    card_id: str,
    finish_reason: object,
    reasoning_content: object,
) -> PipelineInputError:
    reason = finish_reason if isinstance(finish_reason, str) and finish_reason else "없음"
    message = f"카드 {card_id}: 대상 묘사 응답이 비어 있습니다 (finish_reason: {reason})."
    if isinstance(reasoning_content, str) and reasoning_content.strip():
        message += " reasoning_content만 있고 최종 대상 묘사 content가 없습니다."
        if reason == "length":
            message += " 추론이 출력 토큰 한도에 도달해 최종 답을 쓰기 전에 끝났습니다."
    elif reason == "length":
        message += " 출력 토큰 한도에 도달해 최종 답이 잘렸습니다."
    else:
        message += " 모델이 최종 대상 묘사를 반환하지 않았습니다."
    return PipelineInputError(message)


def _request_lm_studio_subject(
    endpoint: str,
    base_url: str,
    model: str,
    system_prompt: str,
    card_context: str,
    card_id: str,
    temperature: float,
) -> str:
    payload = {
        "model": model,
        "system_prompt": system_prompt,
        "input": card_context,
        "temperature": temperature,
        "max_output_tokens": MAX_OUTPUT_TOKENS,
        "reasoning": "off",
        "store": False,
    }
    request = urlrequest.Request(
        endpoint,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Accept": "application/json", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        response = _read_json_response(request, base_url)
    except LlmResponseError as error:
        raise PipelineInputError(f"카드 {card_id}: {error}") from error
    try:
        output = response["output"]
        message = next(
            item for item in output if isinstance(item, Mapping) and item.get("type") == "message"
        )
        subject = message.get("content")
    except (KeyError, StopIteration, TypeError) as error:
        raise PipelineInputError(
            f"카드 {card_id}: LM Studio chat 응답에 최종 대상 묘사가 없습니다."
        ) from error
    if not isinstance(subject, str) or not subject.strip():
        raise PipelineInputError(f"카드 {card_id}: LM Studio가 빈 대상 묘사를 반환했습니다.")
    return subject.strip()


def _system_prompt_with_negative_terms(system_prompt: str, negative_prompt: str) -> str:
    """대상 묘사가 공통 네거티브 프롬프트와 충돌하지 않도록 단일 목록을 전달한다."""
    return (
        f"{system_prompt}\n\n"
        "Do not use any word or phrase from this project-wide negative prompt in your output:\n"
        f"{negative_prompt}"
    )


def _generated_subject_issues(
    subject: str,
    rules: Mapping[str, Any],
    negative_prompt: str,
) -> list[str]:
    issues = validate_subject(subject, rules)
    conflicts = sorted(_words(subject).intersection(_words(negative_prompt)))
    if conflicts:
        issues.append(f"subject uses forbidden negative prompt words: {', '.join(conflicts)}")
    return issues


def _corrected_card_context(
    card_context: str,
    subject: str,
    issues: Sequence[str],
    max_subject_words: int,
) -> str:
    return (
        f"{card_context}\n\n"
        f"Your previous output was: {subject}\n"
        f"It failed these machine rules: {'; '.join(issues)}\n"
        "Return exactly three comma-separated English noun phrases with one to three English words each, "
        f"at most {max_subject_words} English words total, and no explanation."
    )


def request_subject(
    base_url: str,
    model: str,
    system_prompt: str,
    card_context: str,
    card_id: str,
    temperature: float,
    seed: int,
    lm_studio_native_endpoint: str | None = None,
) -> str:
    if lm_studio_native_endpoint is not None:
        # /api/v1/chat은 seed를 허용하지 않아 보내면 400이 된다. 적용하지 못한 값은 산출물에
        # null로 남겨, 실제 요청 조건으로 오인하지 않게 generate_prompts에서 구분한다.
        return _request_lm_studio_subject(
            lm_studio_native_endpoint,
            base_url,
            model,
            system_prompt,
            card_context,
            card_id,
            temperature,
        )

    endpoint = _endpoint_url(base_url, "chat/completions")
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": card_context},
        ],
        "temperature": temperature,
        "seed": seed,
        "max_tokens": MAX_OUTPUT_TOKENS,
        "chat_template_kwargs": {"enable_thinking": False},
    }
    request = urlrequest.Request(
        endpoint,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Accept": "application/json", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        response = _read_json_response(request, base_url)
    except LlmResponseError as error:
        raise PipelineInputError(f"카드 {card_id}: {error}") from error
    try:
        choices = response["choices"]
        choice = choices[0]
        message = choice["message"]
        subject = message.get("content")
    except (KeyError, IndexError, TypeError) as error:
        raise PipelineInputError(
            f"카드 {card_id}: OpenAI 호환 chat completions 응답 형식이 잘못되었습니다."
        ) from error
    if not isinstance(subject, str) or not subject.strip():
        finish_reason = choice.get("finish_reason") if isinstance(choice, Mapping) else None
        reasoning_content = message.get("reasoning_content") if isinstance(message, Mapping) else None
        raise _empty_subject_error(card_id, finish_reason, reasoning_content)
    return subject.strip()


def generate_prompts(arguments: argparse.Namespace) -> int:
    cards = require_list(read_json(arguments.cards), "cards.json")
    template = read_text(arguments.template)
    negative_prompt = read_text(arguments.negative)
    system_prompt = _system_prompt_with_negative_terms(
        read_text(arguments.system_prompt),
        negative_prompt,
    )
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

    require_available_model(arguments.base_url, arguments.model)
    lm_studio_native_endpoint = _lm_studio_native_chat_endpoint(
        arguments.base_url,
        arguments.model,
    )

    records: list[dict[str, str]] = []
    for index, value in enumerate(cards, start=1):
        card = require_mapping(value, f"cards.json[{index}]")
        card_id = card.get("id")
        if not isinstance(card_id, str) or not card_id:
            raise PipelineInputError(f"cards.json[{index}]에 id 문자열이 없습니다.")
        card_context = build_card_context(card)
        for attempt in range(MAX_SUBJECT_ATTEMPTS):
            subject = request_subject(
                arguments.base_url,
                arguments.model,
                system_prompt,
                card_context,
                card_id,
                arguments.temperature,
                arguments.seed,
                lm_studio_native_endpoint,
            )
            subject_issues = _generated_subject_issues(subject, rules, negative_prompt)
            if not subject_issues:
                break
            if attempt + 1 < MAX_SUBJECT_ATTEMPTS:
                card_context = _corrected_card_context(
                    card_context,
                    subject,
                    subject_issues,
                    rules["max_subject_words"],
                )
        else:
            raise PipelineInputError(f"카드 {card_id}: 대상 묘사 형식이 잘못되었습니다: {subject_issues[0]}")
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
        "generation": {
            "base_url": arguments.base_url,
            "model": arguments.model,
            "temperature": arguments.temperature,
            "seed": arguments.seed if lm_studio_native_endpoint is None else None,
        },
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

    generate = commands.add_parser("generate", help="OpenAI 호환 서버로 가변 대상 묘사를 생성하고 검증")
    generate.add_argument("--cards", type=Path, default=DEFAULT_CARDS_PATH)
    generate.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE_PATH)
    generate.add_argument("--negative", type=Path, default=DEFAULT_NEGATIVE_PATH)
    generate.add_argument("--system-prompt", type=Path, default=DEFAULT_SYSTEM_PROMPT_PATH)
    generate.add_argument("--rules", type=Path, default=DEFAULT_RULES_PATH)
    generate.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH)
    generate.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help="서버 모델 ID (기본값: qwen/qwen3.5-9b; §9.3의 8B~14B급 범위)",
    )
    generate.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help="OpenAI 호환 API 기본 URL (기본값: http://localhost:1234/v1)",
    )
    generate.add_argument(
        "--temperature",
        type=float,
        default=DEFAULT_TEMPERATURE,
        help="chat completions temperature (기본값: 0.0)",
    )
    generate.add_argument(
        "--seed",
        type=int,
        default=DEFAULT_SEED,
        help="chat completions seed (기본값: 0)",
    )

    validate = commands.add_parser("validate", help="LLM 서버 없이 기존 프롬프트 파일만 검증")
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
