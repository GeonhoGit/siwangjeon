/// 시왕 심판의 플레이어 표시용 파생 값 (§3.3).
///
/// UI는 이 값을 배치만 한다. 업 구간별 효과 문구를 UI가 다시 만들면 실제 전투
/// 수정 규칙과 표시가 서로 다른 심판을 설명할 수 있다.
library;

import '../model/boss.dart';
import '../model/combat_state.dart';
import 'run_tuning.dart';

class JudgmentPreview {
  const JudgmentPreview({
    required this.title,
    required this.bandLabel,
    required this.effectLabel,
  });

  final String title;
  final String bandLabel;
  final String effectLabel;
}

JudgmentPreview judgmentPreviewFor({
  required int karma,
  required BossDef boss,
  RunTuning tuning = RunTuning.m1,
}) {
  final band = tuning.karmaBandFor(karma);
  final effectLabel = switch (band) {
    KarmaBand.pure => '시왕 체력 ${tuning.pureBossHpReductionPercent}% 감소',
    KarmaBand.ordinary => '기준 심판',
    KarmaBand.turbid => '추가 판결 행동 1개',
    KarmaBand.wicked => '즉시 2페이즈 · 승리 시 유물 획득',
  };
  final bandLabel = switch (band) {
    KarmaBand.pure => '청정',
    KarmaBand.ordinary => '평범',
    KarmaBand.turbid => '탁함',
    KarmaBand.wicked => '악업',
  };

  return JudgmentPreview(
    title: '${boss.enemy.name}의 심판',
    bandLabel: '$bandLabel 업 ($karma)',
    effectLabel: effectLabel,
  );
}
