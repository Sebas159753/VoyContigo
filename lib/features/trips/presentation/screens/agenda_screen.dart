import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/core/utils/date_format.dart';
import 'package:voycontigo/core/utils/error_handler.dart';
import 'package:voycontigo/core/services/notification_service.dart';
import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:voycontigo/features/trips/data/trip_repository.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';

/// Agenda de viajes programados del usuario.
/// Pestaña "Programados" (próximos, agrupados por día, con series) e "Historial".
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen>
    with SingleTickerProviderStateMixin {
  String? _lastSyncSignature;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // El FAB depende de la pestaña activa: refrescar su visibilidad al cambiar.
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Reprograma los recordatorios locales cuando cambia la lista de próximos.
  void _syncReminders(List<TripBoardItem> upcoming) {
    final active = upcoming
        .where((t) =>
            t.status == 'PENDING' ||
            t.status == 'ACCEPTED' ||
            t.status == 'FULL' ||
            t.status == 'EN_ROUTE')
        .toList();

    final signature = active
        .map((t) => '${t.id}:${t.scheduleTime.millisecondsSinceEpoch}:${t.status}')
        .join('|');
    if (signature == _lastSyncSignature) return;
    _lastSyncSignature = signature;

    final reminders = active
        .map((t) => TripReminder(
              tripId: t.id,
              scheduleTime: t.scheduleTime,
              routeLabel: '${t.origin} ➔ ${t.destination}',
            ))
        .toList();

    // Fire-and-forget: no bloquea el render.
    NotificationService().syncUpcomingReminders(reminders);
  }

  @override
  Widget build(BuildContext context) {
    final asyncTrips = ref.watch(myTripsStreamProvider);
    final upcoming = ref.watch(upcomingScheduledTripsProvider);
    final uid = ref.watch(appStateProvider.select((s) => s.uid));
    final isDriver = ref.watch(boardModeProvider) == 'conductor';

    // Sincroniza recordatorios tras construir el frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReminders(upcoming));

    return Scaffold(
      appBar: AppBar(
        title: Text('Agenda', style: AppTheme.titleFont(fontSize: 20)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Programados'),
            Tab(text: 'Calendario'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      // Una sola acción, acorde al perfil activo (conductor o pasajero).
      // Visible en "Programados" y "Calendario", no en "Historial".
      floatingActionButton: _tabController.index != 2
          ? FloatingActionButton.extended(
              onPressed: () => _goSchedule(isDriver),
              icon: Icon(isDriver
                  ? Icons.directions_car_filled
                  : Icons.person_pin_circle_outlined),
              label: Text(isDriver ? 'Ofrecer viaje' : 'Solicitar viaje',
                  style: AppTheme.subtitleFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.pureWhite)),
            )
          : null,
      body: asyncTrips.when(
        loading: () => Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(ErrorHandler.getFriendlyErrorMessage(e),
                textAlign: TextAlign.center,
                style: AppTheme.bodyFont(color: AppTheme.inkMuted)),
          ),
        ),
        data: (all) {
          final history = all
              .where((t) => t.status == 'COMPLETED' || t.status == 'CANCELLED')
              .toList()
            ..sort((a, b) => b.scheduleTime.compareTo(a.scheduleTime));

          return TabBarView(
            controller: _tabController,
            children: [
              _buildProgramados(upcoming, uid, isDriver),
              _CalendarView(trips: all, onOpenTrip: _openTrip),
              _buildHistorial(history, uid),
            ],
          );
        },
      ),
    );
  }

  void _goSchedule(bool isDriver) {
    context.push('/publish?type=${isDriver ? 'oferta' : 'demanda'}');
  }

  // ---------------------------------------------------------------------------
  // Programados: agrupados por día
  // ---------------------------------------------------------------------------
  Widget _buildProgramados(List<TripBoardItem> trips, String uid, bool isDriver) {
    if (trips.isEmpty) {
      return _EmptyState(
        icon: Icons.event_available_outlined,
        title: 'No tienes viajes programados',
        subtitle: isDriver
            ? 'Toca “Ofrecer viaje” abajo para publicar tu ruta Machachi ↔ Quito.'
            : 'Toca “Solicitar viaje” abajo para pedir un cupo entre Machachi y Quito.',
      );
    }

    // Un viaje por día, agrupados por encabezado de día.
    final widgets = <Widget>[];
    String? lastDayKey;
    for (final t in trips) {
      final key = VoyDate.dayKey(t.scheduleTime);
      if (key != lastDayKey) {
        lastDayKey = key;
        widgets.add(_DayHeader(label: VoyDate.dayHeader(t.scheduleTime)));
      }
      widgets.add(_AgendaTile(
        item: t,
        uid: uid,
        onOpen: () => _openTrip(t),
        onEdit: () => _editTrip(t),
        onCancelSingle: () => _cancelSingle(t),
        onCancelSeries: () => _cancelSeries(t),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: widgets,
    );
  }

  Widget _buildHistorial(List<TripBoardItem> trips, String uid) {
    if (trips.isEmpty) {
      return const _EmptyState(
        icon: Icons.history,
        title: 'Tu historial está vacío',
        subtitle: 'Aquí verás los viajes que completaste o cancelaste.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: trips.length,
      itemBuilder: (_, i) => _AgendaTile(
        item: trips[i],
        uid: uid,
        isHistory: true,
        onOpen: () => _openTrip(trips[i]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------
  void _openTrip(TripBoardItem t) {
    context.push('/tracking/${t.id}');
  }

  void _editTrip(TripBoardItem t) {
    context.push('/publish?type=${t.isOffer ? 'oferta' : 'demanda'}&tripId=${t.id}');
  }

  Future<void> _cancelSingle(TripBoardItem t) async {
    final ok = await _confirm(
      title: 'Cancelar viaje',
      message:
          '¿Cancelar tu viaje del ${VoyDate.dayShort(t.scheduleTime)} a las ${VoyDate.time(t.scheduleTime)}? Pasará al historial.',
    );
    if (ok != true) return;
    try {
      await ref.read(tripRepositoryProvider).cancelTrip(t.id);
      await NotificationService().cancelTripReminder(t.id);
      if (mounted) {
        ErrorHandler.showSuccessSnackBar(context, 'Viaje cancelado');
      }
    } catch (e) {
      if (mounted) ErrorHandler.showErrorSnackBar(context, e);
    }
  }

  Future<void> _cancelSeries(TripBoardItem t) async {
    final groupId = t.recurringGroupId;
    if (groupId == null) return _cancelSingle(t);

    final ok = await _confirm(
      title: 'Cancelar toda la serie',
      message:
          'Se cancelarán todos los viajes pendientes de esta serie recurrente. Los que ya tienen pasajeros o conductor no se tocan.',
    );
    if (ok != true) return;
    try {
      final repo = ref.read(tripRepositoryProvider);
      // Cancela primero los recordatorios locales de las ocurrencias pendientes.
      final ids = await repo.pendingSeriesTripIds(groupId, t.creatorUid);
      for (final id in ids) {
        await NotificationService().cancelTripReminder(id);
      }
      final count = await repo.cancelSeries(groupId, t.creatorUid);
      if (mounted) {
        ErrorHandler.showSuccessSnackBar(
            context, 'Serie cancelada · $count viaje(s)');
      }
    } catch (e) {
      if (mounted) ErrorHandler.showErrorSnackBar(context, e);
    }
  }

  Future<bool?> _confirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppTheme.titleFont(fontSize: 20)),
        content: Text(message, style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.inkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.standardRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

}

// -----------------------------------------------------------------------------
// Widgets auxiliares
// -----------------------------------------------------------------------------

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
      child: Text(
        label.toUpperCase(),
        style: AppTheme.subtitleFont(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Vista de calendario mensual: puntos en los días con viajes; al tocar un día
/// se listan sus viajes debajo.
class _CalendarView extends StatefulWidget {
  final List<TripBoardItem> trips;
  final void Function(TripBoardItem) onOpenTrip;

  const _CalendarView({required this.trips, required this.onOpenTrip});

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  late DateTime _month;
  late DateTime _selectedDay;

  static const List<String> _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const List<String> _weekLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final now = DateTime.now();

    // Viajes por día (clave yyyy-MM-dd).
    final Map<String, List<TripBoardItem>> byDay = {};
    for (final t in widget.trips) {
      byDay.putIfAbsent(VoyDate.dayKey(t.scheduleTime), () => []).add(t);
    }

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday - 1; // lunes primero
    final rows = ((offset + daysInMonth) / 7).ceil();

    final selectedTrips = (byDay[VoyDate.dayKey(_selectedDay)] ?? <TripBoardItem>[])
      ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        // Cabecera de mes
        Row(
          children: [
            Expanded(
              child: Text(
                '${_monthNames[_month.month - 1]} ${_month.year}',
                style: AppTheme.titleFont(fontSize: 20, color: AppTheme.ink),
              ),
            ),
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left, color: AppTheme.ink),
            ),
            IconButton(
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right, color: AppTheme.ink),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Días de la semana
        Row(
          children: _weekLabels
              .map((l) => Expanded(
                    child: Center(
                      child: Text(l,
                          style: AppTheme.subtitleFont(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.inkMuted)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        // Rejilla de días
        ...List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final dayNum = row * 7 + col - offset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 48));
              }
              final date = DateTime(_month.year, _month.month, dayNum);
              final isSelected = _sameDay(date, _selectedDay);
              final isToday = _sameDay(date, now);
              final hasTrips = byDay.containsKey(VoyDate.dayKey(date));

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = date),
                  child: Container(
                    height: 48,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected ? primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: (!isSelected && isToday)
                          ? Border.all(color: primary, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: AppTheme.bodyFont(
                            fontSize: 14,
                            fontWeight: (isSelected || isToday)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? AppTheme.pureWhite : AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasTrips
                                ? (isSelected ? AppTheme.pureWhite : primary)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          VoyDate.dayHeader(_selectedDay, now: now),
          style: AppTheme.subtitleFont(
              fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.ink),
        ),
        const SizedBox(height: 10),
        if (selectedTrips.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Sin viajes ese día',
                  style: AppTheme.bodyFont(color: AppTheme.inkMuted)),
            ),
          )
        else
          ...selectedTrips.map((t) => _CalendarTripRow(
                item: t,
                onTap: () => widget.onOpenTrip(t),
              )),
      ],
    );
  }
}

class _CalendarTripRow extends StatelessWidget {
  final TripBoardItem item;
  final VoidCallback onTap;
  const _CalendarTripRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.subtleGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Row(
          children: [
            Text(VoyDate.time(item.scheduleTime),
                style: AppTheme.titleFont(fontSize: 16, color: primary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.origin} → ${item.destination}',
                      style: AppTheme.subtitleFont(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    item.isOffer
                        ? 'Ofrezco · ${item.availableSeats} libres'
                        : 'Busco ${item.seats}',
                    style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _AgendaTile extends StatelessWidget {
  final TripBoardItem item;
  final String uid;
  final bool isHistory;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onCancelSingle;
  final VoidCallback? onCancelSeries;

  const _AgendaTile({
    required this.item,
    required this.uid,
    this.isHistory = false,
    required this.onOpen,
    this.onEdit,
    this.onCancelSingle,
    this.onCancelSeries,
  });

  bool get _isOwnerPending => item.creatorUid == uid && item.status == 'PENDING';
  bool get _isSeries => item.recurringGroupId != null;
  bool get _canTrack =>
      item.status == 'ACCEPTED' || item.status == 'EN_ROUTE' || item.status == 'FULL';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final faded = isHistory || item.status == 'CANCELLED';

    return Opacity(
      opacity: faded ? 0.65 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (_canTrack || isHistory) ? onOpen : null,
            child: Container(
              // Franja lateral con el color del estado: se distingue de un
              // vistazo qué está esperando, confirmado o cancelado.
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: _statusColor(item.status), width: 4),
                ),
              ),
              child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hora
                  Column(
                    children: [
                      Text(VoyDate.time(item.scheduleTime),
                          style: AppTheme.titleFont(fontSize: 22, color: AppTheme.ink)),
                      Text(
                        _weekday(item.scheduleTime),
                        style: AppTheme.subtitleFont(
                            fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.inkMuted),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 52, color: AppTheme.outline),
                  const SizedBox(width: 14),
                  // Detalle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _RolePill(isOffer: item.isOffer),
                            const SizedBox(width: 6),
                            _StatusPill(status: item.status),
                            if (_isSeries) ...[
                              const SizedBox(width: 6),
                              const _SeriesPill(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item.origin} → ${item.destination}',
                          style: AppTheme.subtitleFont(
                              fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.isOffer ? item.exactPickup : item.exactDropoff,
                          style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(item.isOffer ? Icons.event_seat : Icons.groups_outlined,
                                size: 14, color: primary),
                            const SizedBox(width: 4),
                            Text(
                              item.isOffer
                                  ? '${item.availableSeats} libres'
                                  : 'Busca ${item.seats}',
                              style: AppTheme.bodyFont(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.payments_outlined, size: 14, color: primary),
                            const SizedBox(width: 4),
                            Text('\$${item.price?.toStringAsFixed(2) ?? '0.00'}',
                                style: AppTheme.bodyFont(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Menú de acciones
                  if (!isHistory) _buildMenu(context),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final actions = <PopupMenuEntry<String>>[];
    if (_canTrack) {
      actions.add(const PopupMenuItem(value: 'open', child: Text('Abrir seguimiento')));
    }
    if (_isOwnerPending) {
      actions.add(const PopupMenuItem(value: 'edit', child: Text('Editar viaje')));
      actions.add(const PopupMenuItem(value: 'cancel', child: Text('Cancelar viaje')));
      if (_isSeries) {
        actions.add(const PopupMenuItem(value: 'cancelSeries', child: Text('Cancelar serie')));
      }
    }
    if (actions.isEmpty) return const SizedBox(width: 8);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppTheme.inkMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) {
        switch (v) {
          case 'open':
            onOpen();
            break;
          case 'edit':
            onEdit?.call();
            break;
          case 'cancel':
            onCancelSingle?.call();
            break;
          case 'cancelSeries':
            onCancelSeries?.call();
            break;
        }
      },
      itemBuilder: (_) => actions,
    );
  }

  static String _weekday(DateTime dt) {
    const w = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return w[dt.weekday - 1];
  }
}

class _RolePill extends StatelessWidget {
  final bool isOffer;
  const _RolePill({required this.isOffer});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOffer ? Icons.directions_car : Icons.person_pin_circle_outlined,
              size: 12, color: primary),
          const SizedBox(width: 4),
          Text(isOffer ? 'Ofrezco' : 'Busco',
              style: AppTheme.subtitleFont(
                  fontSize: 10, fontWeight: FontWeight.w600, color: primary, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

/// Color semántico por estado del viaje (píldora + franja lateral).
Color _statusColor(String status) {
  switch (status) {
    case 'ACCEPTED':
    case 'COMPLETED':
      return AppTheme.successGreen;
    case 'EN_ROUTE':
      return AppTheme.purpleDarkest;
    case 'FULL':
      return const Color(0xFFB26A00);
    case 'CANCELLED':
      return AppTheme.standardRed;
    default:
      return AppTheme.inkMuted; // PENDING: esperando
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    late String text;
    // Los estados "vivos" van en píldora sólida para saltar a la vista.
    bool solid = true;
    switch (status) {
      case 'ACCEPTED':
        text = 'Aceptado ✓';
        break;
      case 'EN_ROUTE':
        text = 'En camino';
        break;
      case 'FULL':
        text = 'Lleno';
        break;
      case 'CANCELLED':
        text = 'Cancelado';
        break;
      case 'COMPLETED':
        text = 'Completado';
        solid = false;
        break;
      default:
        text = 'Esperando';
        solid = false;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: AppTheme.subtitleFont(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: solid ? Colors.white : color,
              letterSpacing: 0.3)),
    );
  }
}

class _SeriesPill extends StatelessWidget {
  const _SeriesPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.subtleGray,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 11, color: AppTheme.inkMuted),
          const SizedBox(width: 3),
          Text('Serie',
              style: AppTheme.subtitleFont(
                  fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.inkMuted)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: primary.withOpacity(0.06), shape: BoxShape.circle),
              child: Icon(icon, size: 60, color: primary.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style: AppTheme.titleFont(fontSize: 20, color: AppTheme.ink)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.inkMuted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
