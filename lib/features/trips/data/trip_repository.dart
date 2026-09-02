import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tripRepositoryProvider = Provider((ref) => TripRepository());

class TripRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createTrip(String tripId, Map<String, dynamic> tripData) async {
    await _firestore.collection('trips').doc(tripId).set(tripData);
  }

  /// Crea un viaje y devuelve su id.
  Future<String> addTrip(Map<String, dynamic> tripData) async {
    final ref = await _firestore.collection('trips').add(tripData);
    return ref.id;
  }

  /// Crea varios viajes (serie recurrente) y devuelve la lista de ids creados.
  Future<List<String>> addTripsBatch(List<Map<String, dynamic>> tripsData) async {
    final batch = _firestore.batch();
    final ids = <String>[];
    for (var trip in tripsData) {
      final docRef = _firestore.collection('trips').doc();
      ids.add(docRef.id);
      batch.set(docRef, trip);
    }
    await batch.commit();
    return ids;
  }

  Future<void> updateTripData(String tripId, Map<String, dynamic> tripData) async {
    await _firestore.collection('trips').doc(tripId).update(tripData);
  }

  Future<void> updateTripStatus(String tripId, String status) async {
    await _firestore.collection('trips').doc(tripId).update({'status': status});
  }

  /// Cancela un viaje (pasa a CANCELLED y así va al historial).
  Future<void> cancelTrip(String tripId) async {
    await _firestore.collection('trips').doc(tripId).update({'status': 'CANCELLED'});
  }

  /// Cancela toda una serie recurrente creada por [creatorUid].
  /// Solo cancela las ocurrencias aún PENDIENTES (no toca viajes ya aceptados).
  /// Devuelve cuántas ocurrencias se cancelaron.
  Future<int> cancelSeries(String recurringGroupId, String creatorUid) async {
    // Consulta por un solo campo para no requerir índice compuesto.
    final query = await _firestore
        .collection('trips')
        .where('recurringGroupId', isEqualTo: recurringGroupId)
        .get();

    final batch = _firestore.batch();
    int count = 0;
    for (final doc in query.docs) {
      final data = doc.data();
      if ((data['creatorUid'] ?? '') != creatorUid) continue;
      if ((data['status'] ?? 'PENDING') == 'PENDING') {
        batch.update(doc.reference, {'status': 'CANCELLED'});
        count++;
      }
    }
    if (count > 0) await batch.commit();
    return count;
  }

  /// IDs (Firestore doc ids) de las ocurrencias PENDIENTES de una serie
  /// creadas por [creatorUid] — útil para cancelar recordatorios locales.
  Future<List<String>> pendingSeriesTripIds(
      String recurringGroupId, String creatorUid) async {
    final query = await _firestore
        .collection('trips')
        .where('recurringGroupId', isEqualTo: recurringGroupId)
        .get();
    return query.docs
        .where((d) =>
            (d.data()['creatorUid'] ?? '') == creatorUid &&
            (d.data()['status'] ?? 'PENDING') == 'PENDING')
        .map((d) => d.id)
        .toList();
  }

  Future<void> joinTripAsPassenger({
    required String tripId,
    required String uid,
    required Map<String, dynamic> passengerData,
    required int seatsToBook,
    String? matchId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _firestore.collection('trips').doc(tripId);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception("El viaje ya no existe.");
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final int availableSeats = data['availableSeats'] ?? 0;
      final String status = data['status'] ?? 'PENDING';

      if (status == 'CANCELLED' || status == 'COMPLETED') {
        throw Exception("El viaje ya no está disponible.");
      }

      if (availableSeats < seatsToBook) {
        throw Exception("Asientos insuficientes. Alguien los tomó antes.");
      }

      final newAvailableSeats = availableSeats - seatsToBook;
      String newStatus = status;
      if (newAvailableSeats == 0) {
        newStatus = 'FULL';
      }

      transaction.update(docRef, {
        'passengers': FieldValue.arrayUnion([passengerData]),
        'passengerUids': FieldValue.arrayUnion([uid]),
        'availableSeats': newAvailableSeats,
        'status': newStatus,
      });
      
      if (matchId != null) {
        final matchRef = _firestore.collection('matches').doc(matchId);
        transaction.update(matchRef, {'status': 'ACCEPTED'});
      }
    });
  }

  Future<void> acceptTripAsDriver({
    required String tripId,
    required String uid,
    required String userName,
    String? matchId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _firestore.collection('trips').doc(tripId);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception("El viaje ya no existe.");
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final String status = data['status'] ?? 'PENDING';

      if (status != 'PENDING') {
        throw Exception("Este viaje ya fue aceptado o no está disponible.");
      }

      transaction.update(docRef, {
        'status': 'ACCEPTED',
        'acceptedByUid': uid,
        'acceptedByName': userName,
      });
      
      if (matchId != null) {
        final matchRef = _firestore.collection('matches').doc(matchId);
        transaction.update(matchRef, {'status': 'ACCEPTED'});
      }
    });
  }

  Future<void> cancelPassengerReservation({
    required String tripId,
    required String uid,
    required Map<String, dynamic> passengerData,
    required int seatsToRestore,
  }) async {
    await _firestore.collection('trips').doc(tripId).update({
      'passengers': FieldValue.arrayRemove([passengerData]),
      'passengerUids': FieldValue.arrayRemove([uid]),
      'availableSeats': FieldValue.increment(seatsToRestore),
      'status': 'PENDING'
    });
  }

  /// Marca el viaje como COMPLETED. El incremento de `completedTrips` de los
  /// participantes lo hace la Cloud Function `onTripUpdated`: las reglas de
  /// Firestore no permiten que un cliente toque contadores de otros usuarios.
  Future<void> completeTrip(String tripId) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _firestore.collection('trips').doc(tripId);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception("El viaje ya no existe.");
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final String status = data['status'] ?? 'PENDING';

      if (status == 'COMPLETED') {
        return; // Ya completado
      }

      transaction.update(docRef, {'status': 'COMPLETED'});
    });
  }
}
