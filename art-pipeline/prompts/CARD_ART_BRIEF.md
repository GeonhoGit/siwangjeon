# 카드 아트 생성 브리프

『시왕전(十王殿)』 카드 23장의 그림을 만들기 위한 지시서다. 이미지 생성 도구(ChatGPT 등)에
이 문서를 그대로 주고, 아래 「카드 목록」의 각 항목을 한 장씩 뽑는다.

---

## 0. 절대 규칙 — 어기면 그 그림은 못 쓴다

### 그림 안에 글자를 넣지 마라

카드 이름·비용·효과 설명·낙관·도장·서명·워터마크 **어떤 문자도 그리지 마라.**
한자·한글·영문 모두 안 된다. 배경 소품의 장부, 두루마리, 현판에도 글자를 쓰지 마라.

이유는 두 가지다.

1. 카드 이름과 설명은 **앱이 직접 렌더링한다.** 그림에 글자가 있으면 이중으로 표시된다
2. 영어판을 낼 때 그림을 다시 만들지 않아도 된다. 글자가 구워지면 **220장을 전부 재생성**해야 한다

경험상 이 지시를 넣어도 도장이나 문자 흉내가 섞여 나온다. **받은 그림에 글자가 하나라도
보이면 채택하지 말고 다시 뽑아라.**

### 카드 틀을 그리지 마라

테두리, 이름표, 비용 배지, 설명란, 액자, 족자 표구 — 전부 앱이 그린다.
**그림 영역만** 채운다. 사각형 가장자리까지 그림이 이어져야 한다.

---

## 1. 규격

| 항목 | 값 |
|---|---|
| 비율 | **3:4 세로** (앱의 아트 슬롯이 0.75) |
| 권장 크기 | 1024×1365 이상 |
| 파일 형식 | WebP 우선, PNG·JPG도 가능 |
| 파일명 | **카드 id를 그대로** — 목록의 `파일명` 열 참고 |

파일명을 지키면 앱이 자동으로 찾아 붙인다. 다른 작업은 필요 없다.

---

## 2. 화풍 — 조선 시왕도(十王圖)

배경 설정은 **조선시대 저승**이다. 죽은 자가 49일 동안 열 명의 왕 앞에서 자기가 쌓은
업(業)으로 심판받는 세계다.

### 이렇게 그린다

- **조선 불화(佛畵)의 화풍.** 시왕도·감로탱 계열. 평면적이고 장식적인 채색, 또렷한 윤곽선
- **인물은 조선 복식.** 도포, 관복, 사모, 갓, 한복. 왕은 면류관과 홀
- 저승 도상: 업경대(죄를 비추는 거울), 업 장부, 삼도천, 지옥 옥졸, 연꽃, 향로, 부적, 먹과 인장
- 오래된 비단에 그린 듯한 안료 질감

### 이렇게 그리지 마라

- **서양 판타지** — 판금 갑옷, 중세 기사, 서양 검, 룬 문자
- **일본풍** — 사무라이 갑옷, 일본식 투구, 도깨비 방패, 우키요에
- **중국 무협풍** — 이것도 조선이 아니다
- 사진, 3D 렌더, 현대 의복

### 팔레트 (전 카드 공통)

```
주칠 적색 · 청록(옥색) · 먹빛 검정 · 낡은 금색
```

배경은 **어둡고 단순하게.** 인물이나 사물 하나가 가운데 오고, 뒤는 비워 둔다.
카드 하나하나가 아니라 **23장이 한 벌로 보여야 한다.**

---

## 3. 카드 목록

각 행이 그림 한 장이다.

- **묘사**는 그려야 할 대상이다. 여기 적힌 사물·인물·자세를 그린다
- **효과**는 게임에서 그 카드가 하는 일이다. 분위기를 잡는 참고용이지 그림에 글자로 쓰지 마라
- **업**은 이 게임의 핵심 자원이다. 업이 오르는 카드는 붉고 격렬하게, 업을 씻는 카드는
  차분하고 정갈하게 — 한눈에 구분되면 좋다

| # | 카드 | 유형 | 비용 | 업 | 효과 | 묘사 | 파일명 |
|---|---|---|---|---|---|---|---|
| 1 | **타격** | 공격 | 1 | - | 피해 6 | heavy iron mallet, cracked stone slab, bloodied wooden staff | `card_strike.webp` |
| 2 | **원한의 칼날** | 공격 | 1 | +3 | 피해 6 · grudge 1 | crimson blade, jagged edge, vengeful spirit | `card_blade_of_grudge.webp` |
| 3 | **업보의 베기** | 공격 | 1 | +2 | 피해 10 | rotten lotus leaf, karmic ink brush, severed silk ribbon | `card_sinful_slash.webp` |
| 4 | **독사의 판결** | 공격 | 1 | +1 | 피해 4 · poison 3 | poisoned jade seal, venomous cobra fangs, withered kelp rope | `card_venom_verdict.webp` |
| 5 | **추궁의 낙인** | 공격 | 1 | +2 | 피해 5 · vulnerable 2 | branded iron seal, burning question marks, trembling accused soul | `card_inquisition_brand.webp` |
| 6 | **연속 판결** | 공격 | 1 | - | 피해 4 · 피해 4 | split jade gavel, paired iron scales, dual verdict tablets | `card_twin_verdict.webp` |
| 7 | **수습 베기** | 공격 | 1 | - | 피해 5 · weak 2 | carved iron cleaver, kneeling condemned soul, bound ankle chains | `card_suppressing_cut.webp` |
| 8 | **정결한 베기** | 공격 | 1 | - | 피해 8 | polished silver knife, white silk handkerchief, clean cutting edge | `card_clean_cut.webp` |
| 9 | **수비** | 기술 | 1 | - | 방어 5 | parchment talisman bundle, iron-bound reed cage, carved wooden barrier | `card_defend.webp` |
| 10 | **철갑 수비** | 기술 | 1 | - | 방어 10 | iron-plated chest guard, wide silk sleeves, upright stance | `card_iron_guard.webp` |
| 11 | **호흡 고르기** | 기술 | 1 | - | 방어 3 · 드로우 1 | calm breathing monk, folded prayer beads, lotus meditation cushion | `card_steady_breath.webp` |
| 12 | **회복된 기력** | 기술 | 1 | - | 방어 3 · 기력 +1 | glowing jade amulet, woven hemp cord, golden lotus seal | `card_recovered_energy.webp` |
| 13 | **수호의 각인** | 기술 | 1 | - | 방어 5 · dexterity 1(자신) | carved protective sigil, inked warding runes, reed brush seal | `card_guardian_sigil.webp` |
| 14 | **탐욕의 장벽** | 기술 | 1 | +2 | 방어 11 | bronze judgment tablet, reed torch, carved wooden gate | `card_greedy_barrier.webp` |
| 15 | **무력한 시선** | 기술 | 1 | - | 방어 3 · weak 2 | parchment warding talisman, inked cracked sigil, faded protective charm | `card_weakening_glance.webp` |
| 16 | **지옥의 기세** | 힘(지속) | 1 | +3 | 방어 2 · strength 2(자신) | blackened iron gauntlets, scorched silk robe, soot-stained wide sleeves | `card_hellfire_momentum.webp` |
| 17 | **강철의 서약** | 힘(지속) | 2 | - | 방어 2 · dexterity 2(자신) | polished silver amulet, reinforced silk sash, iron-plated shoulder guard | `card_iron_vow.webp` |
| 18 | **집착의 맹세** | 힘(지속) | 2 | +1 | 방어 2 · strength 1(자신) · dexterity 1(자신) | tattered prayer paper, frayed hemp sash, bound wrist cords | `card_clinging_oath.webp` |
| 19 | **고해** | 기술 | 1 | 정화 | 방어 2 · 체력 -5 · 업 -8 | worn hemp sash, prayer beads, linen robe | `card_confession.webp` |
| 20 | **대정화** | 기술 | 3 | 정화 | 방어 6 · 업 -18 | white lotus basin, incense burner stand, wide hemp sash | `card_great_purification.webp` |
| 21 | **금식의 서약** | 기술 | 0 | 정화 | weak fastingWeak(자신) · 업 -fastingCleanse | withered lotus leaf, frayed hemp cord, empty wooden bowl | `card_fasting_vow.webp` |
| 22 | **엷은 장막** | 기술 | 0 | 정화 | vulnerable veilVulnerable(자신) · 업 -veilCleanse | worn paper screen, gauze partition, translucent fabric barrier | `card_thin_veil.webp` |
| 23 | **파계의 수비** | 기술 | 0 | 정화 | 방어도 소모 shatteredWardBlockCost · 업 -shatteredWardCleanse | cracked porcelain warding plate, frayed protective talisman, inked barrier sigil | `card_shattered_ward.webp` |

---

## 4. 한 장씩 뽑을 때 쓰는 프롬프트 틀

목록의 **묘사**를 `{묘사}` 자리에 넣는다.

```
조선시대 불화(시왕도) 화풍의 카드 삽화.
{묘사}
가운데 배치, 대상 하나, 어둡고 단순한 배경.
주칠 적색·청록·먹빛 검정·낡은 금색.
평면적이고 장식적인 채색, 또렷한 윤곽선, 낡은 비단의 안료 질감.
3:4 세로 비율.

금지: 어떤 글자도 넣지 말 것(한자·한글·영문·도장·낙관·서명·워터마크).
카드 테두리나 틀을 그리지 말 것. 족자 표구를 그리지 말 것.
서양 판금 갑옷·중세 기사·사무라이·일본식 투구·우키요에 금지.
사진, 3D 렌더, 현대 의복 금지.
```

## 5. 받은 그림 검사

채택 전에 이 넷만 본다.

1. **글자가 있는가** — 하나라도 있으면 탈락
2. **카드 틀이나 족자 표구가 그려졌는가** — 있으면 탈락
3. **조선 복식인가** — 일본식 투구, 서양 갑옷이면 탈락
4. **다른 카드들과 같은 화풍인가** — 혼자 튀면 탈락

## 6. 앱에 넣는 법

파일명을 `<카드 id>.webp`로 맞춰 다음 폴더에 넣는다.

```
assets/card_art/
```

넣기만 하면 앱이 자동으로 찾아 카드에 붙이고, 아트가 있는 카드는 그림 자리가 커진 큰
레이아웃으로 바뀐다. 코드 수정은 필요 없다.
