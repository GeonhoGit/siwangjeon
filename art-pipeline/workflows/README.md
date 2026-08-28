# ComfyUI 워크플로

`card_art_api.json`은 카드 아트용 **API Format** 워크플로 템플릿이다. 아직 모델을
채택하지 않았으므로 체크포인트 이름은 플레이스홀더다. `MODEL.md`의 라이선스 항목을
작성한 뒤 해당 값만 실제 파일명으로 바꾸고, ComfyUI에서 Save (API Format)으로 다시
내보내어 이 파일을 갱신한다.

`enemy_api.json`과 `boss_api.json`은 아직 만들지 않았다. 이 두 예약 경로에는 카드용
워크플로를 복사하지 않는다. 적은 스프라이트 출력 해상도·투명 배경·전신 구도를, 보스는
별도 출력 해상도·더 큰 실루엣과 여백 구도를 확정한 뒤 각각 ComfyUI **API Format**으로
내보낸다. 확정 전에는 가짜 워크플로 JSON을 커밋하지 않는다.

`generation_defaults.json`은 해상도·샘플러·고정 시드의 기준 파일이다. 워크플로를
수정할 때 두 파일의 같은 값을 함께 갱신해 diff로 재현성 변경을 검토한다.

ComfyUI API JSON은 텍스트 파일을 참조할 수 없으므로 노드 `4`에는
`prompts/negative.txt`의 내용을 의도적으로 복사한다. 네거티브 프롬프트를 바꾸면 두
파일을 같은 커밋에서 함께 갱신하고, 실행 전에 노드 `4.inputs.text`와
`negative.txt`가 완전히 같은지 확인한다.
