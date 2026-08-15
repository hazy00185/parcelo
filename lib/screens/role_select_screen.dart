import 'package:flutter/material.dart';
import 'customer/customer_dashboard.dart';
import 'provider/provider_dashboard.dart';

// This screen is the foundation of the "dual-dashboard" requirement:
// the same app serves two completely different roles, each with its
// own dedicated interface.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.local_shipping_rounded, color: scheme.onPrimaryContainer, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Parcelo',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: scheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                'Fast, reliable delivery — for everyone.',
                style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 48),
              Text(
                'Continue as',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'Customer',
                subtitle: 'Book a delivery and track it live',
                color: scheme.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerDashboard()),
                ),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                icon: Icons.two_wheeler_rounded,
                title: 'Delivery Partner',
                subtitle: 'Accept requests and go online',
                color: scheme.secondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProviderDashboard()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
