/// 유물 선언. 효과 수치와 해석은 전투 엔진의 공통 규칙을 따른다.
library;

/// 유물이 전투 안에서 발동하는 시점.
enum RelicTrigger {
  combatStarted,
  turnStarted,
  cardPlayed,
  turnEnded,
  enemyDied,
  playerDamageDealt,
  playerDamageTaken,
}

/// 데이터가 보유하는 유물 정의. 효과와 발동 시점은 서로 독립적으로 바꾸지 않는다.
class RelicDef {
  RelicDef(this.id, this.name, this.trigger, this.effect)
    : assert(trigger == effect.trigger, '유물 효과의 고정 발동 시점과 정의가 다르다.');

  final String id;
  final String name;
  final RelicTrigger trigger;
  final RelicEffect effect;

  @override
  String toString() => 'RelicDef($id)';
}

/// 유물은 선언만 한다. 실제 피해·방어·드로우·상태 규칙은 전투 인터프리터가 맡는다.
sealed class RelicEffect {
  const RelicEffect(this.trigger);

  final RelicTrigger trigger;
}

final class KarmaScaledStrengthEffect extends RelicEffect {
  const KarmaScaledStrengthEffect() : super(RelicTrigger.combatStarted);
}

final class PureDexterityEffect extends RelicEffect {
  const PureDexterityEffect() : super(RelicTrigger.combatStarted);
}

final class OpeningDrawEffect extends RelicEffect {
  const OpeningDrawEffect() : super(RelicTrigger.combatStarted);
}

final class OpeningCleanseEffect extends RelicEffect {
  const OpeningCleanseEffect() : super(RelicTrigger.combatStarted);
}

final class KarmaBandBlockEffect extends RelicEffect {
  const KarmaBandBlockEffect() : super(RelicTrigger.turnStarted);
}

final class TurbidEnergyEffect extends RelicEffect {
  const TurbidEnergyEffect() : super(RelicTrigger.turnStarted);
}

final class KarmaCardBonusDamageEffect extends RelicEffect {
  const KarmaCardBonusDamageEffect() : super(RelicTrigger.cardPlayed);
}

final class CleanCardBlockEffect extends RelicEffect {
  const CleanCardBlockEffect() : super(RelicTrigger.cardPlayed);
}

final class UnblockedDamageVulnerableEffect extends RelicEffect {
  const UnblockedDamageVulnerableEffect()
    : super(RelicTrigger.playerDamageDealt);
}

final class UnblockedDamageKarmaEffect extends RelicEffect {
  const UnblockedDamageKarmaEffect() : super(RelicTrigger.playerDamageDealt);
}

final class KarmaBurstEffect extends RelicEffect {
  const KarmaBurstEffect() : super(RelicTrigger.turnEnded);
}

final class TurnEndCleanseEffect extends RelicEffect {
  const TurnEndCleanseEffect() : super(RelicTrigger.turnEnded);
}

final class EnemyDeathHealEffect extends RelicEffect {
  const EnemyDeathHealEffect() : super(RelicTrigger.enemyDied);
}

final class EnemyDeathBlockEffect extends RelicEffect {
  const EnemyDeathBlockEffect() : super(RelicTrigger.enemyDied);
}

final class TurbidDamageReductionEffect extends RelicEffect {
  const TurbidDamageReductionEffect() : super(RelicTrigger.playerDamageTaken);
}
