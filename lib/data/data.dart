/// 데이터 레이어 (기획서 §7.2, §7.3).
///
/// 담당하는 것:
/// - `assets/data/*.json`에서 카드·적·유물 정의를 읽어 `domain/` 모델로 변환
/// - 저장/불러오기 (JSON 파일) — 저장 대상은 `{seed, characterId, actionLog}` (§7.4)
/// - Firebase Remote Config로 밸런스 상수 덮어쓰기
///
/// 카드 정의는 M0 동안 Dart 상수로 두고, 런 저장만 단일 JSON 파일로 먼저 쓴다.
library;
