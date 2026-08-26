/// 적과 그 예고 행동 (기획서 §3.1).
///
/// "다음 행동은 항상 아이콘으로 미리 표시"(§3.1)가 규칙이므로,
/// 적의 다음 수는 전투 상태의 일부다. UI가 추측하는 것이 아니라
/// 엔진이 미리 정해 상태에 담아 둔다.
library;

import 'status.dart';

/// 적이 한 턴에 하는 행동.
sealed class EnemyMove {
  const EnemyMove();
}

final class EnemyAttack extends EnemyMove {
  const EnemyAttack(this.damage, {this.times = 1});

  final int damage;

  /// 연속 공격 횟수. 방어도를 잘게 깎는 패턴에 쓴다.
  final int times;
}

final class EnemyDefend extends EnemyMove {
  const EnemyDefend(this.block);

  final int block;
}

final class EnemyInflict extends EnemyMove {
  const EnemyInflict(this.status, this.stacks, {this.target = EffectTarget.enemy});

  final StatusId status;
  final int stacks;

  /// 적 입장에서의 대상이다. [EffectTarget.enemy]는 플레이어를 뜻하고,
  /// [EffectTarget.self]는 그 적 자신을 뜻한다.
  final EffectTarget target;
}

class Enemy {
  const Enemy({
    required this.id,
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.pattern,
    this.block = 0,
    this.statuses = const {},
    this.patternIndex = 0,
  });

  final String id;
  final String name;
  final int hp;
  final int maxHp;
  final int block;
  final Map<StatusId, int> statuses;

  /// 행동 순서. M0에서는 난수 없이 순환한다.
  ///
  /// 적 행동까지 난수로 뽑으면 M0의 목적인 "재미 판정"(§8.1)에서
  /// 관찰한 결과가 설계 때문인지 운 때문인지 구분되지 않는다.
  /// 패턴 선택의 난수화는 적 종류가 늘어나는 M1 이후의 문제다.
  final List<EnemyMove> pattern;
  final int patternIndex;

  bool get isAlive => hp > 0;

  /// 이번 턴에 할 행동. 플레이어에게 미리 보여지는 값이다.
  EnemyMove get intent => pattern[patternIndex % pattern.length];

  Enemy copyWith({
    int? hp,
    int? block,
    Map<StatusId, int>? statuses,
    int? patternIndex,
  }) {
    return Enemy(
      id: id,
      name: name,
      hp: hp ?? this.hp,
      maxHp: maxHp,
      block: block ?? this.block,
      statuses: statuses ?? this.statuses,
      pattern: pattern,
      patternIndex: patternIndex ?? this.patternIndex,
    );
  }

  @override
  String toString() => 'Enemy($id, hp=$hp/$maxHp, block=$block)';
}
