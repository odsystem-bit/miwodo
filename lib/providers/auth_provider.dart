// providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prestataire.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

final authStateChangesProvider = StreamProvider<User?>(
  (ref) => FirebaseService.instance.auth.authStateChanges(),
);

// Provider qui indique si l'utilisateur connecté possède un profil prestataire
final currentUserPrestataireProvider = StreamProvider<Prestataire?>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return FirebaseService.instance.firestore
      .collection('prestataires')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return Prestataire.fromJson({...data, 'id': doc.id});
  });
});

final adminRoleProvider = StreamProvider<AdminRole?>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) {
    return const Stream<AdminRole?>.empty();
  }

  return FirebaseService.instance.firestore
      .collection('admins')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists) return null;
        final data = snapshot.data();
        if (data == null || (data['actif'] as bool? ?? false) != true) {
          return null;
        }
        return AdminRole.fromJson(data);
      });
});

final isAdminProvider = Provider<bool>((ref) {
  final adminRole = ref.watch(adminRoleProvider).asData?.value;
  return adminRole != null;
});

final isSuperAdminProvider = Provider<bool>((ref) {
  final adminRole = ref.watch(adminRoleProvider).asData?.value;
  return adminRole?.role == 'super_admin';
});
