import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:voycontigo/core/config/app_config.dart';

// Definimos el estado global extendido para manejar la sesión en memoria (quitando los viajes locales).
class AppState {
  final int freeUses; // Contador de usos (max 3)
  final bool isPremium;
  final String lastResetMonth;
  
  // Usuario Autenticado en Memoria
  final String uid;
  final String userName;
  final String userEmail;
  final String carModel;
  final String carPlate;
  final bool isVerified;
  final bool isSubscribed;
  final String emergencyPhone;
  final int completedTrips;
  final List<String> redeemedRewards;

  AppState({
    required this.freeUses, 
    this.isPremium = false,
    this.lastResetMonth = '',
    this.uid = '',
    this.userName = 'Invitado',
    this.userEmail = 'invitado@mail.com',
    this.carModel = '',
    this.carPlate = '',
    this.isVerified = false,
    this.isSubscribed = false,
    this.emergencyPhone = '',
    this.completedTrips = 0,
    this.redeemedRewards = const [],
  });

  AppState copyWith({
    int? freeUses, 
    bool? isPremium,
    String? lastResetMonth,
    String? uid,
    String? userName,
    String? userEmail,
    String? carModel,
    String? carPlate,
    bool? isVerified,
    bool? isSubscribed,
    String? emergencyPhone,
    int? completedTrips,
    List<String>? redeemedRewards,
  }) {
    return AppState(
      freeUses: freeUses ?? this.freeUses,
      isPremium: isPremium ?? this.isPremium,
      lastResetMonth: lastResetMonth ?? this.lastResetMonth,
      uid: uid ?? this.uid,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      carModel: carModel ?? this.carModel,
      carPlate: carPlate ?? this.carPlate,
      isVerified: isVerified ?? this.isVerified,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      completedTrips: completedTrips ?? this.completedTrips,
      redeemedRewards: redeemedRewards ?? this.redeemedRewards,
    );
  }
}

final appStateProvider = StateNotifierProvider<AppNotifier, AppState>((ref) {
  return AppNotifier();
});

class AppNotifier extends StateNotifier<AppState> {
  Duration _timeOffset = Duration.zero;

  AppNotifier() : super(AppState(
    freeUses: 0,
  )) {
    _syncServerTime();
  }

  Future<void> _syncServerTime() async {
    try {
      // Intentamos sincronizar con un servidor de tiempo público
      final response = await http.get(Uri.parse('http://worldtimeapi.org/api/timezone/Etc/UTC')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final serverTime = DateTime.parse(data['utc_datetime']);
        _timeOffset = serverTime.difference(DateTime.now().toUtc());
      }
    } catch (e) {
      print('Time Sync Error: $e');
    }
  }

  DateTime get _secureNow => DateTime.now().add(_timeOffset);

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  void login(String uid, String name, String email, {
    int freeUses = 0, 
    bool isPremium = false, 
    String lastResetMonth = '',
    String carModel = '',
    String carPlate = '',
    bool isVerified = false,
    bool isSubscribed = false,
    String emergencyPhone = '',
    int completedTrips = 0,
  }) {
    final currentYearMonth = "${_secureNow.year}-${_secureNow.month.toString().padLeft(2, '0')}";
    int finalFreeUses = freeUses;
    String finalResetMonth = lastResetMonth;
    
    if (uid.isNotEmpty && lastResetMonth.isNotEmpty && lastResetMonth != currentYearMonth) {
      finalFreeUses = 0;
      finalResetMonth = currentYearMonth;
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'freeUses': 0,
        'lastResetMonth': currentYearMonth,
      }).catchError((_) {});
    } else if (uid.isNotEmpty && lastResetMonth.isEmpty) {
      finalResetMonth = currentYearMonth;
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastResetMonth': currentYearMonth,
      }).catchError((_) {});
    }
    
    state = state.copyWith(
      uid: uid, 
      userName: name, 
      userEmail: email, 
      freeUses: finalFreeUses, 
      isPremium: isPremium,
      lastResetMonth: finalResetMonth,
      carModel: carModel,
      carPlate: carPlate,
      isVerified: isVerified,
      isSubscribed: isSubscribed,
      emergencyPhone: emergencyPhone,
      completedTrips: completedTrips,
    );

    // Cancelar cualquier escucha previa de Firestore
    _userSubscription?.cancel();

    // Escucha en tiempo real de Firestore para el usuario
    if (uid.isNotEmpty) {
      _userSubscription = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) {
        if (doc.exists) {
          final data = doc.data()!;
          state = state.copyWith(
            userName: data['name'] ?? state.userName,
            userEmail: data['email'] ?? state.userEmail,
            freeUses: data['freeUses'] ?? state.freeUses,
            isPremium: data['isPremium'] ?? state.isPremium,
            isSubscribed: data['isSubscribed'] ?? state.isSubscribed,
            lastResetMonth: data['lastResetMonth'] ?? state.lastResetMonth,
            carModel: data['carModel'] ?? state.carModel,
            carPlate: data['carPlate'] ?? state.carPlate,
            isVerified: data['isVerified'] ?? state.isVerified,
            emergencyPhone: data['emergencyPhone'] ?? state.emergencyPhone,
            completedTrips: data['completedTrips'] ?? state.completedTrips,
            redeemedRewards: List<String>.from(data['redeemedRewards'] ?? []),
          );
        }
      });
    }
  }

  Future<void> updateName(String name) async {
    if (state.uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(state.uid).update({
        'name': name,
      });
    }
    state = state.copyWith(userName: name);
  }

  Future<void> updateEmergencyPhone(String phone) async {
    if (state.uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(state.uid).update({
        'emergencyPhone': phone,
      });
    }
    state = state.copyWith(emergencyPhone: phone);
  }

  Future<void> updateVehicle(String carModel, String carPlate) async {
    if (state.uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(state.uid).update({
        'carModel': carModel,
        'carPlate': carPlate,
      });
    }
    state = state.copyWith(carModel: carModel, carPlate: carPlate);
  }

  Future<void> submitVerification({
    required String licenseNumber,
    required String carPlate,
    required String carModel,
  }) async {
    if (state.uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(state.uid).update({
        'isVerified': true,
        'licenseNumber': licenseNumber,
        'carPlate': carPlate,
        'carModel': carModel,
      });
    }
    state = state.copyWith(
      isVerified: true,
      carPlate: carPlate,
      carModel: carModel,
    );
  }

  Future<void> _resetFreeUses(String currentYearMonth) async {
    if (state.uid.isEmpty) return;
    await FirebaseFirestore.instance.collection('users').doc(state.uid).update({
      'freeUses': 0,
      'lastResetMonth': currentYearMonth,
    });
    state = state.copyWith(freeUses: 0, lastResetMonth: currentYearMonth);
  }

  bool canTransact({bool isDriverAction = true}) {
    if (!AppConfig.isMonetizationEnabled) return true; // Modo 100% gratis activo
    
    if (!isDriverAction) return true; // Los pasajeros tienen acceso libre
    if (state.isSubscribed || state.isPremium) return true;
    
    final currentYearMonth = "${_secureNow.year}-${_secureNow.month.toString().padLeft(2, '0')}";
    if (state.lastResetMonth.isNotEmpty && state.lastResetMonth != currentYearMonth) {
      _resetFreeUses(currentYearMonth);
      return true;
    }
    
    return state.freeUses < 3;
  }

  Future<void> recordUsage({bool isDriverAction = true}) async {
    if (!AppConfig.isMonetizationEnabled) return; // No registrar ni quemar usos en modo gratis
    
    if (!isDriverAction) return; // No consumir usos si es pasajero
    if (state.uid.isEmpty) return;
    
    final currentYearMonth = "${_secureNow.year}-${_secureNow.month.toString().padLeft(2, '0')}";
    int currentUses = state.freeUses;
    
    if (state.lastResetMonth.isNotEmpty && state.lastResetMonth != currentYearMonth) {
      currentUses = 0;
    }
    
    final newUses = currentUses + 1;
    
    // Persistir en Firestore
    await FirebaseFirestore.instance.collection('users').doc(state.uid).update({
      'freeUses': newUses,
      'lastResetMonth': currentYearMonth,
    });

    state = state.copyWith(freeUses: newUses, lastResetMonth: currentYearMonth);
  }

  Future<void> upgradeToPremium() async {
    if (state.uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(state.uid).update({
        'isPremium': true,
      });
    }
    state = state.copyWith(isPremium: true);
  }

  Future<void> upgradeToSubscribed() async {
    if (state.uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(state.uid).update({
        'isSubscribed': true,
      });
    }
    state = state.copyWith(isSubscribed: true);
  }

  void cancelSubscription() {
    state = state.copyWith(isSubscribed: false);
  }

  void acceptTrip(String id, {bool isDriverAction = true}) {
    recordUsage(isDriverAction: isDriverAction); 
    // Ahora actualizamos en Firestore
    FirebaseFirestore.instance.collection('trips').doc(id).update({
      'status': 'ACCEPTED',
      'acceptedByUid': state.uid,
      'acceptedByName': state.userName,
    });
  }

  void logout() {
    _userSubscription?.cancel();
    _userSubscription = null;
    state = AppState(freeUses: 0);
  }

  Future<void> redeemReward(String rewardId) async {
    if (state.uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(state.uid).update({
        'redeemedRewards': FieldValue.arrayUnion([rewardId]),
      });
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}

// Proveedor dinámico para manejar la paginación del mercado
final marketLimitProvider = StateProvider<int>((ref) => 20);

// Proveedor para recordar el modo seleccionado en el tablero (pasajero o conductor)
final boardModeProvider = StateProvider<String>((ref) => 'pasajero');

// Helper para el mercado: Solo viajes pendientes y limitados dinámicamente
final marketTripsStreamProvider = StreamProvider<List<TripBoardItem>>((ref) {
  final limit = ref.watch(marketLimitProvider);
  return FirebaseFirestore.instance
      .collection('trips')
      .where('status', isEqualTo: 'PENDING')
      .limit(limit)
      .snapshots()
      .map((snapshot) {
    final now = DateTime.now();
    final list = snapshot.docs.map((doc) {
      try {
        return TripBoardItem.fromFirestore(doc.id, doc.data());
      } catch (e) {
        print('Error parsing trip in marketTripsStreamProvider: $e');
        return null;
      }
    }).where((trip) => trip != null && trip.scheduleTime.isAfter(now))
      .cast<TripBoardItem>()
      .toList();
      
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

final myTripsStreamProvider = StreamProvider<List<TripBoardItem>>((ref) {
  final uid = ref.watch(appStateProvider.select((s) => s.uid));
  if (uid.isEmpty) return Stream.value([]);
  
  final stream1 = FirebaseFirestore.instance.collection('trips')
      .where("creatorUid", isEqualTo: uid)
      .orderBy("createdAt", descending: true)
      .limit(20)
      .snapshots();
      
  final stream2 = FirebaseFirestore.instance.collection('trips')
      .where("acceptedByUid", isEqualTo: uid)
      .orderBy("createdAt", descending: true)
      .limit(20)
      .snapshots();
      
  final stream3 = FirebaseFirestore.instance.collection('trips')
      .where("passengerUids", arrayContains: uid)
      .orderBy("createdAt", descending: true)
      .limit(20)
      .snapshots();

  final controller = StreamController<List<TripBoardItem>>();
  
  List<QueryDocumentSnapshot> docs1 = [];
  List<QueryDocumentSnapshot> docs2 = [];
  List<QueryDocumentSnapshot> docs3 = [];
  
  void emitCombined() {
    final Map<String, Map<String, dynamic>> map = {};
    for (var doc in docs1) {
      map[doc.id] = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    }
    for (var doc in docs2) {
      map[doc.id] = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    }
    for (var doc in docs3) {
      map[doc.id] = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    }
    
    final list = map.values.map((data) {
      try {
        return TripBoardItem.fromFirestore(data['id'], data);
      } catch (e) {
        print('Error parsing trip in myTripsStreamProvider: $e');
        return null;
      }
    }).where((t) => t != null).cast<TripBoardItem>().toList();
    
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    controller.add(list);
  }

  final sub1 = stream1.listen((snap) {
    docs1 = snap.docs;
    emitCombined();
  });
  
  final sub2 = stream2.listen((snap) {
    docs2 = snap.docs;
    emitCombined();
  });

  final sub3 = stream3.listen((snap) {
    docs3 = snap.docs;
    emitCombined();
  });
  
  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    sub3.cancel();
    controller.close();
  });

  return controller.stream;
});

// Helper para escuchar las coincidencias desde Firestore
final matchesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(appStateProvider.select((s) => s.uid));
  if (uid.isEmpty) return Stream.value([]);
  
  final stream1 = FirebaseFirestore.instance.collection('matches').where("offerUserId", isEqualTo: uid).snapshots();
  final stream2 = FirebaseFirestore.instance.collection('matches').where("demandUserId", isEqualTo: uid).snapshots();

  final controller = StreamController<List<Map<String, dynamic>>>();
  
  List<QueryDocumentSnapshot> docs1 = [];
  List<QueryDocumentSnapshot> docs2 = [];
  
  void emitCombined() {
    final Map<String, Map<String, dynamic>> map = {};
    for (var doc in docs1) {
      map[doc.id] = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    }
    for (var doc in docs2) {
      map[doc.id] = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    }
    final list = map.values.toList();
    list.sort((a, b) {
      final t1 = a['createdAt'] as Timestamp?;
      final t2 = b['createdAt'] as Timestamp?;
      if (t1 == null || t2 == null) return 0;
      return t2.compareTo(t1);
    });
    controller.add(list);
  }

  final sub1 = stream1.listen((snap) { docs1 = snap.docs; emitCombined(); });
  final sub2 = stream2.listen((snap) { docs2 = snap.docs; emitCombined(); });
  
  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    controller.close();
  });

  return controller.stream;
});
