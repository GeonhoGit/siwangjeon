# 채택 모델·라이선스 원장

아래 원장은 사람이 라이선스 원문을 읽고 상업 이용 조건을 확인한 뒤 기록한다.
오픈웨이트라는 사실만으로 상업 이용 가능하다고 판단하지 않는다.

| 역할 | 이름 | 버전·리비전 | 라이선스 이름 | 라이선스 원문 URL 또는 저장 경로 | 상업 이용 가부·제한 | 확인일 | 확인 근거·확인자 |
|---|---|---|---|---|---|---|---|
| 베이스 모델 | `stable-diffusion-xl-base-1.0` (stabilityai) | 1.0 | CreativeML Open RAIL++-M (2023-07-26) | https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md | 가능 — 상업 이용을 제한하는 조항이 없고, no-charge·royalty-free로 복제·배포·서브라이선스를 허용한다. 단 Attachment A의 금지 용도에는 쓸 수 없다. | 2026-08-28 | 라이선스 원문을 확인했다. 기획서 §9.4가 채택 가능하다고 든 Apache 2.0 / CreativeML Open RAIL++-M 중 후자다. |
| 스타일 LoRA | 미선정 |  |  |  |  |  |  |
| 로컬 LLM | 미선정 |  |  |  |  |  |  |

## 생성물(Output)

원문은 다음과 같이 생성물에 대한 권리를 주장하지 않는다.

> "Licensor claims no rights in the Output You generate using the Model. You are accountable for the Output you generate and its subsequent uses. No use of the output can contravene any provision as stated in the License."

따라서 카드 아트 220장은 프로젝트 생성물로 관리하며, 스토어 배포에 이 라이선스 사본을
첨부할 의무는 없다. 다만 Attachment A의 금지 용도에 어긋나는 생성물은 만들 수 없다.

## 시왕도 LoRA 배포 정책

SDXL 위에 학습한 시왕도 LoRA는 원문의 **Derivatives of the Model**에 해당한다. 원문은
가중치·파라미터·활성값·출력 패턴을 이전하여 만든 모델까지 파생물로 정의하며, hosted service를
포함한 제3자 공유를 **Distribution**으로 본다.

현재 LoRA 가중치는 공개 배포하지 않는다. 외장 백업과 **private Release**에만 보관하고,
Git 저장소 이력에는 넣지 않는다. 현재 저장소가 private여도 나중에 public으로 전환하면 이력의
가중치가 소급해 공개 배포가 되며, 대용량 바이너리를 이력에서 제거하기 어렵기 때문이다.

나중에 공개 배포를 결정하면 SDXL 라이선스 §4에 따라 먼저 다음 의무를 이행한다.

- Attachment A의 사용 제한을 강제력 있는 조항으로 포함한다.
- 수령자에게 라이선스 사본을 제공한다.
- 변경한 파일에 변경 사실을 명시한다.
- 저작권·귀속 표시를 유지한다.

기획서 §11.2의 목적은 LoRA를 잃어버리지 않는 것이지 공개하는 것이 아니므로, 이 보관 정책과
충돌하지 않는다.

`scripts/gen_prompts.py`의 기본값 `qwen/qwen3.5-9b`는 RTX 5080 16GB에서 실행 가능한
8B~14B급 범위를 위한 실행 기본값일 뿐, 위 원장에 기록된 채택 모델이 아니다. 실제 생성에
쓴 모델 ID·서버·라이선스 원문은 프롬프트 결과를 커밋하기 전에 사람이 확인해 이 표에
기록한다.
