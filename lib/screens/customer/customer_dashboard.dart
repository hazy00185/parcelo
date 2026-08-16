import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/delivery_order.dart';
import 'customer_orders_screen.dart';
import 'customer_tracking_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final _formKey = GlobalKey<FormState>();

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _packageController = TextEditingController();

  bool _isSubmitting = false;
  String? _lastOrderId;

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to identify customer. Please restart the app.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final order = DeliveryOrder(
      pickupAddress: _pickupController.text.trim(),
      dropAddress: _dropController.text.trim(),
      packageDetails: _packageController.text.trim(),
      customerId: user.uid,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(order.toMap());

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _lastOrderId = docRef.id;
      });

      _pickupController.clear();
      _dropController.clear();
      _packageController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery request placed successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send request: $e'),
        ),
      );
    }
  }

  void _startNewRequest() {
    _pickupController.clear();
    _dropController.clear();
    _packageController.clear();

    setState(() {
      _lastOrderId = null;
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _packageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customer',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'My Deliveries',
            icon: const Icon(
              Icons.receipt_long_rounded,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerOrdersScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _lastOrderId != null
          ? _WaitingForPartner(
        orderId: _lastOrderId!,
        scheme: scheme,
        onNewRequest: _startNewRequest,
      )
          : _buildForm(scheme),
    );
  }

  Widget _buildForm(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request a delivery',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fill in the details below and a delivery partner will pick it up.',
              style: TextStyle(
                fontSize: 13.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _pickupController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Pickup address',
                prefixIcon: Icon(
                  Icons.trip_origin_rounded,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Pickup address is required';
                }

                if (value.trim().length < 3) {
                  return 'Enter a valid pickup address';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _dropController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Drop-off address',
                prefixIcon: Icon(
                  Icons.location_on_rounded,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Drop-off address is required';
                }

                if (value.trim().length < 3) {
                  return 'Enter a valid drop-off address';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _packageController,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Package details',
                hintText:
                'e.g. Small box, food order, documents...',
                prefixIcon: Icon(
                  Icons.inventory_2_rounded,
                ),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please describe the package';
                }

                if (value.trim().length < 3) {
                  return 'Please provide more details';
                }

                return null;
              },
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitRequest,
                icon: _isSubmitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.send_rounded,
                ),
                label: Text(
                  _isSubmitting
                      ? 'Sending...'
                      : 'Request Delivery',
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingForPartner extends StatelessWidget {
  final String orderId;
  final ColorScheme scheme;
  final VoidCallback onNewRequest;

  const _WaitingForPartner({
    required this.orderId,
    required this.scheme,
    required this.onNewRequest,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load delivery status.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        String status = 'pending';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();

          if (data != null) {
            status = data['status'] ?? 'pending';
          }
        }

        final statusInfo = _statusInfo(status, scheme);

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: statusInfo.color.withValues(
                      alpha: 0.15,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusInfo.icon,
                    size: 48,
                    color: statusInfo.color,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  statusInfo.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  statusInfo.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 26),

                if (status == 'accepted' ||
                    status == 'picked_up')
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeliveryTrackingScreen(
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

                if (status == 'delivered')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your delivery has been completed successfully.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: onNewRequest,
                  child: const Text(
                    'Place another request',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ({
  IconData icon,
  String title,
  String message,
  Color color,
  }) _statusInfo(
      String status,
      ColorScheme scheme,
      ) {
    switch (status) {
      case 'accepted':
        return (
        icon: Icons.two_wheeler_rounded,
        title: 'Partner is on the way',
        message:
        'A delivery partner has accepted your request and is heading to the pickup location.',
        color: scheme.primary,
        );

      case 'picked_up':
        return (
        icon: Icons.local_shipping_rounded,
        title: 'Package picked up',
        message:
        'Your package has been picked up and is now on its way to the destination.',
        color: scheme.primary,
        );

      case 'delivered':
        return (
        icon: Icons.check_circle_rounded,
        title: 'Delivered!',
        message:
        'Your package has been delivered successfully.',
        color: Colors.green,
        );

      default:
        return (
        icon: Icons.hourglass_top_rounded,
        title: 'Waiting for a partner',
        message:
        'Your request has been sent. We are matching you with a delivery partner.',
        color: scheme.secondary,
        );
    }
  }
}
