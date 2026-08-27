/// M1 정예 보상 유물 정의.
library;

import '../domain/model/relic.dart';

final List<RelicDef> m1Relics = List.unmodifiable([
  // 업보 축을 전투 시작의 힘으로 바꾸는 선택이다.
  RelicDef(
    'relic_karma_ledger',
    '업보 장부',
    RelicTrigger.combatStarted,
    const KarmaScaledStrengthEffect(),
  ),
  // 청정 업보 축을 전투 시작의 민첩으로 바꾸는 선택이다.
  RelicDef(
    'relic_pure_mirror',
    '청정 거울',
    RelicTrigger.combatStarted,
    const PureDexterityEffect(),
  ),
  // 업보 축 대신 첫 손패 축을 전투 시작 드로우로 바꾸는 선택이다.
  RelicDef(
    'relic_dead_lantern',
    '망자의 등잔',
    RelicTrigger.combatStarted,
    const OpeningDrawEffect(),
  ),
  // 업보 축을 전투 시작 정화로 바꾸는 선택이다.
  RelicDef(
    'relic_confession_basin',
    '참회의 대야',
    RelicTrigger.combatStarted,
    const OpeningCleanseEffect(),
  ),
  // 업보 구간 축을 매 턴 방어도로 바꾸는 선택이다.
  RelicDef(
    'relic_judges_shield',
    '판관의 방패',
    RelicTrigger.turnStarted,
    const KarmaBandBlockEffect(),
  ),
  // 탁업 축을 매 턴 에너지로 바꾸는 선택이다.
  RelicDef(
    'relic_turbid_brazier',
    '탁업의 화로',
    RelicTrigger.turnStarted,
    const TurbidEnergyEffect(),
  ),
  // 업보 축을 카드 사용 피해 보너스로 바꾸는 선택이다.
  RelicDef(
    'relic_sinner_seal',
    '죄인의 인장',
    RelicTrigger.cardPlayed,
    const KarmaCardBonusDamageEffect(),
  ),
  // 청정 업보 축을 카드 사용 방어도로 바꾸는 선택이다.
  RelicDef(
    'relic_innocent_silk',
    '무죄의 비단',
    RelicTrigger.cardPlayed,
    const CleanCardBlockEffect(),
  ),
  // 막지 못한 피해 축을 취약으로 바꾸는 선택이다.
  RelicDef(
    'relic_bloody_brush',
    '피묻은 붓',
    RelicTrigger.playerDamageDealt,
    const UnblockedDamageVulnerableEffect(),
  ),
  // 막지 못한 피해 축을 업보 증가로 바꾸는 선택이다.
  RelicDef(
    'relic_karmic_abacus',
    '업화 주판',
    RelicTrigger.playerDamageDealt,
    const UnblockedDamageKarmaEffect(),
  ),
  // 업보 축을 턴 종료 폭발로 바꾸는 선택이다.
  RelicDef(
    'relic_grudge_urn',
    '원한 항아리',
    RelicTrigger.turnEnded,
    const KarmaBurstEffect(),
  ),
  // 업보 축을 턴 종료 정화로 바꾸는 선택이다.
  RelicDef(
    'relic_yamas_comb',
    '야마의 빗',
    RelicTrigger.turnEnded,
    const TurnEndCleanseEffect(),
  ),
  // 업보 축을 적 처치 회복으로 바꾸는 선택이다.
  RelicDef(
    'relic_soul_phial',
    '혼백 약병',
    RelicTrigger.enemyDied,
    const EnemyDeathHealEffect(),
  ),
  // 업보 축을 적 처치 방어도로 바꾸는 선택이다.
  RelicDef(
    'relic_guardian_beads',
    '수호 염주',
    RelicTrigger.enemyDied,
    const EnemyDeathBlockEffect(),
  ),
  // 탁업 축을 피격 경감으로 바꾸는 선택이다.
  RelicDef(
    'relic_black_absolution',
    '검은 면죄패',
    RelicTrigger.playerDamageTaken,
    const TurbidDamageReductionEffect(),
  ),
]);
