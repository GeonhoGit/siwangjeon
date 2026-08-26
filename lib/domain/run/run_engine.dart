/// 런 진행과 전투 노드 재생 규칙 (기획서 §2.1, §2.3, §7.4).
library;

import '../combat/combat_engine.dart';
import '../model/card.dart';
import '../model/combat_action.dart';
import '../model/combat_state.dart';
import '../model/enemy.dart';
import '../rng/rng.dart';
import 'run_action.dart';
import 'run_content.dart';
import 'run_map.dart';
import 'run_tuning.dart';
import 'run_state.dart';

/// 액션 로그에 현재 런에서 성립하지 않는 입력이 들어왔을 때 던진다.
///
/// UI와 저장 계층은 [legalRunActions]가 돌려준 값만 기록해야 한다. 불법 입력을
/// 조용히 무시하면 같은 로그를 재생할 때마다 어느 지점까지 믿을 수 있는지
/// 알 수 없어 §7.4의 복원 계약이 무너진다.
class IllegalRunActionError implements Exception {
  const IllegalRunActionError(this.message);

  final String message;

  @override
  String toString() => 'IllegalRunActionError: $message';
}

/// 런이 더 진행될 수 없는 결과. 전투 승리는 다음 노드로 이어지므로 여기에
/// 넣지 않는다.
enum RunOutcome { defeat }

/// 시드와 액션 로그에서 다시 만든 현재 런 진행 상태.
///
/// 이 값은 저장하지 않는다. [RunState]의 세 값과 버전 고정 [RunContent]를 매번
/// 재생해 만들므로, 체력·업·덱·적 구성·전투 결과가 저장 파일을 늘리지 않는다.
class RunProgress {
  RunProgress({
    required this.map,
    required List<int> visitedNodeIds,
    required this.hp,
    required this.maxHp,
    required this.karma,
    required List<CardDef> deck,
    this.combat,
    this.outcome,
  }) : visitedNodeIds = List.unmodifiable(visitedNodeIds),
       deck = List.unmodifiable(deck);

  final RunMap map;
  final List<int> visitedNodeIds;

  /// 런 전체에 이어지는 혼과 업. 전투 중에는 [combat]이 같은 값을 들고 있고,
  /// 전투가 끝나면 이 값으로 다시 접힌다.
  final int hp;
  final int maxHp;
  final int karma;

  /// 보상이 생기기 전에는 시작 덱이며, 이후 단계에서는 보상 액션을 재생한
  /// 결과가 이 자리에 들어온다.
  final List<CardDef> deck;

  /// 현재 전투 중이거나 패배로 끝난 전투 상태. 승리한 전투는 결과를 런 값으로
  /// 반영한 뒤 비워 다음 이동이 가능하게 한다.
  final CombatState? combat;

  final RunOutcome? outcome;

  int? get currentNodeId => visitedNodeIds.isEmpty ? null : visitedNodeIds.last;

  RunNode? get currentNode =>
      currentNodeId == null ? null : map.nodeById(currentNodeId!);

  bool get isOver => outcome != null;

  bool get isInCombat => combat != null && !combat!.isOver;
}

/// 새 런의 저장 가능한 뼈대를 만든다.
RunState startRun({required int seed, required String characterId}) {
  return RunState(seed: seed, characterId: characterId, actionLog: const []);
}

/// 현재 런 상태에서 규칙상 가능한 모든 입력.
///
/// 전투 중에는 전투 액션 하나를 덧붙인 [CombatNodeLog]만 돌려준다. 런 엔진은
/// 손패나 대상 규칙을 판단하지 않고, 그 후보를 [legalActions]에 위임한다.
List<RunAction> legalRunActions(
  RunState state, {
  RunTuning tuning = RunTuning.m1,
  RunContent? content,
}) {
  final progress = replayRun(state, tuning: tuning, content: content);
  if (progress.isOver) return const [];

  if (progress.isInCombat) {
    final nodeId = progress.currentNodeId!;
    final actions = _currentCombatActions(state, nodeId);
    return [
      for (final action in legalActions(progress.combat!))
        CombatNodeLog(nodeId: nodeId, actions: [...actions, action]),
    ];
  }

  return [
    for (final nodeId in _legalNextNodeIds(progress))
      MoveToNode(nodeId: nodeId),
  ];
}

/// 런 액션 하나를 기록한 다음 저장 가능한 상태를 돌려준다.
///
/// [CombatNodeLog]는 전투 노드마다 하나만 두는 하위 로그 스냅샷이다. 전투
/// 액션을 받을 때마다 그 마지막 항목을 교체하므로, 앱이 턴 끝마다 저장해도
/// 최신 로그 하나만 남고 중단 지점까지 정확히 재생된다.
RunState applyRunAction(
  RunState state,
  RunAction action, {
  RunTuning tuning = RunTuning.m1,
  RunContent? content,
}) {
  final legal = legalRunActions(state, tuning: tuning, content: content);
  if (!legal.any((candidate) => _sameRunAction(candidate, action))) {
    throw IllegalRunActionError('현재 런 상태에서 기록할 수 없는 액션이다');
  }

  final replaceLastCombatLog =
      action is CombatNodeLog &&
      state.actionLog.isNotEmpty &&
      state.actionLog.last is CombatNodeLog &&
      (state.actionLog.last as CombatNodeLog).nodeId == action.nodeId;
  final nextLog = replaceLastCombatLog
      ? [...state.actionLog.sublist(0, state.actionLog.length - 1), action]
      : [...state.actionLog, action];

  return RunState(
    seed: state.seed,
    characterId: state.characterId,
    actionLog: nextLog,
  );
}

/// 저장된 런 로그를 처음부터 적용해 현재 상태를 복원한다.
///
/// [content]는 저장 대상이 아닌, 이 앱 버전에 함께 배포된 카드·적 정의다.
/// 콘텐츠를 생략한 호출은 M1-1 호환의 지도 전용 재생이며 전투를 시작하지
/// 않는다. 실제 런은 반드시 콘텐츠를 주입해 전투 노드를 복원한다.
RunProgress replayRun(
  RunState state, {
  RunTuning tuning = RunTuning.m1,
  RunContent? content,
}) {
  final map = generateActOneMap(state.seed, tuning: tuning);
  final visitedNodeIds = <int>[];
  final deck = content?.deck ?? const <CardDef>[];
  var hp = content?.maxHp ?? 0;
  final maxHp = content?.maxHp ?? 0;
  var karma = content?.startingKarma ?? 0;
  CombatState? combat;
  RunOutcome? outcome;
  final combatLogNodeIds = <int>{};

  for (final action in state.actionLog) {
    switch (action) {
      case MoveToNode(:final nodeId):
        if (outcome != null) {
          throw IllegalRunActionError('끝난 런에는 이동을 기록할 수 없다');
        }
        if (combat != null) {
          throw IllegalRunActionError('전투가 끝나기 전에는 다음 노드로 이동할 수 없다');
        }

        final progress = RunProgress(
          map: map,
          visitedNodeIds: visitedNodeIds,
          hp: hp,
          maxHp: maxHp,
          karma: karma,
          deck: deck,
        );
        if (!_legalNextNodeIds(progress).contains(nodeId)) {
          throw IllegalRunActionError('로그가 현재 위치에서 갈 수 없는 노드 $nodeId를 가리킨다');
        }

        visitedNodeIds.add(nodeId);
        final node = map.nodeById(nodeId);
        if (node.hostsCombat && content != null) {
          combat = _beginNodeCombat(
            runSeed: state.seed,
            node: node,
            hp: hp,
            maxHp: maxHp,
            karma: karma,
            deck: deck,
            content: content,
            tuning: tuning,
          );
        }

      case CombatNodeLog(:final nodeId, :final actions):
        if (outcome != null) {
          throw IllegalRunActionError('끝난 런에는 전투 입력을 기록할 수 없다');
        }
        if (visitedNodeIds.isEmpty || visitedNodeIds.last != nodeId) {
          throw IllegalRunActionError('전투 로그가 현재 노드와 맞지 않는다');
        }
        if (combat == null) {
          throw IllegalRunActionError('전투가 아닌 노드에는 전투 로그를 기록할 수 없다');
        }
        if (!combatLogNodeIds.add(nodeId)) {
          throw IllegalRunActionError('한 전투 노드에는 전투 로그를 하나만 기록할 수 있다');
        }

        var currentCombat = combat;
        for (final combatAction in actions) {
          final legal = legalActions(currentCombat);
          if (!legal.any(
            (candidate) => _sameCombatAction(candidate, combatAction),
          )) {
            throw IllegalRunActionError('전투 로그에 불법 전투 액션이 있다');
          }
          currentCombat = applyAction(currentCombat, combatAction).state;
        }

        switch (currentCombat.outcome) {
          case CombatOutcome.victory:
            hp = currentCombat.hp;
            karma = currentCombat.karma;
            combat = null;
          case CombatOutcome.defeat:
            hp = currentCombat.hp;
            karma = currentCombat.karma;
            combat = currentCombat;
            outcome = RunOutcome.defeat;
          case null:
            combat = currentCombat;
            break;
        }
    }
  }

  return RunProgress(
    map: map,
    visitedNodeIds: visitedNodeIds,
    hp: hp,
    maxHp: maxHp,
    karma: karma,
    deck: deck,
    combat: combat,
    outcome: outcome,
  );
}

/// 전투는 노드별로 독립된 시드를 쓴다.
///
/// 하나의 combat 스트림을 전투 사이에 이어 쓰면 앞 전투에서 카드 한 장을 더
/// 뽑은 변화가 다음 전투 손패까지 밀어 낸다. 런 시드와 노드 id로 전투 시드를
/// 파생한 뒤 `beginCombat`에 넘기면 같은 노드의 손패는 앞 전투 입력과 무관하고,
/// 저장 로그의 한 전투를 고쳐도 이후 전투를 독립적으로 재생할 수 있다.
int combatSeedForNode(int runSeed, int nodeId) =>
    _nodeSeed(runSeed, nodeId, 0xC2B2AE35);

/// 적 구성도 노드마다 분리한 encounter 스트림으로 뽑는다.
int encounterSeedForNode(int runSeed, int nodeId) =>
    _nodeSeed(runSeed, nodeId, 0x85EBCA6B);

/// [RngStream.encounter]에서 현재 노드의 적을 결정론적으로 구성한다.
///
/// 정예와 보스의 전용 적은 아직 없으므로 [RunTuning]이 정한 수만큼 M0 적 풀을
/// 뽑는다. 전용 콘텐츠가 생기면 이 함수의 입력 풀만 역할별로 바꾸면 된다.
List<Enemy> encounterForNode({
  required int runSeed,
  required RunNode node,
  required RunContent content,
  RunTuning tuning = RunTuning.m1,
}) {
  if (!node.hostsCombat) {
    throw ArgumentError.value(node, 'node', '전투가 아닌 노드에는 적 구성이 없다');
  }

  final count = tuning.encounterSizeFor(node.type);
  if (count > content.encounterPool.length) {
    throw ArgumentError.value(
      count,
      'tuning encounter size',
      '적 풀보다 많은 서로 다른 적을 배치할 수 없다',
    );
  }

  var rng = Rng.forStream(
    encounterSeedForNode(runSeed, node.id),
    RngStream.encounter,
  );
  final available = List<Enemy>.of(content.encounterPool);
  final enemies = <Enemy>[];

  for (var i = 0; i < count; i++) {
    final (index, next) = rng.nextInt(available.length);
    rng = next;
    enemies.add(available.removeAt(index));
  }

  return List.unmodifiable(enemies);
}

CombatState _beginNodeCombat({
  required int runSeed,
  required RunNode node,
  required int hp,
  required int maxHp,
  required int karma,
  required List<CardDef> deck,
  required RunContent content,
  required RunTuning tuning,
}) {
  return beginCombat(
    seed: combatSeedForNode(runSeed, node.id),
    hp: hp,
    maxHp: maxHp,
    deck: deck,
    enemies: encounterForNode(
      runSeed: runSeed,
      node: node,
      content: content,
      tuning: tuning,
    ),
    karma: karma,
  ).state;
}

List<int> _legalNextNodeIds(RunProgress progress) {
  final currentNodeId = progress.currentNodeId;
  return currentNodeId == null
      ? [progress.map.nodes.first.id]
      : progress.map.nodeById(currentNodeId).nextNodeIds;
}

List<CombatAction> _currentCombatActions(RunState state, int nodeId) {
  if (state.actionLog.isEmpty) return const [];
  final last = state.actionLog.last;
  return switch (last) {
    CombatNodeLog(nodeId: final logNodeId, :final actions)
        when logNodeId == nodeId =>
      actions,
    _ => const [],
  };
}

bool _sameRunAction(RunAction left, RunAction right) => switch ((left, right)) {
  (
    MoveToNode(nodeId: final leftNodeId),
    MoveToNode(nodeId: final rightNodeId),
  ) =>
    leftNodeId == rightNodeId,
  (
    CombatNodeLog(nodeId: final leftNodeId, actions: final leftActions),
    CombatNodeLog(nodeId: final rightNodeId, actions: final rightActions),
  ) =>
    leftNodeId == rightNodeId &&
        _sameCombatActionLists(leftActions, rightActions),
  _ => false,
};

bool _sameCombatActionLists(List<CombatAction> left, List<CombatAction> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (!_sameCombatAction(left[i], right[i])) return false;
  }
  return true;
}

bool _sameCombatAction(CombatAction left, CombatAction right) =>
    switch ((left, right)) {
      (
        PlayCard(
          handIndex: final leftHandIndex,
          targetIndex: final leftTargetIndex,
        ),
        PlayCard(
          handIndex: final rightHandIndex,
          targetIndex: final rightTargetIndex,
        ),
      ) =>
        leftHandIndex == rightHandIndex && leftTargetIndex == rightTargetIndex,
      (EndTurn(), EndTurn()) => true,
      _ => false,
    };

int _nodeSeed(int runSeed, int nodeId, int salt) {
  const mask = 0xFFFFFFFF;
  var mixed = (runSeed ^ salt ^ (nodeId + 1) * 0x9E3779B9) & mask;
  mixed ^= mixed >> 16;
  mixed = (mixed * 0x85EBCA6B) & mask;
  mixed ^= mixed >> 13;
  mixed = (mixed * 0xC2B2AE35) & mask;
  return (mixed ^ (mixed >> 16)) & mask;
}
