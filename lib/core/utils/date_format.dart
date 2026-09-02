/// Formateo de fechas/horas en español para VoyContigo.
///
/// Autónomo (sin inicialización de locale de `intl`) para que se vea igual
/// en cualquier dispositivo. Todo se calcula sobre la hora local.
class VoyDate {
  static const List<String> _monthsShort = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static const List<String> _monthsLong = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  // weekday: 1 = lunes ... 7 = domingo
  static const List<String> _weekdaysShort = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom',
  ];

  static const List<String> _weekdaysLong = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Hora en formato 24h con ceros: "07:05".
  static String time(DateTime dt) => '${_two(dt.hour)}:${_two(dt.minute)}';

  /// Día corto: "Mié 23 jul".
  static String dayShort(DateTime dt) =>
      '${_weekdaysShort[dt.weekday - 1]} ${dt.day} ${_monthsShort[dt.month - 1]}';

  /// Día largo: "Miércoles 23 de julio".
  static String dayLong(DateTime dt) =>
      '${_weekdaysLong[dt.weekday - 1]} ${dt.day} de ${_monthsLong[dt.month - 1]}';

  /// Fecha + hora compacta: "Mié 23 jul · 07:30".
  static String shortDateTime(DateTime dt) => '${dayShort(dt)} · ${time(dt)}';

  /// Encabezado de agrupación relativo: "Hoy", "Mañana" o "Miércoles 23 de julio".
  static String dayHeader(DateTime dt, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == -1) return 'Ayer';
    return dayLong(dt);
  }

  /// Solo la clave de día (para agrupar): "2026-07-23".
  static String dayKey(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

  /// Cuenta regresiva legible respecto a ahora.
  /// Ej.: "Sale en 25 min", "Sale en 3 h 5 min", "Sale en 2 días", "Salió hace poco".
  static String relativeDeparture(DateTime dt, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = dt.difference(ref);

    if (diff.isNegative) {
      final ago = ref.difference(dt);
      if (ago.inMinutes < 60) return 'Salió hace ${ago.inMinutes} min';
      if (ago.inHours < 24) return 'Salió hace ${ago.inHours} h';
      return 'Salida pasada';
    }

    if (diff.inMinutes < 1) return 'Sale ahora';
    if (diff.inMinutes < 60) return 'Sale en ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      final mins = diff.inMinutes % 60;
      return mins == 0
          ? 'Sale en ${diff.inHours} h'
          : 'Sale en ${diff.inHours} h $mins min';
    }
    final days = diff.inDays;
    return days == 1 ? 'Sale mañana' : 'Sale en $days días';
  }
}
