import 'package:flutter_test/flutter_test.dart';
import 'package:fp_pemrograman/service/academic_task_url.dart';

void main() {
  group('Academic task evidence validation', () {
    test('accepts valid http and https evidence links', () {
      expect(isUsableEvidenceUrl('https://storage.pathoengage.com/evidence/IMG-20260822-WA0066.jpg'), isTrue);
      expect(isUsableEvidenceUrl('https://example.com/uploads/report.pdf'), isTrue);
      expect(isUsableEvidenceUrl('http://example.com/file.png'), isTrue);
    });

    test('rejects empty, placeholder, and malformed evidence links', () {
      expect(isUsableEvidenceUrl(null), isFalse);
      expect(isUsableEvidenceUrl(''), isFalse);
      expect(isUsableEvidenceUrl('https://storage.pathoengage.com/evidence/'), isFalse);
      expect(isUsableEvidenceUrl('not-a-url'), isFalse);
    });
  });
}
