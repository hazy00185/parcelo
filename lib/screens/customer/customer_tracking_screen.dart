import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;

  const DeliveryTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<DeliveryTrackingScreen> createState() =>
      _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final MapController _mapController = MapController();

  LatLng? _lastProviderLocation;
  bool _followProvider = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Track Delivery',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip:
                _followProvider ? 'Following provider' : 'Follow provider',
            onPressed: () {
              setState(() => _followProvider = !_followProvider);

              if (_followProvider && _lastProviderLocation != null) {
                _moveToProvider(_lastProviderLocation!, animate: true);
              }
            },
            icon: Icon(
              _followProvider
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(
              message:
                  'Unable to load tracking information.\n\n${snapshot.error}',
              scheme: scheme,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final document = snapshot.data;

          if (document == null || !document.exists) {
            return _ErrorState(
              message: 'This delivery could not be found.',
              scheme: scheme,
              icon: Icons.inventory_2_outlined,
            );
          }

          final data = document.data() ?? <String, dynamic>{};

          final status = _stringValue(
            data['status'],
            fallback: 'pending',
          );

          final pickup = _stringValue(
            data['pickupAddress'],
            fallback: 'Unknown pickup',
          );

          final drop = _stringValue(
            data['dropAddress'],
            fallback: 'Unknown destination',
          );

          final providerLocation = _validLocation(
            _doubleValue(data['providerLatitude']),
            _doubleValue(data['providerLongitude']),
          );

          final providerLocationUpdatedAt =
              _dateValue(data['providerLocationUpdatedAt']);

          // Firestore snapshots are the single source of truth.
          // Every provider coordinate update rebuilds this screen,
          // updates the marker, and moves the map when follow mode is on.
          if (providerLocation != null) {
            final locationChanged =
                _lastProviderLocation == null ||
                _lastProviderLocation!.latitude != providerLocation.latitude ||
                _lastProviderLocation!.longitude != providerLocation.longitude;

            _lastProviderLocation = providerLocation;

            if (locationChanged && _followProvider) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _followProvider) {
                  _moveToProvider(providerLocation, animate: true);
                }
              });
            }
          }

          return Column(
            children: [
              Expanded(
                child: _TrackingMap(
                  mapController: _mapController,
                  scheme: scheme,
                  providerLocation: providerLocation,
                  status: status,
                  followProvider: _followProvider,
                  onFollowChanged: (value) {
                    setState(() => _followProvider = value);

                    if (value && providerLocation != null) {
                      _moveToProvider(providerLocation, animate: true);
                    }
                  },
                ),
              ),
              _TrackingBottomSheet(
                status: status,
                pickup: pickup,
                drop: drop,
                scheme: scheme,
                providerAvailable: providerLocation != null,
                providerLocationUpdatedAt: providerLocationUpdatedAt,
              ),
            ],
          );
        },
      ),
    );
  }

  void _moveToProvider(
    LatLng location, {
    bool animate = false,
  }) {
    try {
      final camera = _mapController.camera;
      final zoom = camera.zoom < 14 ? 15.0 : camera.zoom;

      _mapController.move(location, zoom);
    } catch (_) {
      // Controller can be unattached during the first frame.
    }
  }

  static String _stringValue(
    dynamic value, {
    required String fallback,
  }) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static double? _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static LatLng? _validLocation(
    double? latitude,
    double? longitude,
  ) {
    if (latitude == null || longitude == null) return null;

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  static DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _TrackingMap extends StatelessWidget {
  final MapController mapController;
  final ColorScheme scheme;
  final LatLng? providerLocation;
  final String status;
  final bool followProvider;
  final ValueChanged<bool> onFollowChanged;

  const _TrackingMap({
    required this.mapController,
    required this.scheme,
    required this.providerLocation,
    required this.status,
    required this.followProvider,
    required this.onFollowChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (providerLocation == null) {
      return Container(
        color: scheme.surfaceContainerHighest,
        child: _WaitingForLocation(scheme: scheme),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: providerLocation!,
            initialZoom: 15,
            minZoom: 3,
            maxZoom: 19,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture && followProvider) {
                onFollowChanged(false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.parcelo',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: providerLocation!,
                  width: 68,
                  height: 68,
                  child: _ProviderMarker(
                    scheme: scheme,
                    status: status,
                  ),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          right: 16,
          top: 16,
          child: Material(
            color: scheme.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (!followProvider) {
                  onFollowChanged(true);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      followProvider
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_not_fixed_rounded,
                      size: 17,
                      color: followProvider
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      followProvider ? 'LIVE' : 'FOLLOW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: followProvider
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderMarker extends StatelessWidget {
  final ColorScheme scheme;
  final String status;

  const _ProviderMarker({
    required this.scheme,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDelivered = status == 'delivered';

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isDelivered ? Colors.green : scheme.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.surface,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isDelivered
                ? Icons.check_rounded
                : Icons.two_wheeler_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ],
    );
  }
}

class _WaitingForLocation extends StatelessWidget {
  final ColorScheme scheme;

  const _WaitingForLocation({
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
              Icons.location_searching_rounded,
              size: 58,
              color: scheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Waiting for provider location',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The delivery partner location will appear here '
              'when live location is available.',
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

class _TrackingBottomSheet extends StatelessWidget {
  final String status;
  final String pickup;
  final String drop;
  final ColorScheme scheme;
  final bool providerAvailable;
  final DateTime? providerLocationUpdatedAt;

  const _TrackingBottomSheet({
    required this.status,
    required this.pickup,
    required this.drop,
    required this.scheme,
    required this.providerAvailable,
    required this.providerLocationUpdatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo();

    return Material(
      elevation: 14,
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: info.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      info.icon,
                      color: info.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          info.message,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    status: status,
                    scheme: scheme,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _LocationRow(
                icon: Icons.trip_origin_rounded,
                title: 'Pickup',
                address: pickup,
                scheme: scheme,
              ),
              const SizedBox(height: 10),
              _LocationRow(
                icon: Icons.location_on_rounded,
                title: 'Drop-off',
                address: drop,
                scheme: scheme,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    providerAvailable
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 16,
                    color: providerAvailable
                        ? Colors.green
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      providerAvailable
                          ? _lastUpdatedText()
                          : 'Waiting for live provider location',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastUpdatedText() {
    if (providerLocationUpdatedAt == null) {
      return 'Provider location is live';
    }

    final time = providerLocationUpdatedAt!;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return 'Live location • Updated at $hour:$minute';
  }

  ({
    IconData icon,
    String title,
    String message,
    Color color,
  }) _statusInfo() {
    switch (status) {
      case 'accepted':
        return (
          icon: Icons.two_wheeler_rounded,
          title: 'Partner is on the way',
          message: 'Your delivery partner is heading to the pickup.',
          color: scheme.primary,
        );

      case 'picked_up':
        return (
          icon: Icons.local_shipping_rounded,
          title: 'Package is moving',
          message: 'Your package has been picked up and is on its way.',
          color: scheme.primary,
        );

      case 'delivered':
        return (
          icon: Icons.check_circle_rounded,
          title: 'Delivered',
          message: 'Your package has been delivered successfully.',
          color: Colors.green,
        );

      default:
        return (
          icon: Icons.hourglass_top_rounded,
          title: 'Waiting for partner',
          message:
              'We are matching your request with a delivery partner.',
          color: scheme.secondary,
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final ColorScheme scheme;

  const _StatusBadge({
    required this.status,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'accepted' => ('ACCEPTED', scheme.primary),
      'picked_up' => ('IN TRANSIT', scheme.primary),
      'delivered' => ('DELIVERED', Colors.green),
      _ => ('PENDING', scheme.secondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String address;
  final ColorScheme scheme;

  const _LocationRow({
    required this.icon,
    required this.title,
    required this.address,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: scheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
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

class _ErrorState extends StatelessWidget {
  final String message;
  final ColorScheme scheme;
  final IconData icon;

  const _ErrorState({
    required this.message,
    required this.scheme,
    this.icon = Icons.cloud_off_rounded,
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
              icon,
              size: 58,
              color: scheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
