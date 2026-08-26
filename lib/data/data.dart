/// 데이터 레이어 (기획서 §7.2, §7.3).
///
/// 담당하는 것:
/// - `assets/data/*.json`에서 카드·적·유물 정의를 읽어 `domain/` 모델로 변환
/// - 저장/불러오기 (Hive) — 저장 대상은 `{seed, characterId, actionLog}` (§7.4)
/// - Firebase Remote Config로 밸런스 상수 덮어쓰기
///
/// M0 시점에는 비어 있다. 카드 3장은 테스트 안에 직접 적어 넣고,
/// JSON 로더는 카드 수가 20장을 넘어갈 때 만든다.
library;
