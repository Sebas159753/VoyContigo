import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/features/trips/data/trip_repository.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/core/services/notification_service.dart';
import 'package:voycontigo/core/utils/date_format.dart';

class Hub {
  final String name;
  final double lat;
  final double lng;
  const Hub(this.name, this.lat, this.lng);
}

const List<Hub> machachiHubs = [
  Hub('Parque Central', -0.5097, -78.5672),
  Hub('El Aki', -0.5100, -78.5650),
  Hub('Redondel Norte', -0.5000, -78.5670),
];

const List<Hub> quitoHubs = [
  Hub('El Trébol', -0.2289, -78.5028),
  Hub('U. Católica', -0.2104, -78.4907),
  Hub('Quicentro Sur', -0.28477, -78.54487),
  Hub('La Marín', -0.2236, -78.5042),
];

class PublishScreen extends ConsumerStatefulWidget {
  final String type; // 'oferta' o 'demanda'
  final String? tripId;

  const PublishScreen({super.key, required this.type, this.tripId});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  bool get _isOffer => widget.type == 'oferta';

  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  late final TextEditingController _carModelCtrl;
  late final TextEditingController _carPlateCtrl;
  
  double? _originLat;
  double? _originLng;
  double? _destLat;
  double? _destLng;
  
  String _targetCity = 'Quito';
  bool _isOutbound = true; // true: Machachi -> Target, false: Target -> Machachi
  

  bool _womenOnly = false;
  List<String> _selectedStops = [];
  final List<String> _availableStops = const ['Alóag', 'Tambillo', 'Guamaní', 'Quitumbe', 'San Bartolo', 'Villaflora'];
  DateTime _selectedTime = DateTime.now().add(const Duration(hours: 1));
  bool _isRecurring = false;
  // Días de repetición: 1=Lun ... 7=Dom. Por defecto Lunes a Viernes.
  Set<int> _weekdays = {1, 2, 3, 4, 5};
  // Ventana máxima de generación: 2 semanas.
  static const int _recurringHorizonDays = 14;

  @override
  void initState() {
    super.initState();
    final appState = ref.read(appStateProvider);
    _carModelCtrl = TextEditingController(text: appState.carModel);
    _carPlateCtrl = TextEditingController(text: appState.carPlate);
    
    if (widget.tripId != null) {
      _loadTripData();
    } else {
      _loadCurrentLocation();
    }
  }

  Future<void> _loadCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    if (mounted) {
      setState(() {
        _originCtrl.text = "Obteniendo ubicación...";
      });
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _originLat = position.latitude;
          _originLng = position.longitude;
          
          // Auto-detect direction:
          // Latitudes south of -0.35 are closer to Machachi (approx -0.51).
          // Latitudes north of -0.35 are closer to Quito (approx -0.22).
          if (position.latitude < -0.35) {
            _isOutbound = true; // Machachi ➔ Quito
          } else {
            _isOutbound = false; // Quito ➔ Machachi
          }
          _originCtrl.text = "Buscando nombre de calle...";
        });
      }
      
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'VoyContigoApp'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final street = data['address']?['road'] ?? data['address']?['neighbourhood'] ?? data['display_name'];
        if (street != null && mounted) {
          setState(() {
            _originCtrl.text = street.toString();
          });
        }
      }
    } catch(e) {
      if (mounted && (_originCtrl.text == "Buscando nombre de calle..." || _originCtrl.text == "Obteniendo ubicación...")) {
         setState(() {
           _originCtrl.text = ""; // Limpiar si falla
         });
      }
    }
  }

  Future<void> _loadTripData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('trips').doc(widget.tripId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          if (data['origin'] == 'Machachi') {
            _isOutbound = true;
            _targetCity = data['destination'] ?? 'Quito';
          } else {
            _isOutbound = false;
            _targetCity = data['origin'] ?? 'Quito';
          }
          
          _targetCity = 'Quito';

          _originCtrl.text = data['exactPickup'] ?? '';
          _originLat = data['originLat'] as double?;
          _originLng = data['originLng'] as double?;
          
          _destCtrl.text = data['exactDropoff'] ?? '';
          _destLat = data['destLat'] as double?;
          _destLng = data['destLng'] as double?;
          
          _seatsCtrl.text = (data['seats'] ?? 1).toString();
          _priceCtrl.text = (data['price'] ?? 0.0).toStringAsFixed(2);
          
          if (data['scheduleTime'] != null) {
             _selectedTime = DateTime.parse(data['scheduleTime'] as String);
          }
          
          _womenOnly = data['womenOnly'] ?? false;
          _selectedStops = data['stops'] != null ? List<String>.from(data['stops']) : [];
          
          if (_isOffer) {
             _carModelCtrl.text = data['carModel'] ?? '';
             _carPlateCtrl.text = data['carPlate'] ?? '';
          }
        });
      }
    } catch(e) {
      // ignore error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _seatsCtrl.dispose();
    _priceCtrl.dispose();
    _carModelCtrl.dispose();
    _carPlateCtrl.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  Future<String?> _showPhoneRequiredDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Celular Requerido', style: AppTheme.bodyFont(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Por motivos de seguridad y coordinación, los demás usuarios necesitan poder contactarte durante el viaje.',
              style: AppTheme.bodyFont(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Número de Celular (ej: 0987654321)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          FilledButton(
            onPressed: () async {
              final phone = controller.text.trim();
              if (phone.isEmpty || phone.length < 7) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Por favor, ingresa un número celular válido')),
                );
                return;
              }
              await ref.read(appStateProvider.notifier).updateEmergencyPhone(phone);
              if (ctx.mounted) {
                Navigator.pop(ctx, phone);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Guardar y Continuar'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final notifier = ref.read(appStateProvider.notifier);

    final appState = ref.read(appStateProvider);
    if (appState.emergencyPhone.isEmpty) {
      final newPhone = await _showPhoneRequiredDialog();
      if (newPhone == null || newPhone.isEmpty) {
        return;
      }
    }

    if (_originCtrl.text.isEmpty || _destCtrl.text.isEmpty || _seatsCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena los campos principales')),
      );
      return;
    }

    if (_originLat == null || _originLng == null || _destLat == null || _destLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona las ubicaciones exactas usando el mapa')),
      );
      return;
    }

    if (_isOffer) {
      if (_priceCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes indicar un precio por asiento')),
        );
        return;
      }
      if (_carModelCtrl.text.trim().isEmpty || _carPlateCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes indicar el modelo y la placa de tu vehículo')),
        );
        return;
      }

      final rawPlate = _carPlateCtrl.text.trim().toUpperCase();
      String cleanPlate = rawPlate.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      String formattedPlate = rawPlate;
      
      if (cleanPlate.length >= 6 && cleanPlate.length <= 7) {
        final letters = cleanPlate.substring(0, 3);
        final numbers = cleanPlate.substring(3);
        if (RegExp(r'^[A-Z]{3}$').hasMatch(letters) && RegExp(r'^\d{3,4}$').hasMatch(numbers)) {
          formattedPlate = '$letters-$numbers';
          _carPlateCtrl.text = formattedPlate;
        }
      }

      final plateRegex = RegExp(r'^[A-Z]{3}-\d{3,4}$');
      if (!plateRegex.hasMatch(formattedPlate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Placa inválida. Debe tener el formato ecuatoriano (ej: PBA-1234 o ABC-123)')),
        );
        return;
      }
    }

    int seats = int.tryParse(_seatsCtrl.text) ?? 0;
    double price = double.tryParse(_priceCtrl.text) ?? 0.0;

    if (seats <= 0 || seats > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad de asientos debe estar entre 1 y 6')),
      );
      return;
    }

    if (_isOffer && (price < 0.5 || price > 20.0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El precio por asiento debe estar entre \$0.50 y \$20.00')),
      );
      return;
    }

    if (widget.tripId == null && _isRecurring && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un día para repetir el viaje')),
      );
      return;
    }

    // La salida debe ser futura (evita viajes que nunca aparecen en el mercado).
    final bool recurringCreate = widget.tripId == null && _isRecurring;
    if (recurringCreate) {
      if (_previewDates().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay fechas futuras para los días elegidos. Ajusta la hora o el día de inicio.')),
        );
        return;
      }
    } else if (!_selectedTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La hora de salida debe ser en el futuro')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(appStateProvider).userName;
      final currentUid = ref.read(appStateProvider).uid;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      final currentRating = (userDoc.data()?['rating'] as num?)?.toDouble() ?? 5.0;

      final baseTripData = {
        'creatorUid': currentUid,
        'userName': currentUser,
        'isOffer': _isOffer,
        'origin': _isOutbound ? 'Machachi' : _targetCity, 
        'exactPickup': _originCtrl.text,
        'originLat': _originLat,
        'originLng': _originLng,
        'stops': _isOffer ? _selectedStops : [],
        'destination': _isOutbound ? _targetCity : 'Machachi',
        'exactDropoff': _destCtrl.text,
        'destLat': _destLat,
        'destLng': _destLng,
        'seats': int.tryParse(_seatsCtrl.text) ?? 1,
        'availableSeats': int.tryParse(_seatsCtrl.text) ?? 1,
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
        'rating': currentRating,
        'carModel': _isOffer ? _carModelCtrl.text.trim() : null,
        'carColor': _isOffer ? '' : null,
        'carPlate': _isOffer ? _carPlateCtrl.text.trim().toUpperCase() : null,
        'status': 'PENDING',
        'womenOnly': _womenOnly,
        'isCreatorVerified': ref.read(appStateProvider).isVerified,
        'passengers': [],
        'passengerUids': [],
      };

      final String routeLabel =
          '${baseTripData['origin']} ➔ ${baseTripData['destination']}';
      final notif = NotificationService();

      if (widget.tripId != null) {
        baseTripData['scheduleTime'] = _selectedTime.toIso8601String();
        await ref.read(tripRepositoryProvider).updateTripData(widget.tripId!, baseTripData);
        // Reprogramar el recordatorio de esta ocurrencia.
        await notif.scheduleTripReminder(TripReminder(
          tripId: widget.tripId!,
          scheduleTime: _selectedTime,
          routeLabel: routeLabel,
        ));
      } else {
        final List<Map<String, dynamic>> batchTrips = [];
        final String recurringGroupId = DateTime.now().millisecondsSinceEpoch.toString();

        final List<DateTime> targetDates = _previewDates();

        for (var date in targetDates) {
          final tripData = Map<String, dynamic>.from(baseTripData);
          tripData['scheduleTime'] = date.toIso8601String();
          tripData['createdAt'] = FieldValue.serverTimestamp();
          if (targetDates.length > 1) {
            tripData['recurringGroupId'] = recurringGroupId;
          }
          batchTrips.add(tripData);
        }

        List<String> createdIds;
        if (batchTrips.length == 1) {
          createdIds = [await ref.read(tripRepositoryProvider).addTrip(batchTrips.first)];
        } else {
          createdIds = await ref.read(tripRepositoryProvider).addTripsBatch(batchTrips);
        }

        // Programar un recordatorio local por cada ocurrencia creada.
        for (int i = 0; i < createdIds.length && i < targetDates.length; i++) {
          await notif.scheduleTripReminder(TripReminder(
            tripId: createdIds[i],
            scheduleTime: targetDates[i],
            routeLabel: routeLabel,
          ));
        }
      }

      // Descontar uso localmente solo si es conductor
      notifier.recordUsage(isDriverAction: _isOffer);

      if (_isOffer) {
        notifier.updateVehicle(_carModelCtrl.text.trim(), _carPlateCtrl.text.trim().toUpperCase());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.tripId != null ? 'Viaje actualizado correctamente' : (_isOffer ? 'Viaje publicado' : 'Solicitud de viaje publicada')),
            backgroundColor: Colors.black,
          )
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openMapPicker(TextEditingController ctrl, bool isOrigin) async {
    final result = await context.push<Map<String, dynamic>>('/map-picker');
    if (result != null) {
      ctrl.text = result['address'] as String;
      setState(() {
        if (isOrigin) {
          _originLat = result['lat'] as double;
          _originLng = result['lng'] as double;
        } else {
          _destLat = result['lat'] as double;
          _destLng = result['lng'] as double;
        }
      });
    }
  }

  Widget _buildFrequencySelector() {
    final primary = Theme.of(context).colorScheme.primary;

    Widget modeChip(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? primary : AppTheme.subtleGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? primary : AppTheme.outline),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTheme.subtitleFont(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.pureWhite : AppTheme.inkMuted,
              ),
            ),
          ),
        ),
      );
    }

    const dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            modeChip('Un solo viaje', !_isRecurring, () => setState(() => _isRecurring = false)),
            const SizedBox(width: 10),
            modeChip('Se repite', _isRecurring, () => setState(() => _isRecurring = true)),
          ],
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 18),
          Text('¿Qué días se repite?',
              style: AppTheme.bodyFont(
                  color: AppTheme.inkMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetChip('Lunes a Viernes', const {1, 2, 3, 4, 5}),
              _presetChip('Todos los días', const {1, 2, 3, 4, 5, 6, 7}),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final wd = i + 1;
              final selected = _weekdays.contains(wd);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _weekdays.remove(wd);
                  } else {
                    _weekdays.add(wd);
                  }
                }),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? primary : AppTheme.subtleGray,
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? primary : AppTheme.outline),
                  ),
                  child: Text(
                    dayLabels[i],
                    style: AppTheme.subtitleFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppTheme.pureWhite : AppTheme.inkMuted,
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_weekdays.isEmpty) ...[
            const SizedBox(height: 8),
            Text('Selecciona al menos un día.',
                style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.standardRed)),
          ],
        ],
      ],
    );
  }

  Widget _presetChip(String label, Set<int> days) {
    final primary = Theme.of(context).colorScheme.primary;
    final active = _weekdays.length == days.length && _weekdays.containsAll(days);
    return ChoiceChip(
      label: Text(label),
      selected: active,
      showCheckmark: false,
      onSelected: (_) => setState(() => _weekdays = {...days}),
      labelStyle: AppTheme.subtitleFont(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: active ? primary : AppTheme.inkMuted,
      ),
      selectedColor: primary.withOpacity(0.12),
      backgroundColor: AppTheme.subtleGray,
      side: BorderSide(color: active ? primary : AppTheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    // Los pickers heredan el tema morado de la marca (AppTheme).
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedTime.isBefore(DateTime.now()) ? DateTime.now() : _selectedTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'Elige el día de salida',
    );

    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedTime),
        helpText: 'Elige la hora de salida',
      );

      if (pickedTime != null) {
        setState(() {
          _selectedTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Widget _buildDateTimePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha y Hora de Salida',
          style: AppTheme.bodyFont(
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDateTime(context),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.black54),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    VoyDate.shortDateTime(_selectedTime),
                    style: AppTheme.subtitleFont(
                      color: AppTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.inkMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Campo de programación que se adapta a la frecuencia elegida:
  /// - "Solo este viaje" (o edición): fecha + hora exactas.
  /// - Recurrente: solo la HORA + desde qué día, con vista previa de los días.
  Widget _buildScheduleInputs() {
    final bool isRecurring = widget.tripId == null && _isRecurring;
    if (!isRecurring) {
      return _buildDateTimePickerField();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPickerTile(
                label: 'Hora de salida',
                icon: Icons.access_time,
                value: VoyDate.time(_selectedTime),
                onTap: _selectTimeOnly,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPickerTile(
                label: 'Empezar desde',
                icon: Icons.event,
                value: VoyDate.dayShort(_selectedTime),
                onTap: _selectStartDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildOccurrencePreview(),
      ],
    );
  }

  Widget _buildPickerTile({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodyFont(
              color: AppTheme.inkMuted, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.subtleGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.inkMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: AppTheme.subtitleFont(
                        color: AppTheme.ink, fontSize: 15, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTimeOnly() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
      helpText: 'Hora de salida',
    );
    if (t != null) {
      setState(() {
        _selectedTime = DateTime(
            _selectedTime.year, _selectedTime.month, _selectedTime.day, t.hour, t.minute);
      });
    }
  }

  Future<void> _selectStartDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedTime.isBefore(DateTime.now()) ? DateTime.now() : _selectedTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'Empezar desde',
    );
    if (d != null) {
      setState(() {
        _selectedTime = DateTime(
            d.year, d.month, d.day, _selectedTime.hour, _selectedTime.minute);
      });
    }
  }

  /// Fechas que se crearán: en las próximas 2 semanas, los días elegidos,
  /// a partir de "Empezar desde" ([_selectedTime]).
  List<DateTime> _previewDates() {
    if (!_isRecurring) return [_selectedTime];
    final List<DateTime> dates = [];
    final now = DateTime.now();
    for (int i = 0; i < _recurringHorizonDays; i++) {
      final d = _selectedTime.add(Duration(days: i));
      // Solo días elegidos que aún no hayan pasado (evita ocurrencias fantasma).
      if (_weekdays.contains(d.weekday) && d.isAfter(now)) dates.add(d);
    }
    return dates;
  }

  Widget _buildOccurrencePreview() {
    final primary = Theme.of(context).colorScheme.primary;
    final dates = _previewDates();
    final shown = dates.take(6).map((d) => VoyDate.dayShort(d)).join('   ·   ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_repeat, size: 16, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Se crearán ${dates.length} viajes a las ${VoyDate.time(_selectedTime)}',
                  style: AppTheme.subtitleFont(
                      fontSize: 14, fontWeight: FontWeight.w600, color: primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            dates.length > 6 ? '$shown   …' : shown,
            style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkMuted, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.tripId != null ? 'Modificar Viaje' : (_isOffer ? 'Ofrecer Viaje' : 'Solicitar Viaje')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.tripId != null ? 'Edita tu viaje' : (_isOffer ? 'Publica tu ruta' : 'Busca un viaje'),
              style: AppTheme.titleFont(
                color: AppTheme.ink,
                fontSize: 30,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isOffer ? 'Ingresa los detalles para que otros puedan reservar un asiento.' : 'Dile a los conductores dónde estás y a dónde vas.',
              style: AppTheme.bodyFont(
                color: Colors.black54,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionTitle('Ruta (Trayecto Fijo)'),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!_isOutbound) {
                          setState(() {
                            _isOutbound = true;
                            _originCtrl.clear();
                            _originLat = null;
                            _originLng = null;
                            _destCtrl.clear();
                            _destLat = null;
                            _destLng = null;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _isOutbound ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isOutbound 
                              ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_forward,
                              color: _isOutbound ? Colors.white : Colors.black54,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Machachi ➔ Quito',
                              textAlign: TextAlign.center,
                              style: AppTheme.bodyFont(
                                color: _isOutbound ? Colors.white : Colors.black87,
                                fontWeight: _isOutbound ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_isOutbound) {
                          setState(() {
                            _isOutbound = false;
                            _originCtrl.clear();
                            _originLat = null;
                            _originLng = null;
                            _destCtrl.clear();
                            _destLat = null;
                            _destLng = null;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: !_isOutbound ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: !_isOutbound 
                              ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_back,
                              color: !_isOutbound ? Colors.white : Colors.black54,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quito ➔ Machachi',
                              textAlign: TextAlign.center,
                              style: AppTheme.bodyFont(
                                color: !_isOutbound ? Colors.white : Colors.black87,
                                fontWeight: !_isOutbound ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Ubicaciones'),
            const SizedBox(height: 16),
            _buildMapInputField(
              _isOffer ? 'Punto de encuentro' : 'Dónde puedes subirte', 
              _originCtrl, 
              true,
              _isOutbound ? machachiHubs : (_targetCity == 'Quito' ? quitoHubs : []),
            ),
            const SizedBox(height: 16),
            _buildMapInputField(
              _isOffer ? 'Punto de bajada' : 'Dónde te bajas', 
              _destCtrl, 
              false,
              !_isOutbound ? machachiHubs : (_targetCity == 'Quito' ? quitoHubs : []),
            ),
            const SizedBox(height: 32),

            _buildSectionTitle('Detalles'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInputField(_isOffer ? 'Asientos' : 'Pasajeros', _seatsCtrl, isNumber: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildPriceField(_isOffer ? 'Precio x Asiento (\$)' : 'Oferta de Tarifa (\$)', _priceCtrl)),
              ],
            ),
            const SizedBox(height: 28),
            _buildSectionTitle('¿Cuándo viajas?'),
            const SizedBox(height: 16),
            if (widget.tripId == null) ...[
              _buildFrequencySelector(),
              const SizedBox(height: 20),
            ],
            _buildScheduleInputs(),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.pink.withOpacity(0.3)),
              ),
              child: SwitchListTile(
                title: Row(
                  children: [
                    const Icon(Icons.female, color: Colors.pink),
                    const SizedBox(width: 8),
                    Text('Solo para Mujeres', style: AppTheme.bodyFont(fontWeight: FontWeight.bold, color: Colors.pink[800])),
                  ],
                ),
                subtitle: Text(
                  'Este viaje será exclusivo para conductoras y pasajeras mujeres',
                  style: AppTheme.bodyFont(fontSize: 12, color: Colors.pink[700]),
                ),
                value: _womenOnly,
                activeColor: Colors.pink,
                onChanged: (val) => setState(() => _womenOnly = val),
              ),
            ),

            if (_isOffer) ...[
              const SizedBox(height: 32),
              _buildSectionTitle('Paradas Intermedias (Opcional)'),
              const SizedBox(height: 8),
              Text('Selecciona por dónde pasarás para recoger más pasajeros', style: AppTheme.bodyFont(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableStops.map((stop) {
                  final isSelected = _selectedStops.contains(stop);
                  return FilterChip(
                    label: Text(stop, style: AppTheme.bodyFont(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedStops.add(stop);
                        } else {
                          _selectedStops.remove(stop);
                        }
                      });
                    },
                    selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black12)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Tu Vehículo'),
              const SizedBox(height: 16),
              _buildInputField('Modelo y color (ej. Kia Picanto Rojo)', _carModelCtrl),
              const SizedBox(height: 12),
              _buildInputField('Placa (Ecuador, ej. PBA-1234)', _carPlateCtrl),
            ],

            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.tripId != null ? 'Guardar Cambios' : (_isOffer ? 'Publicar Viaje' : 'Solicitar Viaje')),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(text, style: AppTheme.subtitleFont(color: AppTheme.ink, fontWeight: FontWeight.w600, fontSize: 17));
  }

  Widget _buildMapInputField(String label, TextEditingController controller, bool isOrigin, List<Hub> hubs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodyFont(
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () => _openMapPicker(controller, isOrigin),
          style: AppTheme.bodyFont(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: isOrigin ? 'Establecer punto de partida' : 'Establecer destino',
            prefixIcon: Icon(
              isOrigin ? Icons.my_location : Icons.location_on, 
              color: isOrigin ? AppTheme.purpleDarkest : AppTheme.purpleDark,
            ),
            suffixIcon: const Icon(Icons.map_outlined, color: Colors.black54),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (hubs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Puntos de encuentro sugeridos:',
            style: AppTheme.bodyFont(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hubs.map((hub) {
              final isSelected = controller.text == hub.name;
              return GestureDetector(
                onTap: () {
                  controller.text = hub.name;
                  setState(() {
                    if (isOrigin) {
                      _originLat = hub.lat;
                      _originLng = hub.lng;
                    } else {
                      _destLat = hub.lat;
                      _destLng = hub.lng;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined, 
                        size: 14, 
                        color: isSelected ? Colors.white : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hub.name,
                        style: AppTheme.bodyFont(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceField(String label, TextEditingController controller) {
    if (controller.text.isEmpty) controller.text = "1.00";
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: Colors.black87,
          onPressed: () {
            double current = double.tryParse(controller.text) ?? 1.0;
            if (current >= 1.0) {
              controller.text = (current - 0.5).toStringAsFixed(2);
            }
          },
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: Colors.black87,
          onPressed: () {
            double current = double.tryParse(controller.text) ?? 1.0;
            controller.text = (current + 0.5).toStringAsFixed(2);
          },
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(labelText: label),
    );
  }
}
