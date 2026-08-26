/// 전투 화면 — M0 임시 UI (기획서 §5.2, §12-2).
///
/// 임시 도형으로 만든다. 실제 아트는 M1의 병행 트랙에서 들어온다(§8).
/// **M0에는 아트에 손대지 않는다**(§12-5). 지금 필요한 건 그림이 아니라
/// §8.1의 세 질문에 답할 수 있는 플레이 가능한 전투다.
///
/// 1. 업 시스템이 실제로 매 턴 고민을 만드는가?
/// 2. 세로 화면에서 카드 5장 + 적이 답답하지 않은가?
/// 3. 한 전투가 2~3분에 끝나는가?
///
/// 그래서 화면 위에 경과 시간을 띄워 둔다. 3번은 체감이 아니라 초시계로
/// 답해야 하는 질문이고, 4주 뒤에 기억으로 답하면 틀린다.
///
/// 이 파일은 전투 규칙을 모른다. 숫자는 전부 `domain/`이 계산해 준 것을 받는다.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/combat_controller.dart';
import '../domain/combat/combat_engine.dart';
import '../domain/effect/card_effect.dart';
import '../domain/model/card.dart';
import '../domain/model/combat_state.dart';
import '../domain/model/enemy.dart';
import '../domain/model/game_event.dart';
import '../domain/model/status.dart';
import 'labels.dart';

const _attackColor = Color(0xFFB2332B);
const _skillColor = Color(0xFF2E6B6B);
const _karmaColor = Color(0xFFC9A227);

class CombatScreen extends ConsumerStatefulWidget {
  const CombatScreen({super.key});

  @override
  ConsumerState<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends ConsumerState<CombatScreen> {
  /// 선택된 손패 위치. §5.3의 "탭 → 확대, 다시 탭 or 대상 탭 → 사용".
  int? _selected;

  final _stopwatch = Stopwatch()..start();
  Timer? _ticker;
  int _timedSeed = -1;

  @override
  void initState() {
    super.initState();
    // 경과 시간 표시용. 도메인에는 시계가 없고(§7.2) 있어서도 안 된다.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(combatControllerProvider);
    final state = session.state;

    // 새 전투가 시작되면 초시계도 새로 돌린다.
    if (_timedSeed != session.seed) {
      _timedSeed = session.seed;
      _stopwatch
        ..reset()
        ..start();
      _selected = null;
    }
    if (state.isOver && _stopwatch.isRunning) _stopwatch.stop();

    final selectedCard = _selected != null && _selected! < state.hand.length
        ? state.hand[_selected!]
        : null;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _StatusBar(state: state, elapsed: _stopwatch.elapsed),

                // §5.1 — 상단 40%는 정보 영역, 탭 대상이 아니다.
                // 다만 대상 지정 중일 때만 적이 탭을 받는다(§5.3).
                Expanded(
                  flex: 40,
                  child: _EnemyArea(
                    state: state,
                    events: session.lastEvents,
                    selectedCard: selectedCard,
                    onTapEnemy: selectedCard != null && selectedCard.targeted
                        ? (index) => _play(index)
                        : null,
                  ),
                ),

                // §5.1 — 하단 60%에 모든 상호작용 요소를 배치한다.
                Expanded(
                  flex: 60,
                  child: _HandArea(
                    state: state,
                    actionCount: session.actionLog.length,
                    selected: _selected,
                    onTapCard: _onTapCard,
                    onEndTurn: state.isOver
                        ? null
                        : () {
                            setState(() => _selected = null);
                            ref
                                .read(combatControllerProvider.notifier)
                                .endTurn();
                          },
                  ),
                ),
              ],
            ),
            if (state.isOver)
              _OutcomeOverlay(
                outcome: state.outcome!,
                turn: state.turn,
                karma: state.karma,
                elapsed: _stopwatch.elapsed,
                seed: session.seed,
                onRestart: () =>
                    ref.read(combatControllerProvider.notifier).restart(),
              ),
          ],
        ),
      ),
    );
  }

  void _onTapCard(int index) {
    final state = ref.read(combatControllerProvider).state;
    final card = state.hand[index];

    // 이미 고른 카드를 다시 탭하면: 대상이 없는 카드는 사용, 있는 카드는 취소.
    // §5.3의 "사용 전 항상 취소 가능"을 지키려면 되돌아갈 길이 있어야 한다.
    if (_selected == index) {
      if (card.targeted) {
        setState(() => _selected = null);
      } else {
        _play(null);
      }
      return;
    }

    setState(() => _selected = index);
  }

  void _play(int? targetIndex) {
    final index = _selected;
    if (index == null) return;

    ref
        .read(combatControllerProvider.notifier)
        .play(index, targetIndex: targetIndex);
    setState(() => _selected = null);
  }
}

// ── 상태바 ────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state, required this.elapsed});

  final CombatState state;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: _Meter(
              label: '혼',
              value: state.hp,
              max: state.maxHp,
              color: const Color(0xFF8FBF6B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Meter(
              label: '업',
              value: state.karma,
              max: 100,
              color: _karmaColor,
              // 업 수치만으로는 그것이 좋은 상태인지 알 수 없다.
              // §3.3의 등급이 곧 심판에서 무슨 일이 벌어지는지이므로 같이 적는다.
              suffix: _bandLabel(state.karmaBand),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$minutes:$seconds', style: const TextStyle(fontSize: 13)),
              Text(
                '${state.turn}턴',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _bandLabel(KarmaBand band) => switch (band) {
    KarmaBand.pure => '청정',
    KarmaBand.ordinary => '평범',
    KarmaBand.turbid => '탁함',
    KarmaBand.wicked => '악업',
  };
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.suffix,
  });

  final String label;
  final int value;
  final int max;
  final Color color;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '$value / $max',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            if (suffix != null)
              Text(suffix!, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: max == 0 ? 0 : value / max,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ── 적 영역 (상단 40%) ─────────────────────────────────────

class _EnemyArea extends StatelessWidget {
  const _EnemyArea({
    required this.state,
    required this.events,
    required this.selectedCard,
    required this.onTapEnemy,
  });

  final CombatState state;
  final List<GameEvent> events;
  final CardDef? selectedCard;
  final void Function(int index)? onTapEnemy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < state.enemies.length; i++)
                if (state.enemies[i].isAlive)
                  _EnemyView(
                    enemy: state.enemies[i],
                    intentDamage: previewEnemyDamage(state, i),
                    incoming: selectedCard == null || !selectedCard!.targeted
                        ? null
                        : previewDamage(state, selectedCard!, targetIndex: i),
                    targeting: onTapEnemy != null,
                    onTap: onTapEnemy == null ? null : () => onTapEnemy!(i),
                  ),
            ],
          ),
        ),
        _EventStrip(events: events, state: state),
      ],
    );
  }
}

class _EnemyView extends StatelessWidget {
  const _EnemyView({
    required this.enemy,
    required this.intentDamage,
    required this.incoming,
    required this.targeting,
    required this.onTap,
  });

  final Enemy enemy;
  final int? intentDamage;
  final int? incoming;
  final bool targeting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final intent = intentLabel(enemy.intent);
    final intentText = intentDamage == null ? intent : '$intent $intentDamage';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // §3.1 — 다음 행동은 항상 아이콘으로 미리 표시한다.
          // M0은 임시로 글자다.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(intentText, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 6),

          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFF4A3A44),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: targeting
                    ? _attackColor
                    : Colors.white.withValues(alpha: 0.2),
                width: targeting ? 2.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(enemy.name, style: const TextStyle(fontSize: 15)),
                if (incoming != null)
                  Text(
                    '−$incoming',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _attackColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),

          SizedBox(
            width: 92,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: enemy.hp / enemy.maxHp,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF9E4A4A)),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${enemy.hp} / ${enemy.maxHp}',
            style: const TextStyle(fontSize: 11),
          ),

          if (enemy.block > 0)
            Text(
              '백 ${enemy.block}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF7FA8C9)),
            ),

          _StatusRow(statuses: enemy.statuses),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.statuses});

  final Map<StatusId, int> statuses;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        children: [
          for (final entry in statuses.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${statusLabel(entry.key)} ${entry.value}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

/// 직전 액션이 만들어 낸 이벤트를 한 줄로 보여 준다.
///
/// M1에서 애니메이션이 들어오면 사라질 자리다. 지금 이것이 필요한 이유는
/// 숫자가 왜 그렇게 변했는지 보이지 않으면 §8.1의 1번 질문을 판단할 수
/// 없기 때문이다.
class _EventStrip extends StatelessWidget {
  const _EventStrip({required this.events, required this.state});

  final List<GameEvent> events;
  final CombatState state;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];

    String who(int index) => index == CombatState.playerIndex
        ? '나'
        : (index < state.enemies.length ? state.enemies[index].name : '적');

    for (final event in events) {
      switch (event) {
        case DamageDealt():
          if (event.amount == 0 && event.blocked == 0) continue;
          final blocked = event.blocked > 0 ? ' (막음 ${event.blocked})' : '';
          lines.add('${who(event.targetIndex)} 피해 ${event.amount}$blocked');
        case KarmaGained():
          lines.add('업 +${event.amount}');
        case StatusApplied():
          lines.add(
            '${who(event.targetIndex)} ${statusLabel(event.status)} +${event.stacks}',
          );
        case EnemyDied():
          lines.add('${who(event.index)} 쓰러짐');
        case DeckReshuffled():
          lines.add('덱 섞음 ${event.count}');
        case CardPlayed():
        case BlockGained():
        case CardsDrawn():
        case TurnEnded():
        case TurnStarted():
        case CombatEnded():
          continue;
      }
    }

    return Container(
      height: 24,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        lines.isEmpty ? '' : lines.join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ── 손패 영역 (하단 60%) ───────────────────────────────────

class _HandArea extends StatelessWidget {
  const _HandArea({
    required this.state,
    required this.actionCount,
    required this.selected,
    required this.onTapCard,
    required this.onEndTurn,
  });

  final CombatState state;
  final int actionCount;
  final int? selected;
  final void Function(int index) onTapCard;
  final VoidCallback? onEndTurn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ResourceRow(state: state),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Fan(
              state: state,
              actionCount: actionCount,
              selected: selected,
              onTapCard: onTapCard,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // §5.2 — 우하단이 엄지 홈포지션이다.
              FilledButton(
                key: const ValueKey('end-turn'),
                onPressed: onEndTurn,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 48), // §5.1 최소 터치 타겟 48dp
                ),
                child: const Text('턴 종료'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.state});

  final CombatState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Text('기력 ', style: TextStyle(fontSize: 13)),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(
                i < state.energy ? Icons.circle : Icons.circle_outlined,
                size: 13,
                color: const Color(0xFFE0C060),
              ),
            ),
          const Spacer(),
          Text(
            '덱 ${state.drawPile.length}   버림 ${state.discardPile.length}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          if (state.block > 0) ...[
            const SizedBox(width: 10),
            Text(
              '백 ${state.block}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF7FA8C9)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 부채꼴 손패 (§5.2).
class _Fan extends StatefulWidget {
  const _Fan({
    required this.state,
    required this.actionCount,
    required this.selected,
    required this.onTapCard,
  });

  final CombatState state;
  final int actionCount;
  final int? selected;
  final void Function(int index) onTapCard;

  @override
  State<_Fan> createState() => _FanState();
}

class _FanState extends State<_Fan> with SingleTickerProviderStateMixin {
  static const _cardWidth = 96.0;
  static const _selectionDuration = Duration(milliseconds: 120);

  late final AnimationController _selectionController;
  int? _previousSelected;

  @override
  void initState() {
    super.initState();
    _selectionController = AnimationController(
      vsync: this,
      duration: _selectionDuration,
      value: widget.selected == null ? 0 : 1,
    );
  }

  @override
  void didUpdateWidget(covariant _Fan oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.actionCount != oldWidget.actionCount) {
      // 적용된 액션은 항상 손패를 바꾼다. 같은 카드가 같은 순서로 다시 뽑혀도
      // 인덱스는 이전 손패를 가리키므로, 이전 선택의 축소를 즉시 버린다.
      _previousSelected = null;
      _selectionController
        ..stop()
        ..value = widget.selected == null ? 0 : 1;
      return;
    }

    if (widget.selected == oldWidget.selected) return;

    _previousSelected = oldWidget.selected;
    _selectionController.forward(from: 0);
  }

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hand = widget.state.hand;
    if (hand.isEmpty) {
      return Center(
        child: Text(
          '손패 없음',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        ),
      );
    }

    return Flow(
      delegate: _HandFanDelegate(
        cardCount: hand.length,
        selected: widget.selected,
        previousSelected: _previousSelected,
        selectionProgress: _selectionController,
      ),
      children: [
        for (var i = 0; i < hand.length; i++)
          GestureDetector(
            key: ValueKey('hand-card-$i'),
            onTap: widget.state.isOver ? null : () => widget.onTapCard(i),
            child: _CardView(
              card: hand[i],
              state: widget.state,
              width: _cardWidth,
              selected: widget.selected == i,
              playable:
                  widget.state.energy >= hand[i].cost && !widget.state.isOver,
            ),
          ),
      ],
    );
  }
}

class _HandFanDelegate extends FlowDelegate {
  _HandFanDelegate({
    required this.cardCount,
    required this.selected,
    required this.previousSelected,
    required Animation<double> selectionProgress,
  }) : _selectionProgress = selectionProgress,
       super(repaint: selectionProgress);

  static const _edgeInset = 8.0;
  static const _rotationPerOffset = 0.075;
  static const _selectedScale = 1.12;
  static const _selectedLift = 34.0;

  final int cardCount;
  final int? selected;
  final int? previousSelected;
  final Animation<double> _selectionProgress;

  @override
  BoxConstraints getConstraintsForChild(int index, BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final sizes = [
      for (var i = 0; i < cardCount; i++) context.getChildSize(i)!,
    ];
    final offsets = [
      for (var i = 0; i < cardCount; i++) i - (cardCount - 1) / 2,
    ];
    final baseAngles = [
      for (var i = 0; i < cardCount; i++) offsets[i] * _rotationPerOffset,
    ];
    final angles = [
      for (var i = 0; i < cardCount; i++) selected == i ? 0.0 : baseAngles[i],
    ];
    final scales = [
      for (var i = 0; i < cardCount; i++)
        selected == i
            ? 1 + (_selectedScale - 1) * _selectionProgress.value
            : previousSelected == i
            ? _selectedScale - (_selectedScale - 1) * _selectionProgress.value
            : 1.0,
    ];
    final baseProjectedWidths = [
      for (var i = 0; i < cardCount; i++)
        sizes[i].width * math.cos(baseAngles[i].abs()) +
            sizes[i].height * math.sin(baseAngles[i].abs()),
    ];
    // 선택 확대를 처음부터 예약해 간격이 애니메이션 중에도 흔들리지 않게 한다.
    // 회전한 폭과 선택되어 회전이 0이 된 폭 중 큰 값을 쓰므로, Matrix4 확대가
    // 자식 크기에 반영되지 않는 Flow에서도 양끝 카드의 화면 여백은 보장된다.
    final widestReservedCard = [
      for (var i = 0; i < cardCount; i++)
        _selectedScale * math.max(baseProjectedWidths[i], sizes[i].width),
    ].reduce(math.max);
    final maxStableSpread = baseProjectedWidths.reduce(math.max);

    final spread = cardCount == 1
        ? 0.0
        : math.min(
            maxStableSpread,
            math.max(
              0.0,
              (context.size.width - widestReservedCard - _edgeInset * 2) /
                  (cardCount - 1),
            ),
          );

    for (var i = 0; i < cardCount; i++) {
      final size = sizes[i];
      final angle = angles[i];
      final scale = scales[i];
      final projectedHeight =
          scale *
          (size.height * math.cos(angle.abs()) +
              size.width * math.sin(angle.abs()));
      final left = (context.size.width - size.width) / 2 + offsets[i] * spread;
      final top =
          context.size.height -
          _edgeInset -
          (size.height + projectedHeight) / 2 -
          (selected == i ? _selectedLift : 0);

      context.paintChild(
        i,
        transform: Matrix4.identity()
          ..translateByDouble(
            left + size.width / 2,
            top + size.height / 2,
            0,
            1,
          )
          ..rotateZ(angle)
          ..scaleByDouble(scale, scale, 1, 1)
          ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HandFanDelegate oldDelegate) {
    return cardCount != oldDelegate.cardCount ||
        selected != oldDelegate.selected;
  }
}

class _CardView extends StatelessWidget {
  const _CardView({
    required this.card,
    required this.state,
    required this.width,
    required this.selected,
    required this.playable,
  });

  final CardDef card;
  final CombatState state;
  final double width;
  final bool selected;
  final bool playable;

  @override
  Widget build(BuildContext context) {
    final accent = switch (card.type) {
      CardType.attack => _attackColor,
      CardType.skill => _skillColor,
      _ => Colors.grey,
    };

    // 숫자는 엔진이 준 것만 쓴다. 화면이 다시 계산하면 카드에 적힌 값과
    // 실제로 들어가는 값이 갈라진다.
    final damage = previewDamage(state, card);
    final block = previewBlock(state, card);
    final costDiameter = MediaQuery.textScalerOf(context).scale(20);

    return Opacity(
      opacity: playable ? 1 : 0.45,
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 132),
        decoration: BoxDecoration(
          color: const Color(0xFF241C20),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? Colors.white : accent.withValues(alpha: 0.75),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Container(
                  width: costDiameter,
                  height: costDiameter,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0C060),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${card.cost}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                // 업 표시는 카드에서 가장 중요한 정보다(§3.3).
                // 이게 눈에 띄지 않으면 §8.1의 1번 질문은 물어볼 수조차 없다.
                if (card.karma > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _karmaColor.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _karmaColor.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Text(
                      '업 +${card.karma}',
                      style: const TextStyle(fontSize: 9, color: _karmaColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              card.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (damage != null)
              Text(
                '피해 $damage',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            if (block != null)
              Text(
                '방어 $block',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7FA8C9),
                ),
              ),
            for (final effect in card.effects.whereType<ApplyStatusEffect>())
              Text(
                '${statusLabel(effect.status)} ${effect.stacks}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 종료 화면 ──────────────────────────────────────────────

class _OutcomeOverlay extends StatelessWidget {
  const _OutcomeOverlay({
    required this.outcome,
    required this.turn,
    required this.karma,
    required this.elapsed,
    required this.seed,
    required this.onRestart,
  });

  final CombatOutcome outcome;
  final int turn;
  final int karma;
  final Duration elapsed;
  final int seed;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final won = outcome == CombatOutcome.victory;
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            won ? '승리' : '패배',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: won ? const Color(0xFFE0C060) : _attackColor,
            ),
          ),
          const SizedBox(height: 12),

          // §8.1의 3번 질문("한 전투가 2~3분에 끝나는가")에 답하기 위한 기록.
          Text(
            '$minutes:$seconds   $turn턴   업 $karma',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 4),

          // 이상한 판을 만났으면 이 숫자를 적어 두면 그대로 다시 볼 수 있다(§7.4).
          Text(
            '시드 $seed',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: onRestart,
            style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
            child: const Text('다시'),
          ),
        ],
      ),
    );
  }
}
