/// 야장 선택 화면 문구 (기획서 §2.1, §3.3, §3.5).
///
/// 수치·선택지 해석과 화면 문구를 domain에서 함께 정한다. UI는 이 값을 배치만
/// 하므로, 참회 비용이나 강화 흐름이 바뀌어도 다른 설명을 따로 조립하지 않는다.
library;

import 'run_action.dart';
import 'run_tuning.dart';

class WildCampOptionPreview {
  const WildCampOptionPreview({required this.title, required this.detail});

  final String title;
  final String detail;
}

WildCampOptionPreview wildCampOptionPreview(
  WildCampChoice choice, {
  RunTuning tuning = RunTuning.m1,
}) => switch (choice) {
  WildCampChoice.rest => WildCampOptionPreview(
    title: '휴식',
    detail: '체력 +${tuning.wildCampRestHeal}',
  ),
  WildCampChoice.repent => WildCampOptionPreview(
    title: '참회',
    detail:
        '업 -${tuning.wildCampRepentKarmaCleanse} · 노잣돈 -${tuning.wildCampRepentMoneyCost}',
  ),
  WildCampChoice.enhance => const WildCampOptionPreview(
    title: '강화',
    detail: '선택한 카드 1장을 강화',
  ),
};

const wildCampChoicePrompt = '오늘의 대가를 고르세요';
const wildCampEnhancementTitle = '야장 · 강화';
const wildCampEnhancementStatus = '강화할 카드 1장을 고르세요';
const wildCampEnhancementPrompt = '강화한 카드는 다시 고를 수 없습니다';
