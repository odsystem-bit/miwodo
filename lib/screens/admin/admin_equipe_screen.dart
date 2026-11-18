// screens/admin/admin_equipe_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/admin_user.dart';
import '../../services/firestore_service.dart';
import '../../firebase_options.dart';
import 'admin_shell.dart';

class AdminEquipeScreen extends ConsumerStatefulWidget {
  const AdminEquipeScreen({super.key});

  @override
  AdminEquipeScreenState createState() => AdminEquipeScreenState();
}

class AdminEquipeScreenState extends ConsumerState<AdminEquipeScreen> {
  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Mon équipe',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(child: _buildAdminList(context)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FloatingActionButton(
                backgroundColor: AppColors.primaryOrange,
                onPressed: _showAddAdminDialog,
                child: const Icon(Icons.add, color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminList(BuildContext context) {
    return StreamBuilder<List<AdminUser>>(
      stream: FirestoreService.instance.getAdminUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final admins = snapshot.data ?? [];
        if (admins.isEmpty) {
          return Text(
            'Aucun membre de l’équipe défini.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          );
        }
        return ListView.separated(
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: admins.length,
          itemBuilder: (context, index) {
            final admin = admins[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: Text(
                  admin.nom,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${admin.email} • ${admin.role}${admin.zone != null ? ' • ${admin.zone}' : ''}',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                trailing: Switch(
                  value: admin.actif,
                  activeThumbColor: AppColors.primaryOrange,
                  onChanged: (value) async {
                    await FirestoreService.instance.toggleAdminActive(
                      admin.uid,
                      value,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddAdminDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nomController = TextEditingController();
    final zoneController = TextEditingController();
    var selectedRole = 'moderateur';
    final formKey = GlobalKey<FormState>();
    bool isCreating = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Ajouter un membre', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nomController,
                        decoration: InputDecoration(
                          labelText: 'Nom complet *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (value) =>
                            value?.trim().isEmpty == true ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value?.trim().isEmpty == true) return 'Email requis';
                          if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value!.trim())) {
                            return 'Email invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          helperText: 'Minimum 6 caractères',
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Minimum 6 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        items: const [
                          DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                          DropdownMenuItem(value: 'moderateur', child: Text('Modérateur')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Rôle',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (value) {
                          if (value != null) selectedRole = value;
                        },
                      ),
                      const SizedBox(height: 10),
                      if (selectedRole == 'moderateur')
                        TextFormField(
                          controller: zoneController,
                          decoration: InputDecoration(
                            labelText: 'Zone (optionnelle)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isCreating ? null : () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;

                    final admins = await FirestoreService.instance.getAdminUsers().first;
                    if (!mounted) return;
                    if (admins.length >= 5) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Maximum 5 membres autorisés.')),
                      );
                      return;
                    }

                    setDialogState(() => isCreating = true);

                    try {
                      // Créer l'utilisateur via une instance Firebase secondaire
                      // pour ne pas déconnecter l'admin courant
                      final secondaryApp = await Firebase.initializeApp(
                        name: 'admin-create-user',
                        options: DefaultFirebaseOptions.currentPlatform,
                      );
                      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

                      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text,
                      );
                      final newUid = userCredential.user!.uid;

                      await secondaryAuth.signOut();
                      await secondaryApp.delete();

                      final admin = AdminUser(
                        uid: newUid,
                        email: emailController.text.trim(),
                        nom: nomController.text.trim(),
                        role: selectedRole,
                        zone: selectedRole == 'moderateur'
                            ? (zoneController.text.trim().isEmpty ? null : zoneController.text.trim())
                            : null,
                        actif: true,
                        createdAt: DateTime.now(),
                      );
                      await FirestoreService.instance.createAdminUser(admin);

                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Membre créé avec succès ✓')),
                      );
                    } on FirebaseAuthException catch (e) {
                      setDialogState(() => isCreating = false);
                      String message;
                      switch (e.code) {
                        case 'email-already-in-use':
                          message = 'Cet email est déjà utilisé.';
                          break;
                        case 'invalid-email':
                          message = 'Email invalide.';
                          break;
                        case 'weak-password':
                          message = 'Mot de passe trop faible (min 6 caractères).';
                          break;
                        default:
                          message = 'Erreur: ${e.message}';
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isCreating = false);
                      if (kDebugMode) print('[AdminEquipe] create error: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur lors de la création: $e')),
                        );
                      }
                    }
                  },
                  child: isCreating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
