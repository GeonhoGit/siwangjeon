/// M0 임시 콘텐츠 (기획서 §12-2).
///
/// `assets/data/*.json`이 아니라 Dart 상수인 이유는 `data.dart`에 적어 둔
/// 그대로다 — JSON 로더는 카드가 20장을 넘어갈 때 만든다. 지금 스키마를
/// 먼저 굳히면, 엔진 규칙이 아직 흔들리는 동안 로더가 그 흔들림을 따라다녀야 한다.
///
/// M0의 목적은 진도가 아니라 **의사결정**이다(§8.1). 그래서 이 파일의 목표는
/// 콘텐츠 물량이 아니라, §8.1의 세 질문에 답할 수 있는 최소 구성이다.
/// 특히 1번 질문("업이 매 턴 고민을 만드는가")을 던지려면 덱 안에
/// 「원한의 칼날」처럼 **업을 대가로 세지는 선택지**가 반드시 있어야 한다.
library;

import '../domain/effect/card_effect.dart';
import '../domain/model/card.dart';
import '../domain/model/enemy.dart';
import '../domain/model/status.dart';

// ── 카드 3장 (§12-1) ────────────────────────────────────────

/// 기본 공격. 업이 붙지 않는 안전한 선택지.
const strike = CardDef(
  id: 'card_strike',
  name: '타격',
  type: CardType.attack,
  cost: 1,
  effects: [DamageEffect(value: 6)],
);

/// 기본 방어.
const defend = CardDef(
  id: 'card_defend',
  name: '수비',
  type: CardType.skill,
  cost: 1,
  targeted: false,
  effects: [BlockEffect(5)],
);

/// §7.3의 예시 카드 그대로.
///
/// 업을 3 쌓는 대신 업에 비례해 세지고 원한까지 남긴다.
/// M0에서 §8.1의 1번 질문을 실제로 던지는 카드가 이것이다.
const bladeOfGrudge = CardDef(
  id: 'card_blade_of_grudge',
  name: '원한의 칼날',
  type: CardType.attack,
  rarity: CardRarity.uncommon,
  cost: 1,
  karma: 3,
  effects: [
    DamageEffect(value: 6, scaleWith: 'karma', scale: 0.1),
    ApplyStatusEffect(status: StatusId.grudge, stacks: 1),
  ],
);

/// 시작 덱 10장.
///
/// 「원한의 칼날」이 2장인 이유는, 한 전투에 한 번쯤 손에 잡혀야
/// "지금 쓸 것인가"라는 질문이 생기기 때문이다. 4장이면 그냥 주력이 되고
/// 1장이면 뽑히지 않는 턴이 대부분이라 질문 자체가 생기지 않는다.
const starterDeck = <CardDef>[
  strike,
  strike,
  strike,
  strike,
  defend,
  defend,
  defend,
  defend,
  bladeOfGrudge,
  bladeOfGrudge,
];

// ── 적 ────────────────────────────────────────────────────

/// 아귀(餓鬼) — 때리고, 막고, 크게 때린다.
///
/// 3턴 주기로 예고가 바뀌므로 §3.1의 "다음 행동은 항상 미리 표시"가
/// 실제로 판단에 쓰이는지 볼 수 있다. 3번째 턴의 9는 방어 없이 맞으면 아프다.
Enemy agwi() => const Enemy(
  id: 'enemy_agwi',
  name: '아귀',
  hp: 24,
  maxHp: 24,
  pattern: [EnemyAttack(6), EnemyDefend(5), EnemyAttack(9)],
);

/// 원귀(冤鬼) — 약화를 걸고 잘게 두 번 때린다.
///
/// 연타는 방어도를 잘게 깎으므로 "방어를 쌓을 것인가 밀어붙일 것인가"의
/// 답이 아귀와 달라진다. 적 두 종류가 같은 답을 요구하면 전투가 단조로워진다.
Enemy wongwi() => const Enemy(
  id: 'enemy_wongwi',
  name: '원귀',
  hp: 18,
  maxHp: 18,
  pattern: [EnemyInflict(StatusId.weak, 1), EnemyAttack(4, times: 2)],
);

/// M0의 기본 조우. §8.1의 2번 질문("세로 화면에서 카드 5장 + 적이
/// 답답하지 않은가")을 보려면 적이 둘 이상이어야 한다.
List<Enemy> defaultEncounter() => [agwi(), wongwi()];

/// 플레이어 시작 체력 (§3.2 — 체력 범위 0~80).
const startingHp = 80;
