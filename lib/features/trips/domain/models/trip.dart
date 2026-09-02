import 'package:cloud_firestore/cloud_firestore.dart';

class TripBoardItem {
  final String id;
  final String creatorUid;
  final String? acceptedByUid;
  final String? acceptedByName;
  final String userName;
  final bool isOffer; // true = Driver offering ride, false = Passenger requesting ride
  final String origin;
  final String exactPickup;
  final String destination;
  final String exactDropoff;
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final DateTime scheduleTime;
  final int seats;
  final int availableSeats;
  final double? price;
  final double? currentLat; // GPS Tracking
  final double? currentLng; // GPS Tracking

  // Rating out of 5.0
  final double rating;

  // Driver/Car details - Uber Style
  final String? carModel;
  final String? carColor;
  final String? carPlate;
  
  final String status; // PENDING, ACCEPTED, EN_ROUTE, COMPLETED
  
  // Women only feature
  final bool womenOnly;
  final bool isCreatorVerified;
  
  final List<Map<String, dynamic>> passengers;
  final List<String> stops;
  
  final DateTime createdAt;
  final String? recurringGroupId;
  final Map<String, dynamic> ratingsGiven; // Format: { 'raterUid': ['ratedUid1', 'ratedUid2'] }

  TripBoardItem({
    required this.id,
    required this.creatorUid,
    this.acceptedByUid,
    this.acceptedByName,
    required this.userName,
    required this.isOffer,
    required this.origin,
    required this.exactPickup,
    required this.destination,
    required this.exactDropoff,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    required this.scheduleTime,
    required this.seats,
    required this.availableSeats,
    this.price,
    this.currentLat,
    this.currentLng,
    required this.rating,
    this.carModel,
    this.carColor,
    this.carPlate,
    this.status = 'PENDING',
    this.womenOnly = false,
    this.isCreatorVerified = false,
    this.passengers = const [],
    this.stops = const [],
    required this.createdAt,
    this.recurringGroupId,
    this.ratingsGiven = const {},
  });

  factory TripBoardItem.fromFirestore(String id, Map<String, dynamic> data) {
    return TripBoardItem(
      id: id,
      creatorUid: data['creatorUid'] ?? '',
      acceptedByUid: data['acceptedByUid'],
      acceptedByName: data['acceptedByName'],
      userName: data['userName'] ?? 'Desconocido',
      isOffer: data['isOffer'] ?? true,
      origin: data['origin'] ?? '',
      exactPickup: data['exactPickup'] ?? '',
      destination: data['destination'] ?? '',
      exactDropoff: data['exactDropoff'] ?? '',
      originLat: (data['originLat'] as num?)?.toDouble(),
      originLng: (data['originLng'] as num?)?.toDouble(),
      destLat: (data['destLat'] as num?)?.toDouble(),
      destLng: (data['destLng'] as num?)?.toDouble(),
      scheduleTime: data['scheduleTime'] != null ? DateTime.parse(data['scheduleTime']) : DateTime.now(),
      seats: data['seats'] ?? 1,
      availableSeats: data['availableSeats'] ?? data['seats'] ?? 1,
      price: (data['price'] as num?)?.toDouble(),
      currentLat: (data['currentLat'] as num?)?.toDouble(),
      currentLng: (data['currentLng'] as num?)?.toDouble(),
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      carModel: data['carModel'],
      carColor: data['carColor'],
      carPlate: data['carPlate'],
      status: data['status'] ?? 'PENDING',
      womenOnly: data['womenOnly'] ?? false,
      isCreatorVerified: data['isCreatorVerified'] ?? false,
      passengers: data['passengers'] != null 
          ? List<Map<String, dynamic>>.from(data['passengers']) 
          : [],
      stops: data['stops'] != null ? List<String>.from(data['stops']) : [],
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      recurringGroupId: data['recurringGroupId'],
      ratingsGiven: data['ratingsGiven'] != null ? Map<String, dynamic>.from(data['ratingsGiven']) : {},
    );
  }
}
