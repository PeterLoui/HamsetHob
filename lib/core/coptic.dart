/// التقويم القبطي (سنة الشهداء) وحساب عيد القيامة.
library;

const copticMonths = [
  'توت', 'بابه', 'هاتور', 'كيهك', 'طوبه', 'أمشير', 'برمهات',
  'برموده', 'بشنس', 'بؤونه', 'أبيب', 'مسرى', 'النسيء',
];

const gregorianMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// DateTime.weekday: الإثنين = 1 … الأحد = 7
const weekdayNames = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String weekdayName(DateTime d) => weekdayNames[d.weekday - 1];

/// تحويل الأرقام إلى أرقام عربية مشرقية.
String ar(Object n) => n.toString().replaceAllMapped(RegExp(r'\d'), (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]);

/// تاريخ بلا وقت (منتصف الليل بالتوقيت العالمي) لتجنب مشاكل التوقيت الصيفي.
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

class CopticDate {
  const CopticDate(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  String get monthName => copticMonths[month - 1];

  // رقم اليوم اليولياني لـ 1 توت سنة 1 للشهداء
  static const _epochJdn = 1825030;
  static const _unixEpochJdn = 2440588;

  static int _toJdn(int y, int m, int d) => _epochJdn - 1 + 365 * (y - 1) + y ~/ 4 + 30 * (m - 1) + d;

  static int _jdnOf(DateTime g) => dateOnly(g).millisecondsSinceEpoch ~/ 86400000 + _unixEpochJdn;

  factory CopticDate.fromGregorian(DateTime g) {
    final jdn = _jdnOf(g);
    final y = (4 * (jdn - _epochJdn) + 1463) ~/ 1461;
    final m = (jdn - _toJdn(y, 1, 1)) ~/ 30 + 1;
    final d = jdn + 1 - _toJdn(y, m, 1);
    return CopticDate(y, m, d);
  }

  DateTime toGregorian() =>
      DateTime.fromMillisecondsSinceEpoch((_toJdn(year, month, day) - _unixEpochJdn) * 86400000, isUtc: true);

  static int daysInMonth(int year, int month) => month < 13 ? 30 : (year % 4 == 3 ? 6 : 5);

  String get label => '${ar(day)} $monthName ${ar(year)} ش';
}

/// عيد القيامة حسب الحساب الأبقطي (يولياني) محوّلاً للميلادي.
DateTime copticEaster(int year) {
  final a = year % 4, b = year % 7, c = year % 19;
  final d = (19 * c + 15) % 30;
  final e = (2 * a + 4 * b - d + 34) % 7;
  final month = (d + e + 114) ~/ 31;
  final day = (d + e + 114) % 31 + 1;
  final offset = year ~/ 100 - year ~/ 400 - 2;
  return DateTime.utc(year, month, day).add(Duration(days: offset));
}

int daysBetween(DateTime from, DateTime to) => dateOnly(to).difference(dateOnly(from)).inDays;

String gregorianLabel(DateTime d) => '${ar(d.day)} ${gregorianMonths[d.month - 1]} ${ar(d.year)} م';
