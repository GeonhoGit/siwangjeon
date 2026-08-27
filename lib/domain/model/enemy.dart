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

/// 한 페이즈에서 순환하는 시왕의 행동 묶음.
///
/// 기존 적은 [Enemy.pattern]만 가지므로, [phases]가 비어 있을 때의 행동과
/// 패턴 인덱스는 M0와 정확히 같다.
class EnemyPhase {
  EnemyPhase({required List<EnemyMove> pattern})
    : pattern = List.unmodifiable(pattern);

  final List<EnemyMove> pattern;
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
  const EnemyInflict(
    this.status,
    this.stacks, {
    this.target = EffectTarget.enemy,
  });

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
    this.phases = const [],
    this.phaseIndex = 0,
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

  /// 비어 있으면 [pattern] 하나만 쓰는 기존 적이다.
  final List<EnemyPhase> phases;

  /// 현재 활성 페이즈. 전환은 전투 엔진이 체력만 보고 결정하므로 난수를 쓰지
  /// 않고, 저장 액션 로그 재생도 흔들리지 않는다.
  final int phaseIndex;

  bool get isAlive => hp > 0;

  /// 이번 턴에 할 행동. 플레이어에게 미리 보여지는 값이다.
  int get phaseCount => phases.isEmpty ? 1 : phases.length;

  List<EnemyMove> get activePattern =>
      phases.isEmpty ? pattern : phases[phaseIndex].pattern;

  bool get canAdvancePhase => phaseIndex + 1 < phaseCount;

  /// 이번 턴에 할 행동. 플레이어에게 미리 보여지는 값이다.
  EnemyMove get intent => activePattern[patternIndex % activePattern.length];

  Enemy copyWith({
    int? hp,
    int? maxHp,
    int? block,
    Map<StatusId, int>? statuses,
    int? patternIndex,
    List<EnemyMove>? pattern,
    List<EnemyPhase>? phases,
    int? phaseIndex,
  }) {
    return Enemy(
      id: id,
      name: name,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      block: block ?? this.block,
      statuses: statuses ?? this.statuses,
      pattern: pattern ?? this.pattern,
      patternIndex: patternIndex ?? this.patternIndex,
      phases: phases ?? this.phases,
      phaseIndex: phaseIndex ?? this.phaseIndex,
    );
  }

  /// 탁함 심판의 추가 행동을 모든 보스 페이즈 순환에 붙인다.
  Enemy withExtraPattern(EnemyMove move) {
    if (phases.isEmpty) {
      return copyWith(pattern: [...pattern, move]);
    }
    return copyWith(
      phases: [
        for (final phase in phases)
          EnemyPhase(pattern: [...phase.pattern, move]),
      ],
    );
  }

  @override
  String toString() => 'Enemy($id, hp=$hp/$maxHp, block=$block)';
}
