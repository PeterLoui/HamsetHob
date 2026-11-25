import '../core/coptic.dart' show ar;
import 'bible.dart';

/// خطة قراءة: الكتاب مقسّم على أيام، كل يوم قائمة إصحاحات (الآية ٠).
class ReadingPlan {
  const ReadingPlan(this.id, this.title, this.subtitle, this.days);
  final String id;
  final String title;
  final String subtitle;
  final List<List<VerseRef>> days;

  int get chapters => days.fold(0, (s, d) => s + d.length);
}

/// كل إصحاحات الأسفار المطلوبة بالترتيب (بأرقام الأسفار ١..٦٦).
List<VerseRef> _chaptersOf(Iterable<int> bookNumbers) => [
      for (final n in bookNumbers)
        for (var ch = 1; ch <= books[n - 1].chapters; ch++) VerseRef(n, ch, 0),
    ];

/// توزيع الإصحاحات على [days] يوم بالتساوي؛ الأيام الأولى تاخد إصحاح زيادة لو القسمة مش صحيحة.
List<List<VerseRef>> _split(List<VerseRef> all, int days) {
  final out = <List<VerseRef>>[];
  final base = all.length ~/ days, extra = all.length % days;
  var i = 0;
  for (var d = 0; d < days; d++) {
    final take = base + (d < extra ? 1 : 0);
    out.add(all.sublist(i, i + take));
    i += take;
  }
  return out;
}

List<int> _range(int from, int to) => [for (var n = from; n <= to; n++) n];

/// الخطط المتاحة. الأرقام: العهد القديم ١..٣٩، المزامير ١٩، العهد الجديد ٤٠..٦٦.
final readingPlans = <ReadingPlan>[
  ReadingPlan('gospels40', 'الأناجيل الأربعة في ٤٠ يوم', 'متى ومرقس ولوقا ويوحنا', _split(_chaptersOf([40, 41, 42, 43]), 40)),
  ReadingPlan('nt90', 'العهد الجديد في ٣ شهور', 'الأناجيل والرسائل والرؤيا', _split(_chaptersOf(_range(40, 66)), 90)),
  ReadingPlan('psalms30', 'المزامير في شهر', 'نحو خمسة مزامير كل يوم', _split(_chaptersOf([19]), 30)),
  ReadingPlan('bible365', 'الكتاب المقدس في سنة', 'من التكوين إلى الرؤيا', _split(_chaptersOf(_range(1, 66)), 365)),
];

/// وصف قراءة اليوم: «متى ١–٣» أو «متى ٢٨ — مرقس ٢».
String planDayLabel(List<VerseRef> day) {
  if (day.isEmpty) return '';
  String one(VerseRef r) => '${books[r.book - 1].name} ${ar(r.chapter)}';
  final first = day.first, last = day.last;
  if (day.length == 1) return one(first);
  if (first.book == last.book) return '${books[first.book - 1].name} ${ar(first.chapter)}–${ar(last.chapter)}';
  return '${one(first)} — ${one(last)}';
}
