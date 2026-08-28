# 프롬프트 계약

`template.txt`에는 카드마다 바뀌지 않는 트리거·구도·팔레트·품질 구간만 둔다.
`negative.txt`는 모든 카드에 같은 네거티브 프롬프트다. `system_prompt.md`는 LLM이
만들 수 있는 가변 대상 묘사의 계약이고, `validation_rules.json`은 그중 기계가 검사할
수 있는 규칙이다.

`cards_prompts.json`은 `scripts/gen_prompts.py generate`가 만든 뒤 사람이 눈으로
검토하고 커밋하는 산출물이다. 이 파일은 아직 생성하지 않았으며, 생성 이미지는 이
디렉터리에 두지 않는다.
