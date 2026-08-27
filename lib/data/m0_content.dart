/// M1 런 콘텐츠 조립기와 M0 적 콘텐츠 (기획서 §7.3, §12-2).
///
/// 카드 정의는 이 파일에 두지 않는다. 앱과 테스트 모두 `cards.json`을 같은
/// [CardContentLoader.decode] 경로로 해석하고, 여기에는 시작 덱·보상 풀의 id만 둔다.
library;

import '../domain/model/boss.dart';
import '../domain/model/card.dart';
import '../domain/model/enemy.dart';
import '../domain/model/status.dart';
import '../domain/run/run_content.dart';
import 'm1_events.dart';
import 'm1_relics.dart';

const _starterCardIds = <String>[
  'card_strike',
  'card_strike',
  'card_defend',
  'card_defend',
  'card_blade_of_grudge',
  'card_sinful_slash',
  'card_greedy_barrier',
  'card_confession',
];

const _cardRewardIds = <String>[
  'card_venom_verdict',
  'card_inquisition_brand',
  'card_twin_verdict',
  'card_suppressing_cut',
  'card_clean_cut',
  'card_iron_guard',
  'card_steady_breath',
  'card_recovered_energy',
  'card_guardian_sigil',
  'card_weakening_glance',
  'card_hellfire_momentum',
  'card_iron_vow',
  'card_clinging_oath',
  'card_great_purification',
  'card_fasting_vow',
  'card_thin_veil',
  'card_shattered_ward',
];

/// 아귀(餓鬼) — 세 번 주기로 공격·방어·강공을 반복한다.
Enemy agwi() => const Enemy(
  id: 'enemy_agwi',
  name: '아귀',
  hp: 24,
  maxHp: 24,
  pattern: [EnemyAttack(6), EnemyDefend(5), EnemyAttack(9)],
);

/// 원귀(冤鬼) — 약화를 걸고 약한 2연타를 반복한다.
Enemy wongwi() => const Enemy(
  id: 'enemy_wongwi',
  name: '원귀',
  hp: 18,
  maxHp: 18,
  pattern: [EnemyInflict(StatusId.weak, 1), EnemyAttack(4, times: 2)],
);

/// 독귀(毒鬼) — 중독, 방어, 공격을 반복한다.
Enemy dokgwi() => const Enemy(
  id: 'enemy_dokgwi',
  name: '독귀',
  hp: 16,
  maxHp: 16,
  pattern: [EnemyInflict(StatusId.poison, 2), EnemyDefend(4), EnemyAttack(7)],
);

/// 야차(夜叉) — 스스로 기세를 쌓은 뒤 두 번 공격한다.
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

/// 나찰(羅刹) — 방어, 취약, 강공을 반복한다.
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

/// 염라대왕 — 49일의 업을 심판하는 첫 시왕 보스다.
BossDef yeomra() => BossDef(
  enemy: Enemy(
    id: 'boss_yeomra',
    name: '염라대왕',
    hp: 96,
    maxHp: 96,
    pattern: const [
      EnemyAttack(10),
      EnemyDefend(8),
      EnemyInflict(StatusId.vulnerable, 2),
    ],
    phases: [
      EnemyPhase(
        pattern: const [
          EnemyAttack(10),
          EnemyDefend(8),
          EnemyInflict(StatusId.vulnerable, 2),
        ],
      ),
      EnemyPhase(
        pattern: const [
          EnemyAttack(8, times: 2),
          EnemyInflict(StatusId.weak, 2),
          EnemyAttack(15),
        ],
      ),
    ],
  ),
  turbidExtraMove: const EnemyInflict(StatusId.poison, 2),
);

/// M0 기본 조우는 세 적을 올려 세로 화면의 밀도를 검증한다.
List<Enemy> defaultEncounter() => [agwi(), wongwi(), dokgwi()];

/// JSON 로더가 만든 버전 고정 카드 목록으로 M1 런 콘텐츠를 조립한다.
///
/// id 목록만 이 파일에 남겨 같은 카드 수치를 다시 적지 않는다. 따라서 런타임
/// 콘텐츠와 테스트가 수치가 다른 동명 카드를 가질 수 없다.
RunContent m1RunContentFromCards(List<CardDef> cards) {
  final cardsById = {for (final card in cards) card.id: card};

  CardDef byId(String id) {
    final card = cardsById[id];
    if (card == null) {
      throw ArgumentError.value(id, 'cards', 'M1 콘텐츠에 필요한 카드가 없다');
    }
    return card;
  }

  return RunContent(
    maxHp: startingHp,
    deck: [for (final id in _starterCardIds) byId(id)],
    encounterPool: [...defaultEncounter(), yacha(), nachal()],
    bossPool: [yeomra()],
    cardRewardPool: [for (final id in _cardRewardIds) byId(id)],
    events: m1Events,
    relicRewardPool: m1Relics,
  );
}

/// 플레이어 시작 체력 (기획서 §3.2의 체력 범위 0~80).
const startingHp = 80;
