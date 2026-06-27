import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tripRepositoryProvider = Provider((ref) => TripRepository());

class TripRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createTrip(String tripId, Map<String, dynamic> tripData) async {
    await _firestore.collection('trips').doc(tripId).set(tripData);
  }

  Future<void> addTrip(Map<String, dynamic> tripData) async {
    await _firestore.collection('trips').add(tripData);
  }

  Future<void> addTripsBatch(List<Map<String, dynamic>> tripsData) async {
    final batch = _firestore.batch();
    for (var trip in tripsData) {
      final docRef = _firestore.collection('trips').doc();
      batch.set(docRef, trip);
    }
    await batch.commit();
  }

  Future<void> updateTripData(String tripId, Map<String, dynamic> tripData) async {
    await _firestore.collection('trips').doc(tripId).update(tripData);
  }

  Future<void> updateTripStatus(String tripId, String status) async {
    await _firestore.collection('trips').doc(tripId).update({'status': status});
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

      // 1. Marcar el viaje como completado
      transaction.update(docRef, {'status': 'COMPLETED'});

      // 2. Obtener los participantes
      final String creatorUid = data['creatorUid'] ?? '';
      final String? acceptedByUid = data['acceptedByUid'];
      final List<dynamic>? passengerUids = data['passengerUids'];

      final Set<String> participantUids = {};
      if (creatorUid.isNotEmpty) participantUids.add(creatorUid);
      if (acceptedByUid != null && acceptedByUid.isNotEmpty) {
        participantUids.add(acceptedByUid);
      }
      if (passengerUids != null) {
        for (var uid in passengerUids) {
          if (uid is String && uid.isNotEmpty) {
            participantUids.add(uid);
          }
        }
      }

      // 3. Incrementar completedTrips para cada participante
      for (var uid in participantUids) {
        final userRef = _firestore.collection('users').doc(uid);
        transaction.update(userRef, {
          'completedTrips': FieldValue.increment(1),
        });
      }
    });
  }
}
