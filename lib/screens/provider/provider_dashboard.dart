import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

enum _LocationState {
  checking,
  denied,
  ready,
  error,
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  static const String fallbackProviderId = 'anonymous_provider';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSubscription;

  _LocationState _locationState = _LocationState.checking;

  Position? _currentPosition;

  bool _isOnline = false;
  bool _updatingStatus = false;

  String get _providerId =>
      FirebaseAuth.instance.currentUser?.uid ?? fallbackProviderId;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOCATION
  // ------------------------------------------------------------

  Future<void> _initializeLocation() async {
    if (mounted) {
      setState(() {
        _locationState = _LocationState.checking;
      });
    }

    try {
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationState = _LocationState.error;
          });
        }
        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationState = _LocationState.denied;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _locationState = _LocationState.ready;
      });

      await _loadProviderStatus();

      _startLocationUpdates();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _locationState = _LocationState.error;
      });
    }
  }

  Future<void> _loadProviderStatus() async {
    try {
      final snapshot = await _firestore
          .collection('providers')
          .doc(_providerId)
          .get();

      if (!snapshot.exists || !mounted) return;

      final data = snapshot.data();

      if (data == null) return;

      setState(() {
        _isOnline = data['isOnline'] == true;
      });
    } catch (_) {
      // Keep default offline state.
    }
  }

  void _startLocationUpdates() {
    _positionSubscription?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) async {
      if (!mounted) return;

      setState(() {
        _currentPosition = position;
      });

      if (_isOnline) {
        await _updateProviderLocation(position);
        await _updateActiveOrderLocation(position);
      }
    });
  }

  Future<void> _updateProviderLocation(Position position) async {
    try {
      await _firestore
          .collection('providers')
          .doc(_providerId)
          .set(
        {
          'providerId': _providerId,
          'isOnline': true,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Location failures should not break the UI.
    }
  }

  // ------------------------------------------------------------
  // ONLINE / OFFLINE
  // ------------------------------------------------------------

  Future<void> _toggleOnline(bool value) async {
    if (_currentPosition == null || _updatingStatus) return;

    setState(() {
      _updatingStatus = true;
    });

    try {
      await _firestore
          .collection('providers')
          .doc(_providerId)
          .set(
        {
          'providerId': _providerId,
          'isOnline': value,
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _isOnline = value;
        _updatingStatus = false;
      });

      _showMessage(
        value
            ? 'You are now online'
            : 'You are now offline',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _updatingStatus = false;
      });

      _showMessage(
        'Unable to update online status: $e',
        error: true,
      );
    }
  }

  // ------------------------------------------------------------
  // LIVE ORDER LOCATION
  // ------------------------------------------------------------

  Future<void> _updateActiveOrderLocation(
      Position position,
      ) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('providerId', isEqualTo: _providerId)
          .where(
        'status',
        whereIn: ['accepted', 'picked_up'],
      )
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return;

      final orderId = snapshot.docs.first.id;

      await _firestore
          .collection('orders')
          .doc(orderId)
          .update({
        'providerLatitude': position.latitude,
        'providerLongitude': position.longitude,
        'providerLocationUpdatedAt':
        FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Tracking updates should never crash the provider app.
    }
  }

  // ------------------------------------------------------------
  // ORDER STATUS
  // ------------------------------------------------------------

  Future<void> _updateOrderStatus(
      String orderId,
      String newStatus,
      ) async {
    try {
      if (newStatus == 'accepted') {
        await _acceptOrder(orderId);
        return;
      }

      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'providerId': _providerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (_currentPosition != null &&
          (newStatus == 'picked_up' ||
              newStatus == 'accepted')) {
        await _firestore
            .collection('orders')
            .doc(orderId)
            .update({
          'providerLatitude':
          _currentPosition!.latitude,
          'providerLongitude':
          _currentPosition!.longitude,
          'providerLocationUpdatedAt':
          FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      final message = switch (newStatus) {
        'picked_up' => 'Package marked as picked up',
        'delivered' => 'Delivery completed successfully',
        _ => 'Order status updated',
      };

      _showMessage(message);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Failed to update order: $e',
        error: true,
      );
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef =
      _firestore.collection('orders').doc(orderId);

      final snapshot = await transaction.get(orderRef);

      if (!snapshot.exists) {
        throw Exception('Order no longer exists.');
      }

      final data = snapshot.data();

      if (data == null) {
        throw Exception('Invalid order data.');
      }

      final currentStatus =
          data['status'] ?? 'pending';

      final currentProvider =
      data['providerId'];

      if (currentStatus != 'pending') {
        if (currentProvider == _providerId &&
            currentStatus == 'accepted') {
          return;
        }

        throw Exception(
          'This delivery has already been accepted.',
        );
      }

      final update = <String, dynamic>{
        'status': 'accepted',
        'providerId': _providerId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_currentPosition != null) {
        update['providerLatitude'] =
            _currentPosition!.latitude;

        update['providerLongitude'] =
            _currentPosition!.longitude;

        update['providerLocationUpdatedAt'] =
            FieldValue.serverTimestamp();
      }

      transaction.update(orderRef, update);
    });

    if (!mounted) return;

    _showMessage('Delivery request accepted');
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delivery Partner',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Row(
            children: [
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Switch(
                value: _isOnline,
                onChanged:
                _locationState == _LocationState.ready &&
                    !_updatingStatus
                    ? _toggleOnline
                    : null,
              ),
              const SizedBox(width: 2),
            ],
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              if (_isOnline) {
                await _toggleOnline(false);
              }
              await FirebaseAuth.instance.signOut();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    switch (_locationState) {
      case _LocationState.checking:
        return const Center(
          child: CircularProgressIndicator(),
        );

      case _LocationState.denied:
        return _InfoState(
          icon: Icons.location_off_rounded,
          title: 'Location permission needed',
          message:
          'Enable location permission to provide live delivery tracking.',
          buttonLabel: 'Try Again',
          onPressed: _initializeLocation,
          scheme: scheme,
        );

      case _LocationState.error:
        return _InfoState(
          icon: Icons.gps_off_rounded,
          title: 'Location unavailable',
          message:
          'Turn on GPS/Location and try again.',
          buttonLabel: 'Retry',
          onPressed: _initializeLocation,
          scheme: scheme,
        );

      case _LocationState.ready:
        return _buildProviderInterface(scheme);
    }
  }

  Widget _buildProviderInterface(
      ColorScheme scheme,
      ) {
    final position = _currentPosition!;

    final location = LatLng(
      position.latitude,
      position.longitude,
    );

    return Column(
      children: [
        SizedBox(
          height: 270,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: location,
                  initialZoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                    'com.example.parcelo',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: location,
                        width: 48,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.25),
                                blurRadius: 7,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.two_wheeler_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${position.latitude.toStringAsFixed(5)}, '
                                '${position.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _isOnline ? 'LIVE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _isOnline
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
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

        Expanded(
          child: _isOnline
              ? _buildOrdersList(scheme)
              : _buildOfflineState(scheme),
        ),
      ],
    );
  }

  Widget _buildOfflineState(
      ColorScheme scheme,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delivery_dining_rounded,
              size: 60,
              color: scheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'You are offline',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go online to receive delivery requests.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ORDERS
  // ------------------------------------------------------------

  Widget _buildOrdersList(
      ColorScheme scheme,
      ) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .where(
        Filter.or(
          Filter(
            'status',
            isEqualTo: 'pending',
          ),
          Filter(
            'status',
            isEqualTo: 'accepted',
          ),
          Filter(
            'status',
            isEqualTo: 'picked_up',
          ),
        ),
      )
          .orderBy(
        'createdAt',
        descending: true,
      )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load delivery requests.\n\n'
                    '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final orders = docs.where((doc) {
          final data =
          doc.data() as Map<String, dynamic>;

          final status =
              data['status'] ?? 'pending';

          final assignedProvider =
          data['providerId'];

          if (status == 'pending') {
            return true;
          }

          return assignedProvider == _providerId;
        }).toList();

        if (orders.isEmpty) {
          return _EmptyOrdersState(
            scheme: scheme,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            18,
            16,
            24,
          ),
          children: [
            Text(
              'Delivery Requests',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${orders.length} active '
                  'delivery${orders.length == 1 ? '' : 'ies'}',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...orders.map(
                  (doc) => _OrderCard(
                orderId: doc.id,
                data:
                doc.data() as Map<String, dynamic>,
                onUpdateStatus: _updateOrderStatus,
                scheme: scheme,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

// ============================================================
// ORDER CARD
// ============================================================

class _OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;

  final Future<void> Function(
      String,
      String,
      ) onUpdateStatus;

  final ColorScheme scheme;

  const _OrderCard({
    required this.orderId,
    required this.data,
    required this.onUpdateStatus,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';

    final pickup =
        data['pickupAddress'] ?? 'Unknown pickup';

    final drop =
        data['dropAddress'] ?? 'Unknown destination';

    final package =
        data['packageDetails'] ??
            'No package details';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _statusIcon(status),
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _title(status),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                _StatusChip(
                  status: status,
                  scheme: scheme,
                ),
              ],
            ),

            const SizedBox(height: 18),

            _AddressRow(
              icon: Icons.trip_origin_rounded,
              label: 'PICKUP',
              value: pickup,
              scheme: scheme,
            ),

            const SizedBox(height: 12),

            _AddressRow(
              icon: Icons.location_on_rounded,
              label: 'DROP-OFF',
              value: drop,
              scheme: scheme,
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                scheme.surfaceContainerHighest,
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 19,
                    color:
                    scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      package,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            if (status == 'pending')
              _ActionButton(
                label: 'Accept Delivery',
                icon:
                Icons.check_circle_outline_rounded,
                onPressed: () =>
                    onUpdateStatus(
                      orderId,
                      'accepted',
                    ),
              )
            else if (status == 'accepted')
              _ActionButton(
                label: 'Mark Picked Up',
                icon: Icons.inventory_2_rounded,
                onPressed: () =>
                    onUpdateStatus(
                      orderId,
                      'picked_up',
                    ),
              )
            else if (status == 'picked_up')
                _ActionButton(
                  label: 'Mark Delivered',
                  icon:
                  Icons.check_circle_rounded,
                  onPressed: () =>
                      onUpdateStatus(
                        orderId,
                        'delivered',
                      ),
                ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.two_wheeler_rounded;

      case 'picked_up':
        return Icons.inventory_2_rounded;

      default:
        return Icons.local_shipping_rounded;
    }
  }

  String _title(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted Delivery';

      case 'picked_up':
        return 'Package Picked Up';

      default:
        return 'New Delivery';
    }
  }
}

// ============================================================
// ACTION BUTTON
// ============================================================

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

// ============================================================
// STATUS CHIP
// ============================================================

class _StatusChip extends StatelessWidget {
  final String status;
  final ColorScheme scheme;

  const _StatusChip({
    required this.status,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final String label;

    switch (status) {
      case 'accepted':
        label = 'ACCEPTED';
        break;

      case 'picked_up':
        label = 'PICKED UP';
        break;

      default:
        label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

// ============================================================
// ADDRESS ROW
// ============================================================

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;

  const _AddressRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: scheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color:
                  scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyOrdersState extends StatelessWidget {
  final ColorScheme scheme;

  const _EmptyOrdersState({
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 56,
              color: scheme.outline,
            ),
            const SizedBox(height: 14),
            Text(
              'No active deliveries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'New customer requests will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// INFO STATE
// ============================================================

class _InfoState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;
  final ColorScheme scheme;

  const _InfoState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: scheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
