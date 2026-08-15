import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'customer_tracking_screen.dart';

class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Deliveries',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Unable to identify customer.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Deliveries',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where(
          'customerId',
          isEqualTo: user.uid,
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
                  'Unable to load your deliveries.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final orders = snapshot.data?.docs ?? [];

          if (orders.isEmpty) {
            return _EmptyState(
              scheme: scheme,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];

              return _OrderHistoryCard(
                orderId: doc.id,
                data: doc.data(),
                scheme: scheme,
              );
            },
          );
        },
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final ColorScheme scheme;

  const _OrderHistoryCard({
    required this.orderId,
    required this.data,
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
        data['packageDetails'] ?? 'No package details';

    final info = _statusInfo(status);

    final canTrack =
        status == 'accepted' ||
            status == 'picked_up';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: info.color.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Icon(
                    info.icon,
                    color: info.color,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Delivery',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),

                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: info.color.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Text(
                    info.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: info.color,
                    ),
                  ),
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
                color: scheme.surfaceContainerHighest,
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
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

            if (canTrack) ...[
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DeliveryTrackingScreen(
                              orderId: orderId,
                            ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.location_on_rounded,
                  ),
                  label: const Text(
                    'Track Delivery',
                  ),
                ),
              ),
            ],

            if (status == 'delivered') ...[
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Delivery completed successfully.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ({
  IconData icon,
  String label,
  Color color,
  }) _statusInfo(String status) {
    switch (status) {
      case 'accepted':
        return (
        icon: Icons.two_wheeler_rounded,
        label: 'ACCEPTED',
        color: Colors.blue,
        );

      case 'picked_up':
        return (
        icon: Icons.local_shipping_rounded,
        label: 'PICKED UP',
        color: Colors.orange,
        );

      case 'delivered':
        return (
        icon: Icons.check_circle_rounded,
        label: 'DELIVERED',
        color: Colors.green,
        );

      default:
        return (
        icon: Icons.hourglass_top_rounded,
        label: 'PENDING',
        color: Colors.grey,
        );
    }
  }
}

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
          size: 19,
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
                  color: scheme.onSurfaceVariant,
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

class _EmptyState extends StatelessWidget {
  final ColorScheme scheme;

  const _EmptyState({
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
              Icons.local_shipping_outlined,
              size: 64,
              color: scheme.outline,
            ),

            const SizedBox(height: 16),

            Text(
              'No deliveries yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Your delivery history will appear here.',
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
