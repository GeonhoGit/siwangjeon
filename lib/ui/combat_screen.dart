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
import '../domain/model/card.dart';
import '../domain/model/combat_state.dart';
import '../domain/model/enemy.dart';
import '../domain/model/game_event.dart';
import '../domain/model/status.dart';
import 'labels.dart';

const _attackColor = Color(0xFFB2332B);
const _skillColor = Color(0xFF2E6B6B);
const _karmaColor = Color(0xFFC9A227);
const _cardMinimumHeight = 132.0;
const _cardSecondEffectLineAllowance = 12.0;
// 예고와 체력 바의 좌우 경계를 맞춰 적의 다음 행동과 생존 상태를 함께 읽는다.
const _enemyMeterWidth = 92.0;

double _cardReservedMinimumHeight(TextScaler textScaler, int effectCount) =>
    textScaler.scale(
      _cardMinimumHeight +
          (effectCount > 2 ? _cardSecondEffectLineAllowance : 0),
    );

double _cardReservedMinimumHeightFor(
  CombatState state,
  CardDef card,
  TextScaler textScaler,
) {
  // Flow의 초기 높이도 카드와 같은 domain 미리보기·표기 목록을 써야 자연스러운
  // 줄바꿈 뒤 다음 프레임에 손패가 튀지 않는다.
  final effectCount = cardEffectLabels(
    card,
    damage: previewDamage(state, card),
    block: previewBlock(state, card),
  ).length;
  return _cardReservedMinimumHeight(textScaler, effectCount);
}

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // §5.1의 60%는 손패가 반드시 차지할 고정 비율이 아니라, 모든
            // 상호작용 요소가 머물 수 있는 하한 경계다. 손패는 실제 카드 높이만
            // 쓰고, 남는 공간은 적·정보 영역에 준다. 긴 폰트가 손패를 키워도
            // 이 상한이 탭 대상을 화면 상단 40%로 밀어 올리지 않는다.
            final maxHandHeight = constraints.maxHeight * 0.6;

            return Stack(
              children: [
                Column(
                  children: [
                    _StatusBar(state: state, elapsed: _stopwatch.elapsed),
                    Expanded(
                      child: Column(
                        children: [
                          // §5.1 — 상단은 정보 영역이다. 다만 대상 지정 중일 때만
                          // 적이 탭을 받는다(§5.3).
                          Expanded(
                            child: _EnemyArea(
                              state: state,
                              events: session.lastEvents,
                              selectedCard: selectedCard,
                              onTapEnemy:
                                  selectedCard != null && selectedCard.targeted
                                  ? (index) => _play(index)
                                  : null,
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: maxHandHeight,
                            ),
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
                                          .read(
                                            combatControllerProvider.notifier,
                                          )
                                          .endTurn();
                                    },
                            ),
                          ),
                        ],
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
            );
          },
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
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _EnemyView(
                        enemy: state.enemies[i],
                        intentDamage: previewEnemyDamage(state, i),
                        incoming:
                            selectedCard == null || !selectedCard!.targeted
                            ? null
                            : previewDamage(
                                state,
                                selectedCard!,
                                targetIndex: i,
                              ),
                        targeting: onTapEnemy != null,
                        onTap: onTapEnemy == null ? null : () => onTapEnemy!(i),
                      ),
                    ),
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
    final intentText = intentLabel(enemy.intent, damage: intentDamage);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // §3.1 — 다음 행동은 항상 아이콘으로 미리 표시한다.
          // M0은 임시로 글자다.
          SizedBox(
            width: _enemyMeterWidth,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Text(
                key: ValueKey('enemy-intent-label-${enemy.id}'),
                intentText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
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
            width: _enemyMeterWidth,
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
        case EnergyGained():
          lines.add('기력 +${event.amount}');
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
      mainAxisSize: MainAxisSize.min,
      children: [
        _ResourceRow(state: state),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Fan(
            state: state,
            actionCount: actionCount,
            selected: selected,
            onTapCard: onTapCard,
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '덱 ${state.drawPile.length}   버림 ${state.discardPile.length}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.65),
              ),
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
  final _cardKeys = <int, GlobalKey>{};
  Map<int, Size> _cardSizes = {};
  bool _measurementScheduled = false;
  int? _previousSelected;

  @override
  void initState() {
    super.initState();
    _selectionController = AnimationController(
      vsync: this,
      duration: _selectionDuration,
      value: widget.selected == null ? 0 : 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureCards());
  }

  @override
  void didUpdateWidget(covariant _Fan oldWidget) {
    super.didUpdateWidget(oldWidget);

    _scheduleMeasurement();

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
    final textScaler = MediaQuery.textScalerOf(context);
    final emptyHandHeight = _cardReservedMinimumHeight(textScaler, 0);
    if (hand.isEmpty) {
      return SizedBox(
        height: emptyHandHeight,
        child: Center(
          child: Text(
            '손패 없음',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ),
      );
    }

    final sizes = [
      for (var i = 0; i < hand.length; i++)
        _cardSizes[i] ??
            Size(
              _cardWidth,
              _cardReservedMinimumHeightFor(widget.state, hand[i], textScaler),
            ),
    ];

    return AnimatedBuilder(
      animation: _selectionController,
      builder: (context, child) {
        final layout = _HandFanLayout.fromSizes(
          sizes: sizes,
          selected: widget.selected,
          previousSelected: _previousSelected,
          selectionProgress: _selectionController.value,
        );
        return SizedBox(height: layout.requiredHeight, child: child);
      },
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (notification) {
          _scheduleMeasurement();
          return true;
        },
        child: Flow(
          key: const ValueKey('hand-fan'),
          delegate: _HandFanDelegate(
            cardCount: hand.length,
            selected: widget.selected,
            previousSelected: _previousSelected,
            selectionProgress: _selectionController,
          ),
          children: [
            for (var i = 0; i < hand.length; i++)
              SizeChangedLayoutNotifier(
                key: _cardKeys.putIfAbsent(i, GlobalKey.new),
                child: GestureDetector(
                  key: ValueKey('hand-card-$i'),
                  onTap: widget.state.isOver ? null : () => widget.onTapCard(i),
                  child: _CardView(
                    card: hand[i],
                    state: widget.state,
                    width: _cardWidth,
                    selected: widget.selected == i,
                    playable:
                        widget.state.energy >= hand[i].cost &&
                        !widget.state.isOver,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _scheduleMeasurement() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      _measureCards();
    });
  }

  void _measureCards() {
    if (!mounted) return;

    final nextSizes = <int, Size>{
      for (var i = 0; i < widget.state.hand.length; i++)
        if (_cardKeys[i]?.currentContext?.size case final Size size) i: size,
    };
    if (nextSizes.isEmpty || _sameCardSizes(nextSizes)) return;

    setState(() => _cardSizes = nextSizes);
  }

  bool _sameCardSizes(Map<int, Size> nextSizes) {
    if (_cardSizes.length != nextSizes.length) return false;
    return nextSizes.entries.every(
      (entry) => _cardSizes[entry.key] == entry.value,
    );
  }
}

/// 손패 높이와 Flow 배치가 함께 사용하는 카드별 기하값.
///
/// 선택 전환 중에도 폭 예약을 고정하고, 높이 계산과 실제 변환이 같은 투영값을
/// 소비하게 한다. 둘이 달라지면 Flow의 클리핑 경계가 카드를 자를 수 있다.
class _HandFanLayout {
  const _HandFanLayout._({
    required this.cards,
    required this.requiredHeight,
    required this._widestReservedCard,
    required this._maxStableSpread,
  });

  static const _edgeInset = 8.0;
  static const _cardGap = 2.0;
  static const _rotationPerOffset = 0.075;
  static const _selectedScale = 1.12;
  static const _selectedLift = 34.0;

  final List<_HandFanCardGeometry> cards;
  final double requiredHeight;
  final double _widestReservedCard;
  final double _maxStableSpread;

  factory _HandFanLayout.fromSizes({
    required List<Size> sizes,
    required int? selected,
    required int? previousSelected,
    required double selectionProgress,
  }) {
    final cards = [
      for (var i = 0; i < sizes.length; i++)
        _HandFanCardGeometry.fromSize(
          size: sizes[i],
          offset: i - (sizes.length - 1) / 2,
          selected: selected == i,
          previouslySelected: previousSelected == i,
          selectionProgress: selectionProgress,
        ),
    ];
    final requiredHeight = cards.fold(
      _edgeInset,
      (height, card) => math.max(height, card.topExtent + _edgeInset),
    );
    final widestReservedCard = cards.fold(
      0.0,
      (widest, card) => math.max(widest, card.reservedWidth),
    );
    // 모든 카드의 최대 확대 폭을 예약해야 선택 전환 중 두 카드가 동시에
    // 확대되어도 간격과 양끝 여백이 흔들리지 않는다.
    final maxStableSpread = cards.fold(
      0.0,
      (widest, card) => math.max(widest, card.baseProjectedWidth + _cardGap),
    );

    return _HandFanLayout._(
      cards: cards,
      requiredHeight: requiredHeight,
      widestReservedCard: widestReservedCard,
      maxStableSpread: maxStableSpread,
    );
  }

  List<_HandFanCardPlacement> placeIn(Size fanSize) {
    final spread = cards.length == 1
        ? 0.0
        : math.min(
            _maxStableSpread,
            math.max(
              0.0,
              (fanSize.width - _widestReservedCard - _edgeInset * 2) /
                  (cards.length - 1),
            ),
          );

    return [
      for (final card in cards)
        _HandFanCardPlacement(
          geometry: card,
          left: (fanSize.width - card.size.width) / 2 + card.offset * spread,
          top:
              fanSize.height -
              _edgeInset -
              (card.size.height + card.projectedHeight) / 2 -
              card.selectedLift,
        ),
    ];
  }
}

class _HandFanCardGeometry {
  const _HandFanCardGeometry._({
    required this.size,
    required this.offset,
    required this.angle,
    required this.scale,
    required this.baseProjectedWidth,
    required this.projectedHeight,
    required this.selectedLift,
  });

  final Size size;
  final double offset;
  final double angle;
  final double scale;
  final double baseProjectedWidth;
  final double projectedHeight;
  final double selectedLift;

  factory _HandFanCardGeometry.fromSize({
    required Size size,
    required double offset,
    required bool selected,
    required bool previouslySelected,
    required double selectionProgress,
  }) {
    final baseAngle = offset * _HandFanLayout._rotationPerOffset;
    final angle = selected ? 0.0 : baseAngle;
    final scale = selected
        ? 1 + (_HandFanLayout._selectedScale - 1) * selectionProgress
        : previouslySelected
        ? _HandFanLayout._selectedScale -
              (_HandFanLayout._selectedScale - 1) * selectionProgress
        : 1.0;
    final baseProjectedWidth =
        size.width * math.cos(baseAngle.abs()) +
        size.height * math.sin(baseAngle.abs());
    final projectedHeight =
        scale *
        (size.height * math.cos(angle.abs()) +
            size.width * math.sin(angle.abs()));

    return _HandFanCardGeometry._(
      size: size,
      offset: offset,
      angle: angle,
      scale: scale,
      baseProjectedWidth: baseProjectedWidth,
      projectedHeight: projectedHeight,
      selectedLift: selected ? _HandFanLayout._selectedLift : 0.0,
    );
  }

  double get reservedWidth =>
      _HandFanLayout._selectedScale * math.max(baseProjectedWidth, size.width);

  double get topExtent => projectedHeight + selectedLift;
}

class _HandFanCardPlacement {
  const _HandFanCardPlacement({
    required this.geometry,
    required this.left,
    required this.top,
  });

  final _HandFanCardGeometry geometry;
  final double left;
  final double top;
}

/// 손패를 그릴 순서다.
///
/// Flow는 뒤에 그린 자식이 앞에 오므로, 선택 카드는 항상 마지막에 둔다.
/// 선택 전환 중에는 직전 선택도 일반 카드보다 앞에 두되, 새 선택 카드가
/// 최상단을 유지한다. 축소가 끝난 직전 선택은 원래 인덱스 순서로 돌려 놓는다.
List<int> handFanPaintOrder({
  required int cardCount,
  required int? selected,
  required int? previousSelected,
  required double selectionProgress,
}) {
  final order = List.generate(cardCount, (index) => index);
  final activeSelected = selected != null && selected < cardCount
      ? selected
      : null;
  final activePrevious =
      selectionProgress < 1 &&
          previousSelected != null &&
          previousSelected < cardCount &&
          previousSelected != activeSelected
      ? previousSelected
      : null;

  order.remove(activePrevious);
  order.remove(activeSelected);
  if (activePrevious != null) order.add(activePrevious);
  if (activeSelected != null) order.add(activeSelected);
  return order;
}

class _HandFanDelegate extends FlowDelegate {
  _HandFanDelegate({
    required this.cardCount,
    required this.selected,
    required this.previousSelected,
    required Animation<double> selectionProgress,
  }) : _selectionProgress = selectionProgress,
       super(repaint: selectionProgress);

  final int cardCount;
  final int? selected;
  final int? previousSelected;
  final Animation<double> _selectionProgress;

  @override
  BoxConstraints getConstraintsForChild(int index, BoxConstraints constraints) {
    // 팬의 높이는 자식이 실제로 필요로 한 높이로 다음 프레임에 다시 잡는다.
    // 여기서 Flow의 임시 높이를 자식의 최대 높이로 넘기면 긴 글자가 측정되기
    // 전에 잘려 카드 내부 Column이 오버플로한다.
    return BoxConstraints(maxWidth: constraints.maxWidth);
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final sizes = [
      for (var i = 0; i < cardCount; i++) context.getChildSize(i)!,
    ];
    final layout = _HandFanLayout.fromSizes(
      sizes: sizes,
      selected: selected,
      previousSelected: previousSelected,
      selectionProgress: _selectionProgress.value,
    );
    final placements = layout.placeIn(context.size);

    for (final i in handFanPaintOrder(
      cardCount: cardCount,
      selected: selected,
      previousSelected: previousSelected,
      selectionProgress: _selectionProgress.value,
    )) {
      final placement = placements[i];
      final card = placement.geometry;

      context.paintChild(
        i,
        transform: Matrix4.identity()
          ..translateByDouble(
            placement.left + card.size.width / 2,
            placement.top + card.size.height / 2,
            0,
            1,
          )
          ..rotateZ(card.angle)
          ..scaleByDouble(card.scale, card.scale, 1, 1)
          ..translateByDouble(
            -card.size.width / 2,
            -card.size.height / 2,
            0,
            1,
          ),
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

    // 피해·방어는 엔진이 준 것만 쓰고, 나머지는 카드 정의의 고정 효과만 읽는다.
    // 화면에서 상태 규칙을 다시 계산하면 카드에 적힌 값과 실제 결과가 갈라진다.
    final damage = previewDamage(state, card);
    final block = previewBlock(state, card);
    final effects = cardEffectLabels(card, damage: damage, block: block);
    final handLabel = handCardLabel(card);
    final effectLines = [
      effects.take(2).join(' · '),
      if (effects.length > 2) effects.skip(2).join(' · '),
    ];
    final textScaler = MediaQuery.textScalerOf(context);
    final costDiameter = textScaler.scale(20);

    return Opacity(
      opacity: playable ? 1 : 0.45,
      child: Container(
        width: width,
        constraints: BoxConstraints(
          // 큰 글꼴의 두 번째 효과 줄도 첫 Flow 측정부터 예약한다. 이 값은
          // 최소 높이일 뿐 상한이 아니므로 내용이 더 길면 카드가 계속 커진다.
          minHeight: _cardReservedMinimumHeight(textScaler, effects.length),
        ),
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
                  key: ValueKey('card-cost-${card.id}'),
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
              ],
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: ValueKey('card-hand-label-${card.id}'),
                  handLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    card.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < effectLines.length; index++)
              Text(
                key: ValueKey('card-effect-line-$index'),
                effectLines[index],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accent.withValues(alpha: 0.9),
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
