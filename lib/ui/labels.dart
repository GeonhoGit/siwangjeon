/// 화면에 쓰는 한국어 표기 (기획서 §3.4, §5.4).
///
/// 규칙이 아니라 **표기**만 여기 있다. 숫자는 전부 `domain/`이 계산해 준
/// 것을 받아 쓴다.
///
/// §5.4는 색맹 대응으로 "상태 효과를 색이 아니라 아이콘 모양으로 구분"하라고
/// 요구한다. M0은 임시 도형 단계라 글자로 적어 두었고, 이건 그 요구를 아직
/// 만족하지 않는다. 아이콘은 M1의 실제 UI에서 들어온다.
library;

import '../domain/effect/card_effect.dart';
import '../domain/model/card.dart';
import '../domain/model/enemy.dart';
import '../domain/model/status.dart';

String statusLabel(StatusId id) => switch (id) {
  StatusId.strength => '기세',
  StatusId.dexterity => '굳음',
  StatusId.vulnerable => '취약',
  StatusId.weak => '약화',
  StatusId.poison => '중독',
  StatusId.burn => '화상',
  StatusId.regen => '재생',
  StatusId.bind => '속박',
  StatusId.intangible => '무형',
  StatusId.insight => '통찰',
  StatusId.silence => '침묵',
  StatusId.grudge => '원한',
};

/// 적의 예고 행동 표기 (§3.1).
///
/// 공격의 피해량은 여기서 만들지 않는다. 약화·취약이 걸린 실제 수치는
/// `previewEnemyDamage`가 계산한다. 이 함수는 그 값을 받아 공격 횟수와 함께
/// 한 문자열로 배치만 하므로, 회당 피해와 배수의 순서가 다른 곳에서 갈리지 않는다.
String intentLabel(EnemyMove move, {int? damage}) => switch (move) {
  EnemyAttack(:final times) => _attackIntentLabel(damage: damage, times: times),
  EnemyDefend(:final block) => '방어 $block',
  EnemyInflict(:final status, :final stacks) =>
    '${statusLabel(status)} $stacks',
};

String _attackIntentLabel({required int? damage, required int times}) {
  if (damage == null) return times > 1 ? '공격 ×$times' : '공격';
  return times > 1 ? '공격 $damage ×$times' : '공격 $damage';
}

/// 겹친 손패의 왼쪽 띠에 남길 카드 식별자.
///
/// M0의 스무 카드 이름은 첫 두 글자가 모두 달라 비용과 함께 고를 수 있다.
/// 전체 이름과 효과는 선택 뒤 최상단 카드에서 그대로 읽는다.
String handCardLabel(CardDef card) =>
    card.name.length <= 2 ? card.name : card.name.substring(0, 2);

/// 카드에 적을 효과 요약.
///
/// 피해·방어는 이미 domain이 상태 효과까지 적용해 계산한 값을 받고, 나머지는
/// 카드 정의의 고정 숫자만 읽는다. 따라서 이 파일은 규칙을 다시 계산하지 않고
/// 카드가 내는 업·체력·드로우·기력 거래를 읽기 좋게 배치만 한다.
List<String> cardEffectLabels(CardDef card, {int? damage, int? block}) {
  final labels = <String>[
    if (damage != null) '피해 $damage',
    if (block != null) '방어 $block',
    if (card.karma != 0) '업 +${card.karma}',
  ];

  for (final effect in card.effects) {
    switch (effect) {
      case DamageEffect():
      case BlockEffect():
        continue;
      case ApplyStatusEffect():
        labels.add('${statusLabel(effect.status)} ${effect.stacks}');
      case ChangeKarmaEffect():
        final sign = effect.amount > 0 ? '+' : '';
        labels.add('업 $sign${effect.amount}');
      case DrawCardsEffect():
        labels.add('드로우 ${effect.count}');
      case GainEnergyEffect():
        labels.add('기력 +${effect.amount}');
      case LoseHpEffect():
        labels.add('체력 -${effect.amount}');
    }
  }

  return labels;
}
