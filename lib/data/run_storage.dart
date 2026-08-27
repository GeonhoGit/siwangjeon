/// 런 저장 파일의 직렬화와 디스크 입출력 (§2.3, §7.1, §7.4).
///
/// M1에는 조회·부분 갱신·여러 레코드가 없고, 저장 대상도 작은 JSON 한 개뿐이다.
/// 그래서 Hive/sqflite 대신 앱 문서 디렉터리의 파일을 쓴다. `path_provider`는
/// 플랫폼별 문서 경로만 제공하며, 저장 형식과 원자적 교체는 이 파일에 남긴다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/model/combat_action.dart';
import '../domain/run/run_action.dart';
import '../domain/run/run_state.dart';

/// 저장 파일의 현재 형식 버전.
///
/// 버전이 다른 파일은 일부 필드만 억지로 읽지 않고 거부한다. 액션 하나라도
/// 잘못 해석하면 이후 재생 상태 전체를 믿을 수 없기 때문이다.
/// 새 `ChooseRelicReward` 액션은 구버전 v2가 해석할 수 없으므로 v3로
/// 올린다. v2 저장은 기존 정책대로 거부하고 원본을 보존한다. 보유 유물과
/// 후보는 액션 로그에서 재생하므로 `{seed, characterId, actionLog}` 골격은
/// 그대로다.
const runSaveVersion = 3;

/// 테스트와 앱 배선이 공유하는 런 저장소 경계.
abstract interface class RunStorage {
  Future<RunLoadResult> load();

  Future<void> save(RunState state);
}

/// 저장소 읽기 결과.
sealed class RunLoadResult {
  const RunLoadResult();
}

final class RunLoadFound extends RunLoadResult {
  const RunLoadFound(this.state);

  final RunState state;
}

final class RunLoadMissing extends RunLoadResult {
  const RunLoadMissing();
}

/// 파일을 읽을 수 없거나 형식·버전이 맞지 않는 결과.
///
/// 이 경우 파일은 삭제하거나 덮어쓰지 않는다. 앱은 새 런으로 시작하지만,
/// 플레이어가 다음 액션을 확정하기 전까지는 원래 파일을 보존한다.
final class RunLoadRejected extends RunLoadResult {
  const RunLoadRejected();
}

/// {seed, characterId, actionLog} 런 골격을 JSON 문자열로 바꾼다.
///
/// `version`은 그 골격을 감싸는 호환성 표지일 뿐, 재생 상태를 추가 저장하지
/// 않는다. sealed 액션 계층은 아래 switch에서 빠짐없이 열거해 새 액션이
/// 추가되면 컴파일러가 저장 형식도 갱신하게 한다.
class RunSaveCodec {
  const RunSaveCodec();

  String encode(RunState state) => jsonEncode({
    'version': runSaveVersion,
    'seed': state.seed,
    'characterId': state.characterId,
    'actionLog': [
      for (final action in state.actionLog) _encodeRunAction(action),
    ],
  });

  RunState decode(String source) {
    final Object? decoded = jsonDecode(source);
    final map = _map(decoded, '저장 파일의 최상위 값');
    final version = _int(map, 'version');
    if (version != runSaveVersion) {
      throw const FormatException('지원하지 않는 런 저장 버전이다');
    }

    final rawLog = _list(map['actionLog'], 'actionLog');
    return RunState(
      seed: _int(map, 'seed'),
      characterId: _string(map, 'characterId'),
      actionLog: [for (final rawAction in rawLog) _decodeRunAction(rawAction)],
    );
  }

  Map<String, Object?> _encodeRunAction(RunAction action) => switch (action) {
    MoveToNode(:final nodeId) => {'type': 'moveToNode', 'nodeId': nodeId},
    CombatNodeLog(:final nodeId, :final actions) => {
      'type': 'combatNodeLog',
      'nodeId': nodeId,
      'actions': [for (final action in actions) _encodeCombatAction(action)],
    },
    ChooseCardReward(:final nodeId, :final cardId) => {
      'type': 'chooseCardReward',
      'nodeId': nodeId,
      'cardId': cardId,
    },
    ChooseRelicReward(:final nodeId, :final relicId) => {
      'type': 'chooseRelicReward',
      'nodeId': nodeId,
      'relicId': relicId,
    },
    BuyShopCard(:final nodeId, :final cardId) => {
      'type': 'buyShopCard',
      'nodeId': nodeId,
      'cardId': cardId,
    },
    RemoveShopCard(:final nodeId, :final cardInstanceId) => {
      'type': 'removeShopCard',
      'nodeId': nodeId,
      'cardInstanceId': cardInstanceId,
    },
    LeaveShop(:final nodeId) => {'type': 'leaveShop', 'nodeId': nodeId},
    ChooseWildCampOption(:final nodeId, :final choice) => {
      'type': 'chooseWildCampOption',
      'nodeId': nodeId,
      'choice': choice.name,
    },
    EnhanceWildCampCard(:final nodeId, :final cardInstanceId) => {
      'type': 'enhanceWildCampCard',
      'nodeId': nodeId,
      'cardInstanceId': cardInstanceId,
    },
    ChooseEventOption(:final nodeId, :final choiceId) => {
      'type': 'chooseEventOption',
      'nodeId': nodeId,
      'choiceId': choiceId,
    },
  };

  Map<String, Object?> _encodeCombatAction(CombatAction action) =>
      switch (action) {
        PlayCard(:final handIndex, :final targetIndex) => {
          'type': 'playCard',
          'handIndex': handIndex,
          'targetIndex': ?targetIndex,
        },
        EndTurn() => {'type': 'endTurn'},
      };

  RunAction _decodeRunAction(Object? rawAction) {
    final map = _map(rawAction, '런 액션');
    final type = _string(map, 'type');
    if (type == 'moveToNode') {
      return MoveToNode(nodeId: _int(map, 'nodeId'));
    }
    if (type == 'combatNodeLog') {
      final rawActions = _list(map['actions'], 'combatNodeLog.actions');
      return CombatNodeLog(
        nodeId: _int(map, 'nodeId'),
        actions: [
          for (final rawCombatAction in rawActions)
            _decodeCombatAction(rawCombatAction),
        ],
      );
    }
    if (type == 'chooseCardReward') {
      return ChooseCardReward(
        nodeId: _int(map, 'nodeId'),
        cardId: _string(map, 'cardId'),
      );
    }
    if (type == 'chooseRelicReward') {
      return ChooseRelicReward(
        nodeId: _int(map, 'nodeId'),
        relicId: _string(map, 'relicId'),
      );
    }
    if (type == 'buyShopCard') {
      return BuyShopCard(
        nodeId: _int(map, 'nodeId'),
        cardId: _string(map, 'cardId'),
      );
    }
    if (type == 'removeShopCard') {
      return RemoveShopCard(
        nodeId: _int(map, 'nodeId'),
        cardInstanceId: _string(map, 'cardInstanceId'),
      );
    }
    if (type == 'leaveShop') {
      return LeaveShop(nodeId: _int(map, 'nodeId'));
    }
    if (type == 'chooseWildCampOption') {
      return ChooseWildCampOption(
        nodeId: _int(map, 'nodeId'),
        choice: _wildCampChoice(_string(map, 'choice')),
      );
    }
    if (type == 'enhanceWildCampCard') {
      return EnhanceWildCampCard(
        nodeId: _int(map, 'nodeId'),
        cardInstanceId: _string(map, 'cardInstanceId'),
      );
    }
    if (type == 'chooseEventOption') {
      return ChooseEventOption(
        nodeId: _int(map, 'nodeId'),
        choiceId: _string(map, 'choiceId'),
      );
    }
    throw FormatException('알 수 없는 런 액션 형식: $type');
  }

  WildCampChoice _wildCampChoice(String source) {
    for (final choice in WildCampChoice.values) {
      if (choice.name == source) return choice;
    }
    throw FormatException('알 수 없는 야장 선택지: $source');
  }

  CombatAction _decodeCombatAction(Object? rawAction) {
    final map = _map(rawAction, '전투 액션');
    final type = _string(map, 'type');
    if (type == 'playCard') {
      final rawTargetIndex = map['targetIndex'];
      return PlayCard(
        handIndex: _int(map, 'handIndex'),
        targetIndex: rawTargetIndex == null
            ? null
            : _intValue(rawTargetIndex, 'targetIndex'),
      );
    }
    if (type == 'endTurn') return const EndTurn();
    throw FormatException('알 수 없는 전투 액션 형식: $type');
  }
}

/// 앱 문서 디렉터리의 JSON 파일 저장소.
///
/// 새 문자열은 임시 파일에 먼저 flush한 뒤 원본 이름으로 교체한다. 쓰기 도중
/// 앱이 종료돼도 기존 저장을 우선 보존하기 위한 것이다.
class FileRunStorage implements RunStorage {
  FileRunStorage({
    Future<Directory> Function()? documentsDirectory,
    this.fileName = 'run.json',
    this._codec = const RunSaveCodec(),
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;
  final String fileName;
  final RunSaveCodec _codec;

  @override
  Future<RunLoadResult> load() async {
    try {
      final file = await _file();
      if (FileSystemEntity.typeSync(file.path) ==
          FileSystemEntityType.notFound) {
        return const RunLoadMissing();
      }
      return RunLoadFound(_codec.decode(await file.readAsString()));
    } catch (_) {
      // 손상 파일과 권한·디스크 오류 모두 시작을 막지 않는다. 호출자는 파일을
      // 지우지 않고 새 런으로 시작하므로, 첫 액션 전에는 잃을 데이터를 보존한다.
      return const RunLoadRejected();
    }
  }

  @override
  Future<void> save(RunState state) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(_codec.encode(state), flush: true);
    await temporary.rename(file.path);
  }

  Future<File> _file() async {
    final directory = await _documentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }
}

/// 저장을 원하지 않는 테스트의 기본 구현.
///
/// 실제 앱은 main에서 [FileRunStorage]를 주입한다. 이 기본값 덕분에 위젯 테스트는
/// 디스크를 공유하지 않고, 필요한 저장 동작만 메모리 fake로 명시할 수 있다.
class NoopRunStorage implements RunStorage {
  const NoopRunStorage();

  @override
  Future<RunLoadResult> load() =>
      Future<RunLoadResult>.value(const RunLoadMissing());

  @override
  Future<void> save(RunState state) => Future<void>.value();
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('$name이 JSON 객체가 아니다');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw FormatException('$name의 키가 문자열이 아니다');
    }
    result[key] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String name) {
  if (value is! List<Object?>) {
    throw FormatException('$name이 JSON 배열이 아니다');
  }
  return value;
}

int _int(Map<String, Object?> map, String key) {
  if (!map.containsKey(key)) {
    throw FormatException('$key 필드가 없다');
  }
  return _intValue(map[key], key);
}

int _intValue(Object? value, String key) {
  if (value is! int) {
    throw FormatException('$key 필드가 정수가 아니다');
  }
  return value;
}

String _string(Map<String, Object?> map, String key) {
  if (!map.containsKey(key)) {
    throw FormatException('$key 필드가 없다');
  }
  final value = map[key];
  if (value is! String) {
    throw FormatException('$key 필드가 문자열이 아니다');
  }
  return value;
}
