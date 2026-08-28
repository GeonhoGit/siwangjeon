# 자동화 스크립트

`gen_prompts.py`는 `assets/data/cards.json`을 읽어 카드 이름·효과·강화·업 정보를 LLM에
전달할 한국어 근거로 변환한다. 카드 데이터에 없는 `description`을 빈 문자열로 사용하지
않고, 그 부재를 컨텍스트에 명시한다.

```powershell
# Ollama로 가변 대상 묘사를 만들고 곧바로 규칙 검증
python scripts/gen_prompts.py generate

# Ollama 없이 기존 결과만 검증
python scripts/gen_prompts.py validate --input art-pipeline/prompts/cards_prompts.json
```

기본 모델은 `qwen3:8b`다. RTX 5080 16GB에서는 기획서 §9.3의 8B~14B급 양자화 범위가
30B급보다 적정하므로, 실제 환경에 맞는 태그는 `generate --model <태그>`로 바꾼다.
