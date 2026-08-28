# 『시왕전』 AI 에셋 파이프라인 실행 가이드

- 문서 버전: v1.0 (2026-08-26)
- 대상: 계획서 §9의 파이프라인을 실제로 구축하는 사람 (= 본인)
- 상위 문서: `기획서.md`
- 소요: 총 4~5일 (환경 구축 1일 + 데이터 2일 + 학습·검증 1일 + 생성·선별 1일)

> **버전 주의**: 이 문서의 도구·모델·라이선스 관련 서술은 작성 시점 기준이다.
> 이 생태계는 빠르게 바뀌므로, 각 단계 착수 직전에 공식 문서와 라이선스 원문을 확인한다.
> 특히 §1.3의 라이선스 확인은 건너뛰지 않는다.

---

## 0. 전체 흐름

```
[1] 환경 구축          ComfyUI + kohya_ss + OpenAI 호환 LLM 서버 약 4시간
      ↓
[2] 데이터 수집        공공누리 제1유형 원본 40~60장          1일
      ↓
[3] 전처리·크롭        원본 → 학습용 80~120장                1일  ← 품질이 여기서 결정된다
      ↓
[4] 캡셔닝             트리거 워드 + 내용 태그                2시간
      ↓
[5] LoRA 학습          kohya_ss                              2~3시간
      ↓
[6] 검증               X/Y plot으로 epoch 선택                1시간  ← 실패면 [3]으로 복귀
      ↓
[7] 프롬프트 생성      카드 JSON → 로컬 LLM → 220개           2시간
      ↓
[8] 배치 생성          ComfyUI API 스크립트, 1,760장          2~3시간
      ↓
[9] 선별               컨택트 시트로 220장 확정               4~6시간  ← 진짜 병목
      ↓
[10] 후처리·출고       다운스케일 + WebP 변환                 1시간
```

**되돌아갈 수 있는 지점은 [6]뿐이다.** [6]에서 화풍이 안 잡혔는데 그냥 [7]로 넘어가면
1,760장을 뽑고 나서야 전부 버려야 한다는 걸 알게 된다. 검증에 1시간을 반드시 쓴다.

---

## 1. 환경 구축

### 1.1 하드웨어 확인

| 항목 | 최소 | 권장 |
|---|---|---|
| GPU VRAM | 12GB | **24GB (RTX 3090 중고)** |
| 시스템 RAM | 32GB | 64GB |
| 저장 공간 | 200GB SSD | 500GB SSD |

원본 + 생성물 1,760장 + 체크포인트 여러 개를 합치면 금방 100GB를 넘는다.
생성 원본은 별도 드라이브에 두고 저장소에는 넣지 않는다.

### 1.2 설치

```bash
# 1) ComfyUI — 생성 파이프라인
git clone https://github.com/comfyanonymous/ComfyUI
cd ComfyUI
python -m venv venv && source venv/Scripts/activate   # Windows Git Bash
pip install -r requirements.txt
# PyTorch는 본인 CUDA 버전에 맞춰 공식 안내대로 설치할 것

# 2) ComfyUI-Manager — 커스텀 노드 관리 (거의 필수)
cd custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager

# 3) kohya_ss — LoRA 학습
cd ../..
git clone https://github.com/bmaltais/kohya_ss
# 자체 설치 스크립트 사용

# 4) 로컬 LLM — OpenAI 호환 chat completions 서버 (프롬프트 대량 생성용)
# 이 PC에는 LM Studio가 이미 설치되어 있고 Ollama는 설치되어 있지 않다.
# LM Studio에서 모델을 올린 뒤 로컬 서버를 시작한다.
lms server start
```

`scripts/gen_prompts.py`는 `http://localhost:1234/v1`의 OpenAI 호환 API를 기본으로 쓴다.
이 PC에 내려받은 8B~14B급 후보는 `qwen/qwen3.5-9b`와 `google/gemma-4-e4b`이며, 기본 모델
ID는 전자다. 이는 실행 기본값일 뿐 채택이나 라이선스 판단이 아니다. 모델의 라이선스 원문은
§1.3 및 `art-pipeline/MODEL.md` 절차대로 사람이 확인한다.

Ollama도 대안으로 유지한다. 설치·모델 준비 후 서버를 시작하고
`--base-url http://localhost:11434/v1 --model <서버가_보고한_모델_ID>`를 지정한다. llama.cpp나
vLLM처럼 OpenAI 호환 chat completions를 제공하는 서버도 같은 인자로 쓸 수 있다.

ComfyUI-Manager로 추가할 노드: 배경 제거(RMBG 계열), 얼굴 보정(FaceDetailer 계열).
**노드 이름과 저장소는 시점에 따라 바뀌므로 Manager 검색으로 현재 이름을 확인해 설치한다.**

### 1.3 베이스 모델 선택 — 라이선스부터 확인

이 단계를 건너뛰면 출시 직전에 전부 다시 만들어야 할 수 있다.

**채택 기준**

1. 라이선스가 **Apache 2.0** 또는 **CreativeML Open RAIL++-M** 계열일 것
2. 상업적 이용에 별도 계약이 필요 없을 것
3. 파생 모델(파인튜닝)의 라이선스 승계 조건을 확인할 것

**채택 금지**

- **비상업(Non-Commercial) 라이선스 모델** — 유명하고 성능이 좋아도 게임 출시에 쓸 수 없다.
  일부 최신 고성능 모델이 여기 해당하므로 이름값만 보고 고르지 않는다.
- 라이선스가 명시되지 않았거나 출처가 불분명한 커뮤니티 병합 모델

**베이스는 SDXL 계열 일러스트 파인튜닝을 쓴다.** 이유는 세 가지다 —
LoRA 생태계와 학습 도구가 가장 성숙했고, 24GB에서 학습·추론이 모두 쾌적하며,
라이선스가 명확한 선택지가 많다.

**기록 의무**: 아래를 `art-pipeline/MODEL.md`에 남긴다. 나중에 문제 제기가 들어오면 이 파일이 방어선이다.

```markdown
# 채택 모델
- 모델명 / 버전 / 해시:
- 배포처 URL:
- 라이선스명 / 원문 URL / 확인 날짜:
- 상업적 이용 가능 여부 (원문 인용):
- 파생물 라이선스 승계 조건:
```

---

## 2. 학습 데이터 수집

### 2.1 어디서

| 출처 | URL | 비고 |
|---|---|---|
| 국립중앙박물관 e뮤지엄 | emuseum.go.kr | 소장품 고해상 이미지, 공공누리 유형 표기 |
| 국가유산청 국가유산포털 | heritage.go.kr | 불화·문화재 사진 |
| 공공누리 포털 | kogl.or.kr | 유형별 이용 조건 원문 |

**검색어**: 시왕도, 지장시왕도, 감로왕도(감로탱), 지옥도, 명부전, 시왕탱, 지옥변상도

### 2.2 공공누리 유형 — 제1유형만 쓴다

| 유형 | 조건 | 판정 |
|---|---|---|
| **제1유형** | 출처표시 / 상업적 이용 가능 / **변형 가능** | ✅ **사용** |
| 제2유형 | 출처표시 + 상업적 이용 **금지** | ❌ |
| 제3유형 | 출처표시 + **변형 금지** | ❌ 학습 부적합 |
| 제4유형 | 상업적 이용 금지 + 변형 금지 | ❌ |

**유형은 이미지마다 다르다.** 같은 기관 자료라도 개별 확인이 필요하다.
제3유형이 특히 위험하다 — 상업 이용은 되지만 **변형 금지**라 LoRA 학습에 쓸 수 없다.

> 조선시대 회화 자체는 저작권이 만료된 퍼블릭 도메인이지만,
> 그것을 **촬영한 사진**에는 별도의 권리가 붙을 수 있다.
> 그래서 "옛 그림이니까 괜찮다"가 아니라 **공공누리 유형 표기**를 근거로 삼는다.

### 2.3 수집 기준

- **긴 변 1,024px 이상.** 낮으면 제외한다.
- **40~60장.** 스타일 LoRA는 양보다 **일관성**이 중요하다.
- **1차는 좁게 간다.** 시왕도 계열만으로 시작하고, 감로탱·민화는 섞지 않는다.
  화풍이 섞이면 LoRA가 평균값을 학습해서 아무 특징도 없는 결과가 나온다.
  좁게 성공한 뒤에 확장하는 게 순서다.

### 2.4 출처 기록 — 반드시 지금 한다

수집과 **동시에** `art-pipeline/dataset/SOURCES.md`를 채운다.
나중에 하려면 어떤 파일이 어디서 왔는지 절대 복원하지 못한다.

```markdown
| 파일명 | 작품명 | 소장처 | 공공누리 유형 | 원본 URL | 확인일 |
|---|---|---|---|---|---|
| 001_siwangdo_01.jpg | 시왕도 제1폭 | 국립중앙박물관 | 제1유형 | https://... | 2026-08-26 |
```

공공누리 제1유형은 **출처표시가 의무**다. 게임 내 크레딧 화면에 표기해야 하며,
이 표는 그 크레딧을 만드는 원본이 된다.

---

## 3. 전처리 — 이 단계가 결과를 결정한다

### 3.1 왜 원본을 그대로 쓰면 안 되는가

불화는 **세로로 매우 긴 족자**이고 인물이 화면 대비 작다.
원본을 통째로 학습시키면 LoRA는 "인물 화풍"이 아니라 **"세로로 긴 족자 형태"**를 학습한다.
그러면 카드 아트를 뽑을 때마다 족자가 나온다.

**해법: 부분 크롭.**

### 3.2 크롭 전략

원본 1장에서 2~4장의 학습 이미지를 뽑는다. 40장 원본 → **80~120장 학습 데이터**.

| 크롭 대상 | 목적 | 권장 크기 |
|---|---|---|
| 인물 상반신 | 적·시왕 생성의 핵심 | 1024×1024 |
| 얼굴 클로즈업 | 표정·이목구비 화풍 | 1024×1024 |
| 의복 문양·지물 | 카드 아이템·유물 아트 | 1024×1024 |
| 배경 구름·불꽃·암산 | 카드 배경, 이펙트 | 1024×768 등 |

**크롭 규칙**

- 인물이 프레임의 60~80%를 차지하게 한다
- 잘린 손발이 어중간하게 걸치지 않게 한다
- 텍스트(화기, 방제)가 들어간 부분은 **제외**한다 — 학습되면 결과물에 글자 흉내가 섞인다
- 심하게 훼손·변색된 부분은 제외한다

```bash
# 크롭 후 일괄 리사이즈 (긴 변 1024, 비율 유지)
for f in dataset/raw/*.jpg; do
  magick "$f" -resize 1024x1024\> "dataset/train/$(basename "$f" .jpg).png"
done
```

### 3.3 캡셔닝

**스타일 LoRA의 캡션 원칙: 스타일을 캡션에서 빼고, 내용만 적는다.**

캡션에 없는 공통 요소가 트리거 워드로 흡수된다. 그러니
"조선시대 불화풍", "전통 채색" 같은 서술을 캡션에 쓰면 **오히려 학습이 안 된다.**

**트리거 워드**: `swjdostyle`
기존 토큰과 겹치지 않는 조어여야 한다. 짧고 고유하게.

```
swjdostyle, seated king figure, elaborate red robe, ornate crown,
holding a tablet, dark background, frontal view
```

- 맨 앞에 항상 트리거 워드
- 그 뒤에 **내용만** — 인물, 자세, 색, 구도
- 스타일·화풍·시대 서술은 쓰지 않는다

자동 태거(WD14 계열)로 초안을 만들고 **반드시 수동으로 다듬는다.**
80~120장이면 2시간이면 끝나고, 이 2시간이 결과 품질을 크게 바꾼다.

---

## 4. LoRA 학습

### 4.1 kohya_ss 설정값

SDXL 기준. 24GB VRAM 전제.

```toml
# 데이터
resolution              = "1024,1024"
enable_bucket           = true
bucket_reso_steps       = 64
min_bucket_reso         = 640
max_bucket_reso         = 1536

# 네트워크
network_module          = "networks.lora"
network_dim             = 32          # 스타일이면 16~64
network_alpha           = 16          # dim의 절반

# 학습률
learning_rate           = 1e-4
unet_lr                 = 1e-4
text_encoder_lr         = 5e-5        # 또는 TE 학습 비활성화
lr_scheduler            = "cosine_with_restarts"
lr_warmup_steps         = 100

# 옵티마이저
optimizer_type          = "AdamW8bit"
mixed_precision         = "bf16"
gradient_checkpointing  = true

# 반복
train_batch_size        = 2
num_repeats             = 10
max_train_epochs        = 10
save_every_n_epochs     = 1           # ← 중요. epoch별로 전부 저장한다

# 품질
noise_offset            = 0.05        # 어두운 화면에 유리 (저승 테마와 맞음)
min_snr_gamma           = 5
```

**총 스텝 수 계산**
```
100장 × 10 repeats × 10 epochs ÷ batch 2 = 5,000 step
```
스타일 LoRA는 **2,000~4,000 step** 구간이 보통 적정이다.
그래서 epoch별로 전부 저장해 놓고 §5에서 고른다. 마지막 epoch이 최선인 경우는 드물다.

**소요 시간**: RTX 3090, SDXL, batch 2, 1024px 기준 **약 2~3시간**.

### 4.2 설정 파일도 커밋한다

학습에 쓴 `.toml`을 `art-pipeline/lora/` 에 그대로 커밋한다.
6개월 뒤 카드를 추가할 때 같은 조건으로 재학습해야 할 수 있다.

---

## 5. 검증 — 여기서 실패를 잡는다

### 5.1 X/Y plot

epoch별 저장본(예: 4·6·8·10)과 LoRA strength(0.6·0.8·1.0)를 격자로 비교한다.
**동일 프롬프트, 동일 시드**로 뽑아야 비교가 성립한다.

검증용 프롬프트 3종을 고정해 두고 매번 같은 걸 쓴다.

```
1) swjdostyle, seated king figure, red robe, ornate crown, dark background
2) swjdostyle, a curved sword wreathed in flame, object study, plain background
3) swjdostyle, a fearsome demon guard, full body, holding a spiked club
```

### 5.2 합격 판정

| 확인 항목 | 합격 | 불합격 신호 |
|---|---|---|
| 화풍 | 원본 화풍의 붓질·채색이 나온다 | 일반 애니풍/서양풍 그대로 |
| 다양성 | 같은 프롬프트 다른 시드 → 다른 구도 | 시드가 달라도 거의 같은 그림 = **과적합** |
| 프롬프트 반응 | 프롬프트대로 대상이 바뀐다 | 뭘 넣어도 인물 초상만 나옴 = 과적합 |
| 텍스트 오염 | 글자 흉내가 없다 | 화면에 한자 비슷한 얼룩 = 캡션/크롭 문제 |
| 색감 | 원본의 채도·팔레트 | 전부 회색조 / 채도 폭주 |

### 5.3 실패 시 대응

| 증상 | 원인 | 조치 |
|---|---|---|
| 화풍이 안 잡힘 | 캡션에 스타일 서술이 남아 있음 | 캡션에서 화풍 관련 단어 전부 제거 후 재학습 |
| 과적합 (원본 복제) | step 과다 / dim 과다 | 이른 epoch 채택, `network_dim` 16으로 |
| 족자 형태만 나옴 | 크롭 부족 | §3.2로 복귀 — **가장 흔한 실패** |
| 글자 얼룩 | 화기·방제가 포함된 크롭 | 해당 이미지 제외 후 재학습 |
| 결과가 다 비슷 | 데이터 다양성 부족 | 크롭 대상을 인물 외로 확대 |

**§3.2로 복귀하는 경우가 가장 많다.** 크롭을 다시 하는 반나절이
잘못된 LoRA로 1,760장을 뽑는 것보다 훨씬 싸다.

---

## 6. 프롬프트 설계와 생성

### 6.1 템플릿 고정이 일관성의 핵심

220장의 일관성은 LoRA가 아니라 **템플릿**이 만든다.
LLM에게 프롬프트 전체를 맡기면 220장이 제각각이 된다.

```
{트리거}, {가변: 대상 묘사}, {고정: 구도}, {고정: 팔레트}, {고정: 품질}
```

| 구간 | 내용 | 담당 |
|---|---|---|
| 트리거 | `swjdostyle` | 고정 |
| 대상 묘사 | 카드마다 다름 | **LLM** |
| 구도 | `centered composition, single subject, plain dark background` | 고정 |
| 팔레트 | `deep vermilion, jade green, ink black, muted gold` | 고정 |
| 품질 | `highly detailed, traditional pigment texture` | 고정 |

**네거티브 프롬프트 (전 카드 공통, 고정)**
```
text, watermark, signature, letters, characters, modern clothing,
photograph, 3d render, western fantasy armor, blurry, extra limbs,
scroll mounting, frame border, multiple panels
```
`scroll mounting`, `frame border`, `multiple panels`는 족자 형태 방지용이다.
LoRA가 아무리 잘 나와도 이 세 개는 넣어 두는 게 안전하다.

### 6.2 로컬 LLM으로 220개 생성

`scripts/gen_prompts.py`는 특정 런처 CLI를 부르지 않는다. `art-pipeline/prompts/system_prompt.md`를
시스템 메시지로 읽어 OpenAI 호환 `GET /models`와 `POST /chat/completions`를 사용한다. 따라서
LM Studio·Ollama·llama.cpp·vLLM 서버를 URL 하나로 바꿔 쓸 수 있다.

```powershell
# 이 PC의 기본 실행: LM Studio 서버를 켜고 기본 URL·모델 ID로 생성
lms server start
python scripts/gen_prompts.py generate --temperature 0 --seed 0

# Ollama 또는 다른 OpenAI 호환 서버
python scripts/gen_prompts.py generate --base-url http://localhost:11434/v1 --model <서버가_보고한_모델_ID> --temperature 0 --seed 0
```

서버가 꺼져 있으면 스크립트는 0이 아닌 코드로 종료하며, LM Studio 기준으로 `lms server start`를
안내한다. 요청한 모델이 없으면 서버의 사용 가능한 모델 ID 목록을 함께 출력한다. 비어 있거나
깨진 응답은 해당 카드 ID와 함께 실패 처리하므로 빈 프롬프트를 저장하지 않는다.

생성 결과 `cards_prompts.json`에는 서버 `base_url`, 실제 `model`, `temperature`, `seed`가 함께
기록된다. 이 값과 카드·템플릿·시스템 프롬프트를 고정해야 6개월 뒤 같은 프롬프트를 재생성할
근거가 남는다.

**생성 후 반드시 눈으로 훑는다.** 220줄이면 15분이다.
LLM이 가끔 설명 문장을 뱉거나 금지 단어를 넣는다. 이걸 걸러야 §8에서 재작업이 없다.

---

## 7. 배치 생성

### 7.1 ComfyUI 워크플로

```
Load Checkpoint (§1.3 채택 모델)
  → Load LoRA (strength: §5에서 확정한 값)
  → CLIP Text Encode [positive] / [negative]
  → Empty Latent Image (1152×896)
  → KSampler (steps 28, cfg 6.0, sampler: dpmpp_2m, scheduler: karras)
  → VAE Decode
  → Save Image
```

**해상도 규격**

| 용도 | 생성 | 출고 | 비율 |
|---|---|---|---|
| 카드 아트 | 1152×896 | 450×350 | 9:7 |
| 일반·정예 적 | 1024×1024 | 512×512 | 1:1 |
| 시왕(보스) | 896×1152 | 700×900 | 7:9 |

> **카드 프레임을 생성 해상도에 맞춘다.** 4:3 같은 이상적 비율을 정해 놓고
> SDXL이 싫어하는 해상도로 뽑느니, 9:7로 뽑고 UI 프레임을 거기 맞추는 게 낫다.
> 어차피 프레임은 Flutter 코드라 바꾸는 데 5분이다.

워크플로를 완성하면 **Save (API Format)**으로 `workflows/card_art_api.json`에 저장한다.
일반 저장 형식이 아니라 API 형식이어야 스크립트에서 쓸 수 있다.

### 7.2 배치 스크립트

```python
# scripts/batch_generate.py
import json, urllib.request, random, copy

COMFY = "http://127.0.0.1:8188"
WF = json.load(open("workflows/card_art_api.json", encoding="utf-8"))

# 노드 ID는 워크플로마다 다르다. API JSON을 한 번 열어 확인하고 여기 박아둔다.
NODE_POS     = "6"   # CLIPTextEncode (positive)
NODE_SAMPLER = "3"   # KSampler
NODE_SAVE    = "9"   # SaveImage

def queue(prompt_text, prefix, seed):
    wf = copy.deepcopy(WF)
    wf[NODE_POS]["inputs"]["text"] = prompt_text
    wf[NODE_SAMPLER]["inputs"]["seed"] = seed
    wf[NODE_SAVE]["inputs"]["filename_prefix"] = prefix
    data = json.dumps({"prompt": wf}).encode("utf-8")
    req = urllib.request.Request(f"{COMFY}/prompt", data=data,
                                 headers={"Content-Type": "application/json"})
    urllib.request.urlopen(req).read()

cards = json.load(open("prompts/cards_prompts.json", encoding="utf-8"))
CANDIDATES = 8

for c in cards:
    for i in range(CANDIDATES):
        queue(c["prompt"], f"{c['id']}/{c['id']}_v{i:02d}",
              random.randint(0, 2**32 - 1))

print(f"큐 등록 완료: {len(cards) * CANDIDATES}장")
```

1,760장을 한 번에 큐에 넣어도 된다. ComfyUI가 순차 처리한다.
중단하려면 ComfyUI 화면에서 큐를 비우면 된다.

**소요 시간**: 3090 기준 장당 4~6초 → **약 2~3시간**. 자고 일어나면 끝나 있다.

---

## 8. 선별 — 진짜 병목

### 8.1 컨택트 시트

1,760장을 하나씩 보면 하루가 간다. 카드당 8장을 한 장에 붙인다.

```bash
mkdir -p sheets
for d in raw/card_*/; do
  id=$(basename "$d")
  magick montage "$d"*.png -tile 4x2 -geometry 400x+6+6 \
    -background '#1a1a1a' -label '%f' "sheets/${id}.jpg"
done
```

시트를 순서대로 넘기면서 **채택 번호만 텍스트로 기록**한다.

```
card_blade_of_grudge  v03
card_river_crossing   v07
card_mirror_of_karma  v01
...
```

카드당 10~15초. **220장에 약 1시간**이면 1차 선별이 끝난다.
"괜찮은 게 하나도 없는" 카드만 따로 표시해 두고 나중에 재생성한다.
경험상 10~15%가 재생성 대상이다.

### 8.2 선별 기준

- **화풍 일관성이 최우선.** 혼자 잘 그린 그림보다 220장과 어울리는 그림
- 카드 프레임 안에서 잘릴 것을 고려 — 중앙에 대상이 있는지
- 글자 얼룩, 손가락 붕괴, 좌우 비대칭은 탈락
- 어두운 배경 유지 (UI 위에서 텍스트 가독성)

### 8.3 확정 복사

```bash
# picks.txt: "card_id v03" 형식
while read id v; do
  cp "raw/$id/${id}_${v}"*.png "final/$id.png"
done < picks.txt
```

---

## 9. 후처리와 출고

### 9.1 업스케일은 하지 않는다

계획서 초안에는 업스케일 단계가 있었지만 **불필요하다.**

모바일에서 카드 아트가 실제 표시되는 크기는 폭 150dp 내외,
3배 밀도 기준 450px다. 생성 해상도 1152px에서 **다운스케일**하면 되고,
오히려 다운스케일이 **AI 특유의 잔결함을 뭉개서 품질을 올린다.**

크게 뽑아 작게 출고한다. 이게 슈퍼샘플링과 같은 효과를 낸다.

### 9.2 변환

```bash
# 카드 아트 → 450×350 WebP
for f in final/card_*.png; do
  magick "$f" -resize 450x350^ -gravity center -extent 450x350 \
    -quality 82 "assets/cards/$(basename "$f" .png).webp"
done

# 적 스프라이트 → 512×512 WebP (알파 유지)
for f in final/enemy_*.png; do
  magick "$f" -resize 512x512 -quality 85 \
    "assets/enemies/$(basename "$f" .png).webp"
done
```

적 스프라이트는 투명 배경이 필요하므로 변환 **전에** ComfyUI의 배경 제거 노드를 통과시킨다.
카드 아트는 프레임 안에 들어가므로 배경 제거가 필요 없다.

### 9.3 용량 예산

| 항목 | 수량 | 장당 | 합계 |
|---|---|---|---|
| 카드 아트 | 220 | ~35KB | 7.7MB |
| 적 스프라이트 | 47 | ~60KB | 2.8MB |
| 시왕 | 6 | ~180KB | 1.1MB |
| **합계** | | | **약 12MB** |

APK 100MB 한도(계획서 §7.5) 대비 충분히 여유가 있다.
용량 때문에 화질을 깎을 이유가 없다.

---

## 10. 적·시왕 파이프라인의 차이

### 10.1 적 47종

카드와 거의 동일하되 두 가지가 다르다.

- **정면 1컷씩만 필요하다.** 여러 각도·포즈가 없으므로 캐릭터 일관성 문제를 겪지 않는다.
  이게 이 게임이 AI 파이프라인과 궁합이 좋은 결정적 이유다.
- **투명 배경이 필요하다.** 배경 제거 노드를 워크플로에 포함시킨다.

같은 적의 강화 변종(2막·3막 재등장)은 **같은 시드 + 프롬프트 일부 수정**으로 만든다.
색만 바꾼 팔레트 스왑도 유효하다 — 로그라이크의 오랜 관습이고, 유저도 이해한다.

### 10.2 시왕 6종 — 유일하게 사람 손이 들어가는 곳

시왕은 **스토어 아이콘과 스크린샷에 쓰이는 얼굴**이다. 다운로드 전환율에 직접 기여한다.
AI로 30~50장 후보를 뽑아 2~3장으로 좁힌 뒤, **리터칭 외주**를 넣는다.

**발주 시 제공할 것**
- 선별한 AI 생성 원본 (고해상)
- 캐릭터 설정 (계획서 §4)
- 팔레트와 화풍 레퍼런스 (학습에 쓴 원본 시왕도 몇 장)
- 요구 사항: 얼굴·손 정리, 실루엣 정돈, 문양 디테일 보강, 좌우 대칭 교정

**계약에 반드시 명시할 것**
- 원본이 **AI 생성물임을 사전 고지** — 이걸 숨기면 나중에 분쟁이 된다.
  거부하는 작업자가 있으므로 처음부터 밝히고 수락한 사람과 진행한다
- 완성물의 저작권·이용권 귀속
- 러프 검수 단계 (1차 러프 확인 후 진행)
- 수정 횟수

건당 8만원 × 6종 = 48만원. 1종 먼저 발주해 결과를 보고 나머지를 진행한다.

---

## 11. 저장소 구조와 재현성

### 11.1 구조

```
(저장소 루트)
├─ art-pipeline/
│   ├─ MODEL.md                채택 모델·라이선스 기록 (§1.3)
│   ├─ dataset/
│   │   ├─ SOURCES.md          출처·공공누리 유형 기록 (§2.4)
│   │   ├─ raw/                수집 원본           [gitignore]
│   │   └─ train/              크롭·캡션 완료본     [커밋]
│   ├─ lora/
│   │   ├─ swjdostyle.safetensors [Git LFS 또는 Release 첨부 + 외장 백업]
│   │   └─ train_config.toml    학습 설정 (§4.2)     [커밋]
│   ├─ workflows/
│   │   └─ card_art_api.json    카드용 API 워크플로  [커밋]
│   ├─ prompts/
│   │   ├─ template.txt         고정부 정의 (§6.1)   [커밋]
│   │   ├─ negative.txt         공통 네거티브        [커밋]
│   │   ├─ system_prompt.md     LLM 대상 묘사 계약   [커밋]
│   │   ├─ validation_rules.json 기계 검증 규칙      [커밋]
│   │   └─ cards_prompts.json  생성된 220개          [커밋]
│   ├─ raw/                     생성 원본 1,760장    [gitignore, 외장 백업]
│   ├─ final/                   선별본·출시 카드 아트 [커밋]
│   └─ picks.txt                선별 기록             [커밋]
└─ scripts/
    └─ gen_prompts.py           프롬프트 생성·검증   [커밋]
```

`scripts/`는 저장소 루트에 둔다. §6.2와 §7.2의 `scripts/...` 경로도 이 기준이다.
`batch_generate.py`와 `postprocess.sh`는 아직 저장소에 만들지 않은 실행 예시다. 구현할 때도
`art-pipeline/scripts/`가 아니라 루트 `scripts/`에 둔다.

`workflows/enemy_api.json`과 `workflows/boss_api.json`은 아직 만들지 않았다. 카드 아트와
출력 해상도·구도가 다르므로 카드 워크플로를 복사하지 않고, 적의 투명 배경·전신 구도와
보스의 더 큰 실루엣·여백 구도를 정한 뒤 각각 **API Format**으로 내보낸다.

### 11.2 반드시 커밋할 것

**워크플로 JSON, 프롬프트 계약, 학습 설정, 크롭·캡션 완료본, final/ 출시 아트, picks.txt.**

이유는 하나다. 출시 6개월 뒤 카드 30장을 추가할 때 같은 화풍이 안 나오면
**그때까지 만든 220장이 전부 어색해진다.** 그 시점에 LoRA를 잃어버렸으면
전량 재생성 외에 방법이 없다.

`.safetensors`는 수십~수백 MB라 Git LFS를 쓰거나 Release 첨부와 외장 백업을 병행한다.
어느 방식을 택했는지는 가중치 파일명·확정 epoch·강도와 함께 작업 기록에 남긴다.

### 11.3 크레딧 표기

게임 내 크레딧 화면에 공공누리 출처표시를 넣는다. `SOURCES.md`에서 자동 생성한다.

```
이 게임의 아트는 국립중앙박물관 등이 공공누리 제1유형으로 공개한
조선시대 시왕도 이미지를 학습한 전용 모델로 제작되었습니다.

출처: 국립중앙박물관 「시왕도」 외 (공공누리 제1유형)
```

**이건 의무이자 마케팅이다.** 계획서 §9.2에서 정한 대로, 학습 출처를 밝히는 것이
AI 아트 반감에 대한 최선의 방어다. 크레딧에 묻어 두지 말고 스토어 설명에도 쓴다.

---

## 12. 체크리스트

**착수 전**
- [ ] GPU VRAM 12GB 이상 확보
- [ ] 베이스 모델 라이선스 원문 확인, `MODEL.md` 작성
- [ ] 저장 공간 200GB 확보

**데이터**
- [ ] 공공누리 **제1유형만** 수집했는가
- [ ] 각 이미지의 유형을 개별 확인했는가
- [ ] `SOURCES.md`를 수집과 동시에 작성했는가
- [ ] 화풍을 한 계열로 좁혔는가

**전처리**
- [ ] 원본을 통째로 쓰지 않고 크롭했는가
- [ ] 텍스트(화기·방제) 포함 영역을 제외했는가
- [ ] 캡션에서 화풍·시대 서술을 제거했는가
- [ ] 트리거 워드가 모든 캡션 맨 앞에 있는가

**학습·검증**
- [ ] epoch별로 전부 저장했는가
- [ ] X/Y plot으로 비교했는가
- [ ] 과적합 징후(시드 무관 동일 구도)가 없는가
- [ ] 족자 형태가 나오지 않는가

**생성**
- [ ] 프롬프트 템플릿 고정부가 확정됐는가
- [ ] 220개 프롬프트를 눈으로 훑었는가
- [ ] 네거티브에 `scroll mounting, frame border` 포함했는가
- [ ] 워크플로를 **API Format**으로 저장했는가

**출고**
- [ ] 업스케일 없이 다운스케일했는가
- [ ] WebP 변환 후 용량이 예산 내인가
- [ ] 적 스프라이트 배경이 투명한가

**보관**
- [ ] LoRA·워크플로·템플릿·학습 설정을 커밋했는가
- [ ] 크레딧 표기를 작성했는가

---

## 13. 일정

| 일차 | 작업 | 산출물 |
|---|---|---|
| 1일차 | 환경 구축, 모델 선택·라이선스 확인 | 동작하는 ComfyUI + `MODEL.md` |
| 2일차 | 데이터 수집 | 원본 40~60장 + `SOURCES.md` |
| 3일차 | 크롭·캡셔닝 | 학습 데이터 80~120장 |
| 4일차 오전 | LoRA 학습 | epoch별 체크포인트 |
| 4일차 오후 | 검증, 필요 시 재학습 | **확정 LoRA** |
| 5일차 오전 | 프롬프트 생성, 배치 시작 | 1,760장 |
| 5일차 오후 | 선별, 후처리, 출고 | `assets/` 220장 |

**계획서 §8의 병행 트랙 2주 안에 충분히 들어간다.** 남는 시간은 재학습 여유로 둔다.
첫 LoRA가 한 번에 합격하는 경우는 드물고, 보통 §3.2 크롭을 한 번 다시 한다.

---

## 부록. 자주 겪는 문제

| 증상 | 원인 | 조치 |
|---|---|---|
| 결과가 전부 세로 족자 | 크롭 부족 | §3.2 재작업 — 가장 흔하다 |
| 그림에 한자 비슷한 얼룩 | 화기 포함 크롭 | 해당 이미지 제외 후 재학습 |
| 카드마다 화풍이 제각각 | 템플릿 가변부가 너무 큼 | 고정부 확대, LoRA strength 고정 |
| 얼굴이 뭉개짐 | 생성 해상도 대비 인물이 작음 | FaceDetailer 계열 노드 추가 |
| 색이 튐 | 팔레트 태그 누락 | 고정부에 팔레트 명시 |
| 시드가 달라도 같은 그림 | 과적합 | 이른 epoch 채택, `network_dim` 낮추기 |
| VRAM 부족 | batch/해상도 과다 | `train_batch_size` 1, gradient checkpointing 확인 |
| ComfyUI API 400 오류 | 노드 ID 불일치 | API JSON을 열어 실제 ID 재확인 |
