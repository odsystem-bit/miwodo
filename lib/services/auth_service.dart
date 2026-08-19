// services/auth_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_service.dart';

class AdminRole {
  final String role;
  final String? zone;
  final String? nom;
  final String? email;
  final DateTime? createdAt;
  final bool actif;

  const AdminRole({
    required this.role,
    this.zone,
    this.nom,
    this.email,
    this.createdAt,
    this.actif = true,
  });

  bool get isSuperAdmin => role == 'super_admin';
  bool get isModerateur => role == 'moderateur';
  String get label {
    return isSuperAdmin ? 'Super Admin' : 'Modérateur';
  }

  factory AdminRole.fromJson(Map<String, dynamic> json) {
    return AdminRole(
      role: json['role'] as String? ?? 'moderateur',
      zone: json['zone'] as String?,
      nom: json['nom'] as String?,
      email: json['email'] as String?,
      actif: json['actif'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseFirestore _firestore = FirebaseService.instance.firestore;
  late final StreamSubscription<User?> _authSubscription = FirebaseService
      .instance
      .auth
      .authStateChanges()
      .listen(_onAuthStateChanged);
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _adminDocumentSubscription;
  AdminRole? _currentAdminRole;

  AdminRole? get currentAdminRole => _currentAdminRole;
  bool get isAdminUser => _currentAdminRole != null && _currentAdminRole!.actif;
  bool get isSuperAdmin => _currentAdminRole?.isSuperAdmin == true;

  void setAdminRole(AdminRole? role) {
    final hasChanged = _currentAdminRole?.role != role?.role ||
        _currentAdminRole?.actif != role?.actif;
    _currentAdminRole = role;
    if (hasChanged) notifyListeners();
  }

  void _onAuthStateChanged(User? user) {
    _adminDocumentSubscription?.cancel();
    _currentAdminRole = null;
    notifyListeners();

    if (user == null) {
      return;
    }

    _adminDocumentSubscription = _firestore
        .collection('admins')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          final updatedRole = _adminRoleFromSnapshot(snapshot);
          final hasChanged =
              _currentAdminRole?.role != updatedRole?.role ||
              _currentAdminRole?.zone != updatedRole?.zone ||
              _currentAdminRole?.nom != updatedRole?.nom ||
              _currentAdminRole?.email != updatedRole?.email ||
              _currentAdminRole?.actif != updatedRole?.actif;

          if (hasChanged) {
            _currentAdminRole = updatedRole;
            notifyListeners();
          }
        });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _adminDocumentSubscription?.cancel();
    super.dispose();
  }

  AdminRole? _adminRoleFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;
    if (data['actif'] != true) return null;
    return AdminRole.fromJson(data);
  }

  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _firestore.collection('admins').doc(uid).get();
      final data = doc.data();
      return doc.exists && (data?['actif'] as bool? ?? false) == true;
    } catch (e) {
      if (kDebugMode) print('[AuthService] isAdmin error: $e');
      return false;
    }
  }

  Future<AdminRole?> getAdminRole(String uid) async {
    try {
      final doc = await _firestore.collection('admins').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || (data['actif'] as bool? ?? false) != true) {
        return null;
      }
      return AdminRole.fromJson(data);
    } catch (e) {
      if (kDebugMode) print('[AuthService] getAdminRole error: $e');
      return null;
    }
  }

  // Sign in with email & password
  Future<UserCredential> signInWithEmail(String email, String password, {bool rememberMe = true}) async {
    try {
      // Sauvegarder le choix "Se souvenir de moi"
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', rememberMe);
      
      return await FirebaseService.instance.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) print('[AuthService] signInWithEmail error: $e');
      rethrow;
    }
  }

  // Create account with email & password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await FirebaseService.instance.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) print('[AuthService] signUpWithEmail error: $e');
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseService.instance.auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      if (kDebugMode) print('[AuthService] sendPasswordResetEmail error: $e');
      rethrow;
    }
  }

  // Sign in with Google. On web uses popup; on mobile this method is not implemented here
  // (add `google_sign_in` package and mobile-specific flow if you need mobile Google sign-in).
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        return await FirebaseService.instance.auth.signInWithPopup(provider);
      } else {
        // Mobile Google Sign-In is not implemented here. Add `google_sign_in` and
        // implement the native flow for Android/iOS.
        throw UnimplementedError('Google Sign-In for mobile is not implemented.');
      }
    } catch (e) {
      if (kDebugMode) print('[AuthService] signInWithGoogle error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Nettoyer le flag "Se souvenir de moi"
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remember_me');
      await FirebaseService.instance.auth.signOut();
    } catch (e) {
      if (kDebugMode) print('[AuthService] signOut error: $e');
      rethrow;
    }
  }
}
