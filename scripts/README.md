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
`POST /chat/completions`를 호출하므로, LM Studio·Ollama·llama.cpp·vLLM에 같은 코드 경로를
쓴다. Ollama를 쓸 때는 해당 서버를 시작하고 `--base-url http://localhost:11434/v1`와 서버가
보고한 모델 ID를 지정한다.

기본값은 실행 편의를 위한 값이며 채택 모델이나 라이선스 판단이 아니다. 기획서 §9.3의
8B~14B급 양자화 범위에 맞는 실제 모델을 선택하되, 생성 전에 `art-pipeline/MODEL.md`의
원장 절차대로 라이선스 원문을 사람이 확인한다. 생성 결과에는 실제 `base_url`, `model`,
`temperature`, `seed`를 기록한다. 기본 `temperature=0.0`, `seed=0`은
`--temperature`, `--seed`로 바꿀 수 있다.
