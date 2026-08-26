/// 런 진행 재생과 노드 이동 규칙 (기획서 §2.1, §2.3, §7.4).
library;

import 'run_action.dart';
import 'run_map.dart';
import 'run_state.dart';
import 'run_tuning.dart';

/// 액션 로그에 현재 런에서 성립하지 않는 입력이 들어왔을 때 던진다.
///
/// UI와 저장 계층은 [legalRunActions]가 돌려준 이동만 기록해야 한다. 불법 이동을
/// 조용히 무시하면 같은 로그를 재생할 때마다 어느 지점까지 믿을 수 있는지
/// 알 수 없어 §7.4의 복구 계약이 무너진다.
class IllegalRunActionError implements Exception {
  const IllegalRunActionError(this.message);

  final String message;

  @override
  String toString() => 'IllegalRunActionError: $message';
}

/// 시드와 액션 로그에서 다시 만든 현재 런 진행 상태.
///
/// 이 값은 저장하지 않는다. [RunState]의 세 필드만 저장한 뒤 매번 재생한다.
class RunProgress {
  RunProgress({required this.map, required List<int> visitedNodeIds})
    : visitedNodeIds = List.unmodifiable(visitedNodeIds);

  final RunMap map;
  final List<int> visitedNodeIds;

  int? get currentNodeId => visitedNodeIds.isEmpty ? null : visitedNodeIds.last;

  RunNode? get currentNode =>
      currentNodeId == null ? null : map.nodeById(currentNodeId!);
}

/// 새 런의 저장 가능한 시작값.
RunState startRun({required int seed, required String characterId}) {
  return RunState(seed: seed, characterId: characterId, actionLog: const []);
}

/// 현재 상태에서 합법인 런 액션.
///
/// 지금은 노드 이동만 실행한다. 전투 하위 로그는 전투 노드가 실제로 시작될 때
/// 기존 전투 엔진이 만들어 넣으므로, 가능한 카드 행동을 여기서 추측하지 않는다.
List<RunAction> legalRunActions(
  RunState state, {
  RunTuning tuning = RunTuning.m1,
}) {
  final progress = replayRun(state, tuning: tuning);
  final currentNodeId = progress.currentNodeId;
  final legalNodeIds = currentNodeId == null
      ? [progress.map.nodes.first.id]
      : progress.map.nodeById(currentNodeId).nextNodeIds;

  return [for (final id in legalNodeIds) MoveToNode(nodeId: id)];
}

/// 액션 하나를 기록해 다음 저장 상태를 돌려준다.
RunState applyRunAction(
  RunState state,
  RunAction action, {
  RunTuning tuning = RunTuning.m1,
}) {
  switch (action) {
    case MoveToNode(:final nodeId):
      final legal = legalRunActions(
        state,
        tuning: tuning,
      ).whereType<MoveToNode>();
      if (!legal.any((candidate) => candidate.nodeId == nodeId)) {
        throw IllegalRunActionError('현재 위치에서 노드 $nodeId(으)로 이동할 수 없다');
      }

    case CombatNodeLog(:final nodeId):
      final progress = replayRun(state, tuning: tuning);
      final currentNode = progress.currentNode;
      if (currentNode == null || currentNode.id != nodeId) {
        throw IllegalRunActionError('전투 로그는 현재 노드에만 기록할 수 있다');
      }
      if (!currentNode.hostsCombat) {
        throw IllegalRunActionError('전투가 아닌 노드에는 전투 로그를 기록할 수 없다');
      }
      if (state.actionLog.whereType<CombatNodeLog>().any(
        (log) => log.nodeId == nodeId,
      )) {
        throw IllegalRunActionError('한 전투 노드에는 전투 로그를 하나만 기록할 수 있다');
      }
  }

  return RunState(
    seed: state.seed,
    characterId: state.characterId,
    actionLog: [...state.actionLog, action],
  );
}

/// 저장된 액션 로그를 처음부터 적용해 현재 노드까지 복원한다.
RunProgress replayRun(RunState state, {RunTuning tuning = RunTuning.m1}) {
  final map = generateActOneMap(state.seed, tuning: tuning);
  final visitedNodeIds = <int>[];

  for (final action in state.actionLog) {
    switch (action) {
      case MoveToNode(:final nodeId):
        final legalNodeIds = visitedNodeIds.isEmpty
            ? [map.nodes.first.id]
            : map.nodeById(visitedNodeIds.last).nextNodeIds;
        if (!legalNodeIds.contains(nodeId)) {
          throw IllegalRunActionError('로그가 현재 위치에서 갈 수 없는 노드 $nodeId를 가리킨다');
        }
        visitedNodeIds.add(nodeId);

      case CombatNodeLog(:final nodeId):
        if (visitedNodeIds.isEmpty || visitedNodeIds.last != nodeId) {
          throw IllegalRunActionError('전투 로그가 현재 노드와 맞지 않는다');
        }
        if (!map.nodeById(nodeId).hostsCombat) {
          throw IllegalRunActionError('전투가 아닌 노드의 전투 로그는 재생할 수 없다');
        }
    }
  }

  return RunProgress(map: map, visitedNodeIds: visitedNodeIds);
}
