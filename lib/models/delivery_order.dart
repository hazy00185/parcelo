import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryOrder {
  final String? id;
  final String pickupAddress;
  final String dropAddress;
  final String packageDetails;
  final String status;
  final String? customerId;
  final String? providerId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DeliveryOrder({
    this.id,
    required this.pickupAddress,
    required this.dropAddress,
    required this.packageDetails,
    this.status = 'pending',
    this.customerId,
    this.providerId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'pickupAddress': pickupAddress,
      'dropAddress': dropAddress,
      'packageDetails': packageDetails,
      'status': status,
      'customerId': customerId,
      'providerId': providerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt':
      updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory DeliveryOrder.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    return DeliveryOrder(
      id: id,
      pickupAddress: map['pickupAddress'] ?? '',
      dropAddress: map['dropAddress'] ?? '',
      packageDetails: map['packageDetails'] ?? '',
      status: map['status'] ?? 'pending',
      customerId: map['customerId'],
      providerId: map['providerId'],
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
