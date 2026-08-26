/// 카드 효과 (기획서 §7.3).
///
/// 카드는 코드가 아니라 `assets/data/cards.json`으로 정의된다.
/// 이 sealed 계층은 그 JSON의 `effects` 배열을 해석한 결과물이며,
/// 인터프리터가 [CardEffect]를 받아 전투 상태에 적용한다.
library;

sealed class CardEffect {
  const CardEffect();
}

/// `{"op": "damage", "value": 6, "scaleWith": "karma", "scale": 0.1}`
final class DamageEffect extends CardEffect {
  const DamageEffect({
    required this.value,
    this.scaleWith,
    this.scale = 0,
  });

  final int value;

  /// 피해량을 함께 키우는 자원 이름. 현재는 `karma`만 쓴다.
  final String? scaleWith;

  /// 자원 1당 증가 비율.
  final double scale;
}

/// `{"op": "applyStatus", "status": "grudge", "stacks": 1}`
final class ApplyStatusEffect extends CardEffect {
  const ApplyStatusEffect({required this.status, required this.stacks});

  final String status;
  final int stacks;
}

/// 방어(魄)를 부여한다. 턴 종료 시 소멸한다 (§3.2).
final class BlockEffect extends CardEffect {
  const BlockEffect(this.value);

  final int value;
}
