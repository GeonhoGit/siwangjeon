# LoRA 학습

`train_config.toml`은 실제 학습에 사용한 kohya_ss 설정을 고정한다. SDXL 파생물인
`.safetensors` 가중치와 epoch별 체크포인트는 일반 Git과 Git LFS 모두에 넣지 않는다.
실행가이드 §11.2에 따라 외장 백업과 private Release에만 보관하고, 확정한 epoch·강도와
두 백업 위치는 작업 기록에 남긴다. 공개 배포 전 라이선스 §4 의무는 `MODEL.md`를 따른다.

라이선스가 검증된 베이스 모델을 `MODEL.md`에 기록한 뒤
`pretrained_model_name_or_path`의 플레이스홀더를 실제 경로로 바꾼다.
