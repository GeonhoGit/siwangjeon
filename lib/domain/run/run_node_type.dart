/// 저승길 노드 종류의 공통 정의 (기획서 §2.1).
library;

/// 이번 단계에서는 종류와 경로만 정의한다. 보상·상점·야장·사건의 내용은
/// 다음 단계의 각 도메인 규칙이 붙을 자리다.
enum RunNodeType { combat, elite, shop, wildCamp, event, boss }
