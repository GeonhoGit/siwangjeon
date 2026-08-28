# 자동화 스크립트

`gen_prompts.py`는 `assets/data/cards.json`을 읽어 카드 이름·효과·강화·업 정보를 LLM에
전달할 한국어 근거로 변환한다. 카드 데이터에 없는 `description`을 빈 문자열로 사용하지
않고, 그 부재를 컨텍스트에 명시한다.

```powershell
# 기본값: LM Studio의 OpenAI 호환 서버를 켠 뒤 가변 대상 묘사를 생성·검증
lms server start
python scripts/gen_prompts.py generate

# 다른 OpenAI 호환 서버(예: Ollama, llama.cpp, vLLM)도 URL과 서버 모델 ID만 지정하면 된다.
python scripts/gen_prompts.py generate --base-url http://localhost:11434/v1 --model <서버에_올린_모델_ID>

# LLM 서버 없이 기존 결과만 검증
python scripts/gen_prompts.py validate --input art-pipeline/prompts/cards_prompts.json
```

기본 URL은 LM Studio의 `http://localhost:1234/v1`, 기본 모델 ID는
`qwen/qwen3.5-9b`다. `generate`는 먼저 `GET /models`로 모델 ID를 확인한 뒤
추론을 끌 수 있는 LM Studio 모델이면 `POST /api/v1/chat`을, 그 외 OpenAI 호환 서버면
`POST /chat/completions`를 호출한다. Ollama를 쓸 때는 해당 서버를 시작하고
`--base-url http://localhost:11434/v1`와 서버가 보고한 모델 ID를 지정한다.

기본값은 실행 편의를 위한 값이며 채택 모델이나 라이선스 판단이 아니다. 기획서 §9.3의
8B~14B급 양자화 범위에 맞는 실제 모델을 선택하되, 생성 전에 `art-pipeline/MODEL.md`의
원장 절차대로 라이선스 원문을 사람이 확인한다. 생성 결과에는 실제 `base_url`, `model`,
`temperature`, `seed`를 기록한다. LM Studio 네이티브 API는 `seed`를 받지 않으므로 이 경로의
`generation.seed`는 적용되지 않았음을 뜻하는 `null`이다. 기본 `temperature=0.0`에서는 같은
입력에 대해 사실상 결정론적으로 생성하며, 결과 JSON 자체를 커밋하므로 §11.2의 재현성 보관
목적도 지킨다. Ollama 등 OpenAI 호환 chat completions 서버에서는 요청에 `seed`가 포함되어
결과 메타데이터에도 그 값이 기록된다. 기본 `temperature=0.0`, `seed=0`은
`--temperature`, `--seed`로 바꿀 수 있다.

## 이 PC의 추론 모델

`GET /api/v1/models` 기준으로 `qwen/qwen3.5-9b`, `google/gemma-4-e4b`는 추론을
`on`/`off`로 전환할 수 있고, `openai/gpt-oss-20b`는 `low`/`medium`/`high` 추론 단계를
제공한다. `qwen3.8-27b@iq3_s`와 `qwen3.8-27b@q3_k_xl`은 서버가 추론 설정을 공개하지
않으며, `text-embedding-nomic-embed-text-v1.5`는 임베딩 전용이라 카드 묘사 생성에 쓸 수
없다. 따라서 §9.3 범위에서 검토할 수 있는 모델은 추론 모델 `qwen/qwen3.5-9b`(9B)와
`google/gemma-4-e4b`(7.5B)다.

기본 Qwen은 추론이 켜진 상태에서 짧은 대상 묘사보다 사고 과정을 먼저 길게 출력할 수 있다.
LM Studio가 이 설정을 공개하면 스크립트는 네이티브 `/api/v1/chat`에 `reasoning: "off"`와
`max_output_tokens: 256`을 보내 사고 토큰이 최종 답변을 밀어내지 않게 한다. 그 외 OpenAI
호환 서버에는 같은 256토큰 상한과 `chat_template_kwargs.enable_thinking=false` 힌트를 보낸다.
응답의 `reasoning_content`만 있고 `content`가 비었거나 `finish_reason: length`이면 생성은
실패하며, 오류 메시지에 두 원인을 구분해 표시한다.

모델이 공통 네거티브 프롬프트 단어를 다시 사용하면 스크립트는 충돌 단어를 포함한 보정 요청을
한 번만 더 보낸다. 보정 뒤에도 계약을 어기면 결과를 조용히 고치지 않고 해당 카드 오류로 중단한다.
