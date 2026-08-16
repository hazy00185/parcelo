import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../role_select_screen.dart';
import '../customer/customer_dashboard.dart';
import '../provider/provider_dashboard.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        final user = snapshot.data;

        if (user == null || user.isAnonymous) {
          if (user?.isAnonymous == true) {
            // Clean up the anonymous session used by the previous app version.
            FirebaseAuth.instance.signOut();
          }
          return const LoginScreen();
        }

        return _RoleResolver(user: user);
      },
    );
  }
}

class _RoleResolver extends StatelessWidget {
  final User user;

  const _RoleResolver({required this.user});

  Future<String?> _loadRole() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = snapshot.data();
    final role = data?['role'];

    if (role is String && (role == 'customer' || role == 'provider')) {
      return role;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _loadRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        if (snapshot.data == 'customer') {
          return const CustomerDashboard();
        }

        if (snapshot.data == 'provider') {
          return const ProviderDashboard();
        }

        // Missing profile/role: let the authenticated user choose a role.
        // This also keeps existing accounts usable after the auth upgrade.
        return const RoleSelectScreen();
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.local_shipping_rounded,
                size: 36,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
