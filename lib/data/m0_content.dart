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
import '../domain/run/run_content.dart';
import 'm1_events.dart';

// ── M0 카드 20장 (§12-1) ─────────────────────────────────────

/// 기본 공격. 업을 내지 않아 심판을 미루는 대신 피해도 평범한 안전 선택이다.
const strike = CardDef(
  id: 'card_strike',
  name: '타격',
  type: CardType.attack,
  cost: 1,
  effects: [DamageEffect(value: 6)],
);

/// 기본 방어. 업을 늘리지 않고 다음 적 턴을 견뎌 정화·고업 카드의 여지를 만든다.
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

/// 업 2를 내고 즉시 10 피해를 얻는다. 심판을 앞당겨 지금의 처치를 서두르는 거래다.
const sinfulSlash = CardDef(
  id: 'card_sinful_slash',
  name: '악업의 베기',
  type: CardType.attack,
  rarity: CardRarity.uncommon,
  cost: 1,
  karma: 2,
  effects: [DamageEffect(value: 10)],
);

/// 업 1을 내고 독 3을 남긴다. 당장 덜 때리는 대신 이후 턴의 피해를 미리 사는 거래다.
const venomVerdict = CardDef(
  id: 'card_venom_verdict',
  name: '독사의 판결',
  type: CardType.attack,
  cost: 1,
  karma: 1,
  effects: [
    DamageEffect(value: 4),
    ApplyStatusEffect(status: StatusId.poison, stacks: 3),
  ],
);

/// 업 2를 내고 취약 2를 건다. 이어지는 공격을 크게 만들지만 심판을 뒤로 미루지 못한다.
const inquisitionBrand = CardDef(
  id: 'card_inquisition_brand',
  name: '추궁의 낙인',
  type: CardType.attack,
  rarity: CardRarity.uncommon,
  cost: 1,
  karma: 2,
  effects: [
    DamageEffect(value: 5),
    ApplyStatusEffect(status: StatusId.vulnerable, stacks: 2),
  ],
);

/// 업 없이 두 번 나눈 피해를 준다. 방어도에는 약하지만 업을 피하며 압박을 이어 가는 선택이다.
const twinVerdict = CardDef(
  id: 'card_twin_verdict',
  name: '연속 단죄',
  type: CardType.attack,
  rarity: CardRarity.uncommon,
  cost: 1,
  effects: [DamageEffect(value: 4), DamageEffect(value: 4)],
);

/// 업 대신 약화 2로 다음 공격을 낮춘다. 지금 밀어붙이지 않고 정화할 시간을 사는 공격이다.
const suppressingCut = CardDef(
  id: 'card_suppressing_cut',
  name: '제압 베기',
  type: CardType.attack,
  cost: 1,
  effects: [
    DamageEffect(value: 5),
    ApplyStatusEffect(status: StatusId.weak, stacks: 2),
  ],
);

/// 업을 내지 않는 8 피해다. 높은 보상은 없지만 심판 수치를 유지하며 마무리하는 기준선이다.
const cleanCut = CardDef(
  id: 'card_clean_cut',
  name: '정결한 베기',
  type: CardType.attack,
  cost: 1,
  effects: [DamageEffect(value: 8)],
);

/// 업을 내지 않는 큰 방어다. 심판을 키우지 않고 강한 예고를 막아 정화 선택을 보존한다.
const ironGuard = CardDef(
  id: 'card_iron_guard',
  name: '철갑 수비',
  type: CardType.skill,
  cost: 1,
  targeted: false,
  effects: [BlockEffect(10)],
);

/// 작은 방어 뒤 한 장을 뽑는다. 카드를 낸 뒤 빈 한 칸만 채워 손패 상한 낭비 없이 선택지를 넓힌다.
const steadyBreath = CardDef(
  id: 'card_steady_breath',
  name: '호흡 고르기',
  type: CardType.skill,
  cost: 1,
  targeted: false,
  effects: [BlockEffect(3), DrawCardsEffect(1)],
);

/// 방어와 기력 1을 함께 준다. 업 없이 다음 고비용 지속 카드에 기력을 넘기는 연결 카드다.
const recoveredEnergy = CardDef(
  id: 'card_recovered_energy',
  name: '되찾은 기력',
  type: CardType.skill,
  cost: 1,
  targeted: false,
  effects: [BlockEffect(3), GainEnergyEffect(1)],
);

/// 방어와 굳음 1을 남긴다. 업을 내지 않는 장기 방어로 정화 뒤에도 버틸 수 있게 한다.
const guardianSigil = CardDef(
  id: 'card_guardian_sigil',
  name: '수호의 각인',
  type: CardType.skill,
  rarity: CardRarity.uncommon,
  cost: 1,
  targeted: false,
  effects: [
    BlockEffect(5),
    ApplyStatusEffect(
      status: StatusId.dexterity,
      stacks: 1,
      target: EffectTarget.self,
    ),
  ],
);

/// 업 2를 내고 큰 방어를 얻는다. 지금 생존을 사는 대신 나중의 심판을 정화로 갚아야 한다.
const greedyBarrier = CardDef(
  id: 'card_greedy_barrier',
  name: '탐욕의 장벽',
  type: CardType.skill,
  rarity: CardRarity.uncommon,
  cost: 1,
  karma: 2,
  targeted: false,
  effects: [BlockEffect(11)],
);

/// 작은 방어와 적 약화 2를 준다. 업을 쌓지 않고 다수의 다음 공격을 낮춰 정화할 턴을 만든다.
const weakeningGlance = CardDef(
  id: 'card_weakening_glance',
  name: '외면의 약화',
  type: CardType.skill,
  cost: 1,
  effects: [
    BlockEffect(3),
    ApplyStatusEffect(status: StatusId.weak, stacks: 2),
  ],
);

/// 업 3을 내고 기세 2를 전투 내내 남긴다. 빠른 처치와 더 높은 심판을 맞바꾸는 지속 투자다.
const hellfireMomentum = CardDef(
  id: 'card_hellfire_momentum',
  name: '업화의 기세',
  type: CardType.power,
  rarity: CardRarity.rare,
  cost: 1,
  karma: 3,
  targeted: false,
  effects: [
    BlockEffect(2),
    ApplyStatusEffect(
      status: StatusId.strength,
      stacks: 2,
      target: EffectTarget.self,
    ),
  ],
);

/// 업 없이 굳음 2를 지속시킨다. 심판 대신 방어 누적으로 긴 전투와 정화를 선택하는 투자다.
const ironVow = CardDef(
  id: 'card_iron_vow',
  name: '강철의 서약',
  type: CardType.power,
  rarity: CardRarity.uncommon,
  cost: 2,
  targeted: false,
  effects: [
    BlockEffect(2),
    ApplyStatusEffect(
      status: StatusId.dexterity,
      stacks: 2,
      target: EffectTarget.self,
    ),
  ],
);

/// 업 1을 내고 기세·굳음 1을 모두 남긴다. 작은 심판 부담으로 공격과 방어를 함께 굳히는 절충이다.
const clingingOath = CardDef(
  id: 'card_clinging_oath',
  name: '집착의 맹세',
  type: CardType.power,
  rarity: CardRarity.rare,
  cost: 2,
  karma: 1,
  targeted: false,
  effects: [
    BlockEffect(2),
    ApplyStatusEffect(
      status: StatusId.strength,
      stacks: 1,
      target: EffectTarget.self,
    ),
    ApplyStatusEffect(
      status: StatusId.dexterity,
      stacks: 1,
      target: EffectTarget.self,
    ),
  ],
);

/// 체력 5를 내고 업 8을 씻는다. 심판을 늦추기 위해 즉시 생존 자원을 포기하는 정화다.
const confession = CardDef(
  id: 'card_confession',
  name: '고해',
  type: CardType.skill,
  cost: 1,
  targeted: false,
  effects: [BlockEffect(2), LoseHpEffect(5), ChangeKarmaEffect(-8)],
);

/// 한 턴의 기력 3을 모두 내고 업 18을 씻는다. 공격 기회를 통째로 포기하는 큰 정화다.
const greatPurification = CardDef(
  id: 'card_great_purification',
  name: '대정화',
  type: CardType.skill,
  rarity: CardRarity.rare,
  cost: 3,
  targeted: false,
  effects: [BlockEffect(6), ChangeKarmaEffect(-18)],
);

/// M0 카드 풀. 전투 규칙이 흔들리는 동안에는 JSON 스키마가 아니라 Dart 상수로 둔다(§7.3).
const m0Cards = <CardDef>[
  strike,
  bladeOfGrudge,
  sinfulSlash,
  venomVerdict,
  inquisitionBrand,
  twinVerdict,
  suppressingCut,
  cleanCut,
  defend,
  ironGuard,
  steadyBreath,
  recoveredEnergy,
  guardianSigil,
  greedyBarrier,
  weakeningGlance,
  hellfireMomentum,
  ironVow,
  clingingOath,
  confession,
  greatPurification,
];

/// 무관의 시작 덱 8장 (§2.1).
///
/// 기본 공격·방어를 두 장씩 두고, 업을 내는 공격 둘과 업 방어 하나를 넣는다.
/// 여기에 체력을 대가로 업을 씻는 [confession]을 함께 넣어 §8.1의 첫 질문이
/// 첫 전투부터 성립하게 한다. 즉시 처치·생존을 위해 업을 쌓을지, 정화를 위해
/// 체력과 한 장을 쓸지 선택하게 하며, 나머지 M0 카드는 보상으로 발견한다.
const starterDeck = <CardDef>[
  strike,
  strike,
  defend,
  defend,
  bladeOfGrudge,
  sinfulSlash,
  greedyBarrier,
  confession,
];

/// 시작 덱에 없는 M0 카드는 모두 전투 카드 보상에서만 만난다.
const cardRewardPool = <CardDef>[
  venomVerdict,
  inquisitionBrand,
  twinVerdict,
  suppressingCut,
  cleanCut,
  ironGuard,
  steadyBreath,
  recoveredEnergy,
  guardianSigil,
  weakeningGlance,
  hellfireMomentum,
  ironVow,
  clingingOath,
  greatPurification,
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

/// 독귀(毒鬼) — 막아도 사라지지 않는 중독을 남긴 뒤 버틴다.
///
/// 중독은 플레이어 턴 시작에 방어도를 무시하므로, 이 적의 질문은 "긴 전투를
/// 감수할 것인가, 지금 밀어붙여 중독 누적을 끊을 것인가"다. 아귀의 큰 한 방과
/// 달리 단순 방어만으로는 답이 되지 않는다.
Enemy dokgwi() => const Enemy(
  id: 'enemy_dokgwi',
  name: '독귀',
  hp: 16,
  maxHp: 16,
  pattern: [EnemyInflict(StatusId.poison, 2), EnemyDefend(4), EnemyAttack(7)],
);

/// 야차(夜叉) — 자기 기세를 쌓은 뒤 두 번 때린다.
///
/// 다음 예고가 기세 강화면 약화로 피해를 낮출지, 강화된 연타 전에 먼저 처치할지를
/// 묻는다. 원귀가 플레이어의 공격을 약하게 만드는 적이라면, 야차는 적 공격 자체를
/// 상태 카드로 꺾어야 하는 적이다.
Enemy yacha() => const Enemy(
  id: 'enemy_yacha',
  name: '야차',
  hp: 22,
  maxHp: 22,
  pattern: [
    EnemyInflict(StatusId.strength, 2, target: EffectTarget.self),
    EnemyAttack(5, times: 2),
    EnemyDefend(6),
  ],
);

/// 나찰(羅刹) — 방어를 먼저 쌓고 취약 뒤에 큰 한 방을 예고한다.
///
/// 이 적의 질문은 "방어도에 공격을 버릴 것인가, 독·원한을 심어 넘길 것인가"다.
/// 이어지는 취약+강공은 아귀처럼 바로 막기보다, 약화나 큰 방어를 미리 준비하게 한다.
Enemy nachal() => const Enemy(
  id: 'enemy_nachal',
  name: '나찰',
  hp: 26,
  maxHp: 26,
  pattern: [
    EnemyDefend(10),
    EnemyInflict(StatusId.vulnerable, 2),
    EnemyAttack(11),
  ],
);

/// M0의 기본 조우. §8.1의 2번 질문("세로 화면에서 카드 5장 + 적이
/// 답답하지 않은가")은 적 3마리를 실제로 보아야 물을 수 있다. 중독·약화·큰 예고를
/// 함께 둬 한 화면에서 서로 다른 다음 행동을 읽게 하되, 체력 합계는 M0 한 전투가
/// 2~3분을 넘기지 않도록 58로 제한한다.
List<Enemy> defaultEncounter() => [agwi(), wongwi(), dokgwi()];

/// M1 런 재생에 주입하는 M0 콘텐츠.
///
/// `defaultEncounter()`의 세 적은 M0에서 검증한 기본 조합으로 유지하고, 남은
/// 두 적까지 풀에 넣어 런 노드가 encounter 스트림으로 구성을 뽑는다. 카드 보상이
/// 생겼으므로 시작 덱 밖의 [cardRewardPool]와 M1 사건 8종도 함께 주입한다.
RunContent m0RunContent() => RunContent(
  maxHp: startingHp,
  deck: starterDeck,
  encounterPool: [...defaultEncounter(), yacha(), nachal()],
  cardRewardPool: cardRewardPool,
  events: m1Events,
);

/// 플레이어 시작 체력 (§3.2 — 체력 범위 0~80).
const startingHp = 80;
