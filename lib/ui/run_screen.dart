/// M1 런 화면 — 지도, 전투 연결, 카드 보상.
///
/// 지도는 domain이 만든 경로와 legalRunActions 결과만 표시한다. 노드의 전투,
/// 보상, 이동 규칙을 이 레이어에서 다시 계산하지 않는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/combat_controller.dart';
import '../app/run_controller.dart';
import '../domain/combat/combat_engine.dart';
import '../domain/model/card.dart';
import '../domain/model/relic.dart';
import '../domain/run/run_action.dart';
import '../domain/run/run_engine.dart';
import '../domain/run/run_event.dart';
import '../domain/run/judgment_preview.dart';
import '../domain/run/run_map.dart';
import '../domain/run/run_node_type.dart';
import '../domain/run/run_tuning.dart';
import '../domain/run/wild_camp_preview.dart';
import 'combat_screen.dart';
import 'labels.dart';
import 'relic_inventory.dart';

const _mapNodeDiameter = 56.0;
const _mapRowExtent = 96.0;
const _mapVerticalInset = 24.0;
const _mapHorizontalInset = 36.0;

/// 런 진행도에 맞는 화면을 고른다. 화면 전환 자체는 저장할 상태가 아니며,
/// 항상 domain의 재생 결과에서 다시 정해진다.
class RunScreen extends ConsumerWidget {
  const RunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(runControllerProvider);
    final controller = ref.read(runControllerProvider.notifier);
    final progress = session.progress;

    if (progress.isOver) {
      return _RunEndedScreen(
        outcome: progress.outcome!,
        victoryRelics: progress.victoryRelics,
        onRestart: controller.restart,
      );
    }
    if (progress.pendingCardReward != null) {
      return _RewardScreen(session: session, onChoose: controller.dispatch);
    }
    if (progress.pendingRelicReward != null) {
      return _RelicRewardScreen(
        session: session,
        onChoose: controller.dispatch,
      );
    }
    if (progress.pendingShop != null) {
      return _ShopScreen(session: session, onChoose: controller.dispatch);
    }
    if (progress.pendingWildCamp != null) {
      return _WildCampScreen(session: session, onChoose: controller.dispatch);
    }
    if (progress.pendingEvent != null) {
      return _EventScreen(session: session, onChoose: controller.dispatch);
    }
    if (progress.isInCombat) return const _RunCombatHost();

    return RunMapScreen(session: session, onMove: controller.dispatch);
  }
}

/// 검수된 M0 전투 레이아웃을 고치지 않고 런 전투만 주입하는 경계다.
class _RunCombatHost extends StatelessWidget {
  const _RunCombatHost();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        combatControllerProvider.overrideWith(RunCombatController.new),
      ],
      child: const CombatScreen(),
    );
  }
}

/// 세로 스크롤 지도.
class RunMapScreen extends StatefulWidget {
  const RunMapScreen({super.key, required this.session, required this.onMove});

  final RunSession session;
  final ValueChanged<MoveToNode> onMove;

  @override
  State<RunMapScreen> createState() => _RunMapScreenState();
}

class _RunMapScreenState extends State<RunMapScreen> {
  final _scrollController = ScrollController();
  int? _revealedNodeId;

  @override
  void initState() {
    super.initState();
    _revealCurrentNode();
  }

  @override
  void didUpdateWidget(covariant RunMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.progress.currentNodeId !=
        widget.session.progress.currentNodeId) {
      _revealCurrentNode();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _revealCurrentNode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final map = widget.session.progress.map;
      final nodeId =
          widget.session.progress.currentNodeId ?? map.nodes.first.id;
      if (_revealedNodeId == nodeId) return;
      _revealedNodeId = nodeId;

      final node = map.nodeById(nodeId);
      final target =
          _nodeCenterY(node.depth) -
          _scrollController.position.viewportDimension / 2;
      _scrollController.jumpTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.session.progress;
    final legalMovesByNode = {
      for (final action in widget.session.legalActions.whereType<MoveToNode>())
        action.nodeId: action,
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '저승길',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text('체력 ${progress.hp}/${progress.maxHp}'),
                  const SizedBox(width: 12),
                  Text('노잣돈 ${progress.money}'),
                  RelicInventoryButton(
                    key: const ValueKey('map-relic-inventory'),
                    relics: progress.relics,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _MapLegend(),
            ),
            if (progress.judgmentPreview case final preview?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _JudgmentNotice(preview: preview),
              ),
            const SizedBox(height: 8),
            Expanded(
              // §5.1의 하단 60%는 한 전투에서 엄지로 조작할 카드·버튼을
              // 모으는 원칙이다. 지도는 현재 위치와 이어진 길을 함께 읽는
              // 탐색 화면이므로, 56dp 노드를 세로 스크롤 전체에 두고 현재
              // 위치로 자동 이동시키는 쪽이 그 목적(한눈의 경로 판단)을 지킨다.
              child: SingleChildScrollView(
                key: const ValueKey('run-map-scroll'),
                controller: _scrollController,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final geometry = _MapGeometry(
                      map: progress.map,
                      width: constraints.maxWidth,
                    );
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: geometry.height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _MapEdgesPainter(
                                  map: progress.map,
                                  geometry: geometry,
                                ),
                              ),
                            ),
                          ),
                          for (final node in progress.map.nodes)
                            Positioned(
                              left:
                                  geometry.centers[node.id]!.dx -
                                  _mapNodeDiameter / 2,
                              top:
                                  geometry.centers[node.id]!.dy -
                                  _mapNodeDiameter / 2,
                              child: _MapNodeButton(
                                node: node,
                                selected: node.id == progress.currentNodeId,
                                onTap: legalMovesByNode[node.id] == null
                                    ? null
                                    : () => widget.onMove(
                                        legalMovesByNode[node.id]!,
                                      ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final type in RunNodeType.values)
          _LegendItem(symbol: _nodeSymbol(type), label: _nodeName(type)),
      ],
    );
  }
}

/// 심판 문구는 [JudgmentPreview]가 만들고, 화면은 전투 전 지도에서 읽기 쉬운
/// 위치에 놓기만 한다. UI가 업 구간을 다시 해석하지 않는다.
class _JudgmentNotice extends StatelessWidget {
  const _JudgmentNotice({required this.preview});

  final JudgmentPreview preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('judgment-preview'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1D29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC9A227)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text('${preview.bandLabel} · ${preview.effectLabel}'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.symbol, required this.label});

  final String symbol;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF332B31),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(child: Text(symbol)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _MapNodeButton extends StatelessWidget {
  const _MapNodeButton({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final RunNode node;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? _nodeColor(node.type) : const Color(0xFF4A4147);
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: '${_nodeName(node.type)} ${node.depth + 1}번째 길목',
      child: SizedBox(
        key: ValueKey('run-node-${node.id}'),
        width: _mapNodeDiameter,
        height: _mapNodeDiameter,
        child: Material(
          color: selected ? const Color(0xFFC9A227) : color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              // 기호는 56dp 터치 원 안에서 폰트 배율 1.3에도 충분히 남는다.
              // FittedBox로 글자를 축소하지 않는다 (§5.4).
              child: Text(
                _nodeSymbol(node.type),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapGeometry {
  _MapGeometry({required RunMap map, required this.width})
    : height = _mapContentHeight(map),
      centers = _centersFor(map, width);

  final double width;
  final double height;
  final Map<int, Offset> centers;
}

Map<int, Offset> _centersFor(RunMap map, double width) {
  final centers = <int, Offset>{};
  final nodesByDepth = <int, List<RunNode>>{};
  for (final node in map.nodes) {
    (nodesByDepth[node.depth] ??= []).add(node);
  }
  final columnCount = nodesByDepth.values.fold(
    0,
    (maximum, nodes) => nodes.length > maximum ? nodes.length : maximum,
  );

  for (final entry in nodesByDepth.entries) {
    final nodes = entry.value
      ..sort((left, right) => left.id.compareTo(right.id));
    final rowStartSlot = (columnCount - nodes.length) / 2;
    for (var slot = 0; slot < nodes.length; slot++) {
      centers[nodes[slot].id] = Offset(
        _nodeCenterX(width, rowStartSlot + slot, columnCount),
        _nodeCenterY(entry.key),
      );
    }
  }
  return centers;
}

double _nodeCenterX(double width, double slot, int columnCount) {
  if (columnCount == 1) return width / 2;
  final availableWidth = width - _mapHorizontalInset * 2;
  return _mapHorizontalInset + availableWidth * slot / (columnCount - 1);
}

double _nodeCenterY(int depth) =>
    _mapVerticalInset + _mapNodeDiameter / 2 + depth * _mapRowExtent;

double _mapContentHeight(RunMap map) {
  final lastDepth = map.nodes
      .map((node) => node.depth)
      .reduce((current, depth) => current > depth ? current : depth);
  return _nodeCenterY(lastDepth) + _mapNodeDiameter / 2 + _mapVerticalInset;
}

class _MapEdgesPainter extends CustomPainter {
  const _MapEdgesPainter({required this.map, required this.geometry});

  final RunMap map;
  final _MapGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF75666D)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final node in map.nodes) {
      final start = geometry.centers[node.id]!;
      for (final nextNodeId in node.nextNodeIds) {
        // domain의 인접 슬롯·비교차 간선만 그대로 잇는다. UI가 간선을
        // 새로 만들지 않으므로 좁은 세로 화면에서도 같은 경로를 읽는다.
        canvas.drawLine(start, geometry.centers[nextNodeId]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapEdgesPainter oldDelegate) =>
      oldDelegate.map != map || oldDelegate.geometry.width != geometry.width;
}

class _RewardScreen extends StatelessWidget {
  const _RewardScreen({required this.session, required this.onChoose});

  final RunSession session;
  final ValueChanged<ChooseCardReward> onChoose;

  @override
  Widget build(BuildContext context) {
    final reward = session.progress.pendingCardReward!;
    final choicesByCardId = {
      for (final action in session.legalActions.whereType<ChooseCardReward>())
        action.cardId: action,
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                '전투 승리',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('노잣돈 ${session.progress.money}'),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('카드 하나를 고르세요'),
                  SizedBox(height: 4),
                  Text(
                    '피해·방어는 상태와 업 보정 전 기본 수치입니다',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: reward.cards.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final card = reward.cards[index];
                  final choice = choicesByCardId[card.id];
                  return _RewardCardButton(
                    card: card,
                    onChoose: choice == null ? null : () => onChoose(choice),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelicRewardScreen extends StatelessWidget {
  const _RelicRewardScreen({required this.session, required this.onChoose});

  final RunSession session;
  final ValueChanged<ChooseRelicReward> onChoose;

  @override
  Widget build(BuildContext context) {
    final reward = session.progress.pendingRelicReward!;
    final choicesByRelicId = {
      for (final action in session.legalActions.whereType<ChooseRelicReward>())
        action.relicId: action,
    };

    return _NodeChoiceScaffold(
      screenKey: const ValueKey('relic-reward-screen'),
      title: '정예 전리품',
      status: '현재 업 ${session.progress.karma} · 노잣돈 ${session.progress.money}',
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: reward.relics.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('유물 하나를 고르세요'),
                const SizedBox(height: 4),
                Text(
                  key: const ValueKey('relic-reward-karma'),
                  '정예 승리 보상 · 업 +${reward.karmaGained}',
                ),
              ],
            );
          }

          final relic = reward.relics[index - 1];
          final choice = choicesByRelicId[relic.id];
          return FilledButton(
            key: ValueKey('reward-relic-${relic.id}'),
            onPressed: choice == null ? null : () => onChoose(choice),
            style: FilledButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.all(16),
            ),
            child: RelicSummary(relic: relic),
          );
        },
      ),
    );
  }
}

class _RewardCardButton extends StatelessWidget {
  const _RewardCardButton({required this.card, required this.onChoose});

  final CardDef card;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    // 보상에는 진행 중인 전투 상태가 없다. 기본 피해·방어 합산은 엔진에
    // 맡기고, 화면은 그 결과와 공용 효과 표기만 배치한다.
    final effects = cardEffectLabels(
      card,
      damage: previewBaseDamage(card),
      block: previewBaseBlock(card),
    );
    final effectLines = [
      effects.take(2).join(' · '),
      if (effects.length > 2) effects.skip(2).join(' · '),
    ];

    return FilledButton(
      key: ValueKey('reward-card-${card.id}'),
      onPressed: onChoose,
      style: FilledButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(72),
        padding: const EdgeInsets.all(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_cardTypeName(card.type)} · 비용 ${card.cost}'),
          if (effectLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var index = 0; index < effectLines.length; index++)
              Text(
                key: ValueKey('reward-card-effect-${card.id}-$index'),
                effectLines[index],
              ),
          ],
        ],
      ),
    );
  }
}

class _ShopScreen extends StatelessWidget {
  const _ShopScreen({required this.session, required this.onChoose});

  final RunSession session;
  final ValueChanged<RunAction> onChoose;

  @override
  Widget build(BuildContext context) {
    final progress = session.progress;
    final shop = progress.pendingShop!;
    final purchasesByCardId = {
      for (final action in session.legalActions.whereType<BuyShopCard>())
        action.cardId: action,
    };
    final removalsByCardInstanceId = {
      for (final action in session.legalActions.whereType<RemoveShopCard>())
        action.cardInstanceId: action,
    };
    final leave = session.legalActions.whereType<LeaveShop>().single;

    return _NodeChoiceScaffold(
      screenKey: const ValueKey('shop-screen'),
      title: '저승 상점',
      status: '노잣돈 ${progress.money}',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text('상품을 고르세요'),
          const SizedBox(height: 8),
          for (final card in shop.cards) ...[
            _ShopCardButton(
              card: card,
              price: RunTuning.m1.shopCardPrice,
              onPurchase: purchasesByCardId[card.id] == null
                  ? null
                  : () => onChoose(purchasesByCardId[card.id]!),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          const Text(
            '카드 제거',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('비용 ${RunTuning.m1.shopRemoveCardPrice} 노잣돈'),
          const SizedBox(height: 8),
          for (var index = 0; index < progress.deckCards.length; index++) ...[
            _ShopRemoveCardButton(
              deckCard: progress.deckCards[index],
              deckPosition: index + 1,
              onRemove:
                  removalsByCardInstanceId[progress
                          .deckCards[index]
                          .instanceId] ==
                      null
                  ? null
                  : () => onChoose(
                      removalsByCardInstanceId[progress
                          .deckCards[index]
                          .instanceId]!,
                    ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            key: const ValueKey('shop-leave'),
            onPressed: () => onChoose(leave),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('상점 나가기'),
          ),
        ],
      ),
    );
  }
}

class _ShopCardButton extends StatelessWidget {
  const _ShopCardButton({
    required this.card,
    required this.price,
    required this.onPurchase,
  });

  final CardDef card;
  final int price;
  final VoidCallback? onPurchase;

  @override
  Widget build(BuildContext context) {
    final effectLines = _cardEffectLines(card);
    return FilledButton(
      key: ValueKey('shop-card-${card.id}'),
      onPressed: onPurchase,
      style: FilledButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(72),
        padding: const EdgeInsets.all(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_cardTypeName(card.type)} · 비용 ${card.cost}'),
          const SizedBox(height: 8),
          for (var index = 0; index < effectLines.length; index++)
            Text(
              key: ValueKey('shop-card-effect-${card.id}-$index'),
              effectLines[index],
            ),
          const SizedBox(height: 8),
          Text('구매 $price 노잣돈'),
          if (onPurchase == null) const Text('구매할 수 없음'),
        ],
      ),
    );
  }
}

class _ShopRemoveCardButton extends StatelessWidget {
  const _ShopRemoveCardButton({
    required this.deckCard,
    required this.deckPosition,
    required this.onRemove,
  });

  final RunDeckCard deckCard;
  final int deckPosition;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: ValueKey('shop-remove-${deckCard.instanceId}'),
      onPressed: onRemove,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.all(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${deckCard.card.name} · 덱 $deckPosition번',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${_cardTypeName(deckCard.card.type)} · 비용 ${deckCard.card.cost}',
          ),
          if (onRemove == null) const Text('제거할 수 없음'),
        ],
      ),
    );
  }
}

class _WildCampScreen extends StatelessWidget {
  const _WildCampScreen({required this.session, required this.onChoose});

  final RunSession session;
  final ValueChanged<RunAction> onChoose;

  @override
  Widget build(BuildContext context) {
    final progress = session.progress;
    final wildCamp = progress.pendingWildCamp!;
    final optionsByChoice = {
      for (final action
          in session.legalActions.whereType<ChooseWildCampOption>())
        action.choice: action,
    };
    final enhancementsByCardInstanceId = {
      for (final action
          in session.legalActions.whereType<EnhanceWildCampCard>())
        action.cardInstanceId: action,
    };

    if (wildCamp.isChoosingEnhancement) {
      return _NodeChoiceScaffold(
        screenKey: const ValueKey('wild-camp-enhance-screen'),
        title: wildCampEnhancementTitle,
        status: wildCampEnhancementStatus,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(wildCampEnhancementPrompt),
            const SizedBox(height: 12),
            for (final deckCard in progress.deckCards)
              if (enhancementsByCardInstanceId[deckCard.instanceId]
                  case final action?) ...[
                _WildCampEnhanceCardButton(
                  deckCard: deckCard,
                  action: action,
                  onChoose: onChoose,
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      );
    }

    return _NodeChoiceScaffold(
      screenKey: const ValueKey('wild-camp-screen'),
      title: '야장',
      status:
          '체력 ${progress.hp}/${progress.maxHp} · 업 ${progress.karma} · 노잣돈 ${progress.money}',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text(wildCampChoicePrompt),
          const SizedBox(height: 12),
          _WildCampOptionButton(
            choice: WildCampChoice.rest,
            title: wildCampOptionPreview(WildCampChoice.rest).title,
            detail: wildCampOptionPreview(WildCampChoice.rest).detail,
            action: optionsByChoice[WildCampChoice.rest],
            onChoose: onChoose,
          ),
          const SizedBox(height: 12),
          _WildCampOptionButton(
            choice: WildCampChoice.repent,
            title: wildCampOptionPreview(WildCampChoice.repent).title,
            detail: wildCampOptionPreview(WildCampChoice.repent).detail,
            action: optionsByChoice[WildCampChoice.repent],
            onChoose: onChoose,
          ),
          const SizedBox(height: 12),
          _WildCampOptionButton(
            choice: WildCampChoice.enhance,
            title: wildCampOptionPreview(WildCampChoice.enhance).title,
            detail: wildCampOptionPreview(WildCampChoice.enhance).detail,
            action: optionsByChoice[WildCampChoice.enhance],
            onChoose: onChoose,
          ),
        ],
      ),
    );
  }
}

class _WildCampEnhanceCardButton extends StatelessWidget {
  const _WildCampEnhanceCardButton({
    required this.deckCard,
    required this.action,
    required this.onChoose,
  });

  final RunDeckCard deckCard;
  final EnhanceWildCampCard action;
  final ValueChanged<RunAction> onChoose;

  @override
  Widget build(BuildContext context) {
    final effectLines = _cardEffectLines(deckCard.card);
    return OutlinedButton(
      key: ValueKey('wild-camp-enhance-${deckCard.instanceId}'),
      onPressed: () => onChoose(action),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.all(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deckCard.card.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${_cardTypeName(deckCard.card.type)} · 비용 ${deckCard.card.cost}',
          ),
          for (final line in effectLines) Text(line),
        ],
      ),
    );
  }
}

class _WildCampOptionButton extends StatelessWidget {
  const _WildCampOptionButton({
    required this.choice,
    required this.title,
    required this.detail,
    required this.action,
    required this.onChoose,
  });

  final WildCampChoice choice;
  final String title;
  final String detail;
  final ChooseWildCampOption? action;
  final ValueChanged<RunAction> onChoose;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: ValueKey('wild-camp-${choice.name}'),
      onPressed: action == null ? null : () => onChoose(action!),
      style: FilledButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(64),
        padding: const EdgeInsets.all(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(detail),
          if (action == null) const Text('선택할 수 없음'),
        ],
      ),
    );
  }
}

class _EventScreen extends StatelessWidget {
  const _EventScreen({required this.session, required this.onChoose});

  final RunSession session;
  final ValueChanged<RunAction> onChoose;

  @override
  Widget build(BuildContext context) {
    final pendingEvent = session.progress.pendingEvent!;
    final optionsById = {
      for (final action in session.legalActions.whereType<ChooseEventOption>())
        action.choiceId: action,
    };
    final previewsByChoiceId = {
      for (final preview in pendingEvent.choicePreviews)
        preview.choiceId: preview,
    };

    return _NodeChoiceScaffold(
      screenKey: const ValueKey('event-screen'),
      title: pendingEvent.event.name,
      status: '사건 선택',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text('선택지가 기록을 바꿉니다'),
          const SizedBox(height: 12),
          // 사건의 보이지 않는 선택지는 현재 업 구간에서 애초에 성립하지 않는
          // 서사다. 상점처럼 공개된 상품을 흐리게 보이는 것과 달리, 이를
          // 노출하면 도메인이 감춘 업 구간 정보를 UI가 새로 알려 주게 된다.
          for (final choice in pendingEvent.event.choices)
            if (optionsById[choice.id] case final action?) ...[
              _EventChoiceButton(
                choice: choice,
                preview: previewsByChoiceId[choice.id]!,
                action: action,
                onChoose: onChoose,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _EventChoiceButton extends StatelessWidget {
  const _EventChoiceButton({
    required this.choice,
    required this.preview,
    required this.action,
    required this.onChoose,
  });

  final RunEventChoice choice;
  final RunEventChoicePreview preview;
  final ChooseEventOption action;
  final ValueChanged<RunAction> onChoose;

  @override
  Widget build(BuildContext context) {
    final gainedCard = preview.gainedCard;
    final cardEffects = gainedCard == null
        ? const <String>[]
        : _cardEffectLines(gainedCard);

    return FilledButton(
      key: ValueKey('event-choice-${choice.id}'),
      onPressed: () => onChoose(action),
      style: FilledButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(64),
        padding: const EdgeInsets.all(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            choice.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(preview.outcomeLabels.join(' · ')),
          if (gainedCard != null) ...[
            const SizedBox(height: 4),
            Text(preview.gainedCardLabel!),
            for (final effect in cardEffects) Text(effect),
          ],
        ],
      ),
    );
  }
}

class _NodeChoiceScaffold extends StatelessWidget {
  const _NodeChoiceScaffold({
    required this.screenKey,
    required this.title,
    required this.status,
    required this.child,
  });

  final Key screenKey;
  final String title;
  final String status;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(status),
            ),
            const SizedBox(height: 20),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

List<String> _cardEffectLines(CardDef card) {
  // 상점은 보상과 마찬가지로 진행 중인 전투 상태가 없다. 그래서 엔진이 정한
  // 상태·업 보정 전 기본 수치만 쓰고, UI에서 피해·방어 규칙을 다시 계산하지 않는다.
  final effects = cardEffectLabels(
    card,
    damage: previewBaseDamage(card),
    block: previewBaseBlock(card),
  );
  return [
    effects.take(2).join(' · '),
    if (effects.length > 2) effects.skip(2).join(' · '),
  ].where((line) => line.isNotEmpty).toList();
}

class _RunEndedScreen extends StatelessWidget {
  const _RunEndedScreen({
    required this.outcome,
    required this.victoryRelics,
    required this.onRestart,
  });

  final RunOutcome outcome;
  final List<RelicDef> victoryRelics;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: ValueKey('run-ended-${outcome.name}'),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  runOutcomeTitle(outcome),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(runOutcomeMessage(outcome), textAlign: TextAlign.center),
                if (outcome == RunOutcome.victory &&
                    victoryRelics.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    key: const ValueKey('victory-relics'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF332B31),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '심판의 유물',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        for (
                          var index = 0;
                          index < victoryRelics.length;
                          index++
                        ) ...[
                          const SizedBox(height: 12),
                          RelicSummary(
                            key: ValueKey(
                              'victory-relic-${victoryRelics[index].id}',
                            ),
                            relic: victoryRelics[index],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRestart,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('새 런 시작'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _nodeSymbol(RunNodeType type) => switch (type) {
  RunNodeType.combat => '전',
  RunNodeType.elite => '정',
  RunNodeType.shop => '상',
  RunNodeType.wildCamp => '야',
  RunNodeType.event => '사',
  RunNodeType.boss => '왕',
};

String _nodeName(RunNodeType type) => switch (type) {
  RunNodeType.combat => '전투',
  RunNodeType.elite => '정예',
  RunNodeType.shop => '상점',
  RunNodeType.wildCamp => '야장',
  RunNodeType.event => '사건',
  RunNodeType.boss => '보스',
};

Color _nodeColor(RunNodeType type) => switch (type) {
  RunNodeType.combat => const Color(0xFF8B3131),
  RunNodeType.elite => const Color(0xFF7B5A20),
  RunNodeType.shop => const Color(0xFF3D6A6D),
  RunNodeType.wildCamp => const Color(0xFF496741),
  RunNodeType.event => const Color(0xFF5B4F79),
  RunNodeType.boss => const Color(0xFF6B253A),
};

String _cardTypeName(CardType type) => switch (type) {
  CardType.attack => '공격',
  CardType.skill => '기술',
  CardType.power => '지속',
  CardType.curse => '저주',
  CardType.status => '상태',
};
