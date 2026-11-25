import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/formative_activities/domain/models/formative_activity.dart';
import 'package:jf_innova_app/features/home/domain/draft_card_data.dart';
import 'package:jf_innova_app/features/home/domain/draft_card_mapper.dart';

void main() {
  group('FormativeActivity duration and HH', () {
    test('rejects invalid times and activities crossing midnight', () {
      expect(FormativeActivity.durationMinutes('09:15', '09:15'), isNull);
      expect(FormativeActivity.durationMinutes('09:30', '09:15'), isNull);
      expect(FormativeActivity.durationMinutes('24:00', '24:15'), isNull);
      expect(FormativeActivity.durationMinutes('23:45', '00:15'), isNull);
    });

    test('rounds positive duration up to 15-minute blocks', () {
      expect(FormativeActivity.accountedDurationMinutes(1), 15);
      expect(FormativeActivity.accountedDurationMinutes(15), 15);
      expect(FormativeActivity.accountedDurationMinutes(16), 30);
      expect(FormativeActivity.accountedDurationMinutes(60), 60);
      expect(FormativeActivity.accountedDurationMinutes(0), 0);
    });

    test('computes HH with and without one relator', () {
      expect(FormativeActivity.hoursWithoutRelator(4, 30), 2);
      expect(FormativeActivity.hoursWithRelator(4, 30), 2.5);
    });
  });

  test('maps formative activity drafts to their own Home card type', () {
    final draft = DraftCardMapper.fromInspeccion({
      'id': 'activity-1',
      'tipo_actividad': 'ACTIVIDAD_FORMATIVA',
      'fecha_realizacion': '2026-09-03T10:00:00.000Z',
    });

    expect(draft.kind, DraftKind.actividadFormativa);
    expect(draft.title, 'Actividad Formativa');
  });
}
