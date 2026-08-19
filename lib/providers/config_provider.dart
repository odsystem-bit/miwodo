// providers/config_provider.dart
// Providers Riverpod pour la configuration dynamique Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config_models.dart';

final _firestore = FirebaseFirestore.instance;

// ─── VILLES ──────────────────────────────────────────────────────────────────

final configVillesProvider = StreamProvider<List<ConfigVille>>((ref) {
  return _firestore
      .collection('config')
      .doc('villes')
      .snapshots()
      .map((snap) {
        if (!snap.exists || snap.data() == null) return _defaultVilles;
        final data = snap.data()!;
        final list = (data['items'] as List<dynamic>?)
            ?.map((e) => ConfigVille.fromJson(e as Map<String, dynamic>))
            .toList() ?? _defaultVilles;
        list.sort((a, b) => a.ordre.compareTo(b.ordre));
        return list;
      });
});

final configVillesActivesProvider = Provider<AsyncValue<List<ConfigVille>>>((ref) {
  return ref.watch(configVillesProvider).whenData(
    (villes) => villes.where((v) => v.actif).toList(),
  );
});

// ─── ZONES ───────────────────────────────────────────────────────────────────

final configZonesProvider = StreamProvider<List<ConfigZone>>((ref) {
  return _firestore
      .collection('config')
      .doc('zones')
      .snapshots()
      .map((snap) {
        if (!snap.exists || snap.data() == null) return _defaultZones;
        final data = snap.data()!;
        final list = (data['items'] as List<dynamic>?)
            ?.map((e) => ConfigZone.fromJson(e as Map<String, dynamic>))
            .toList() ?? _defaultZones;
        list.sort((a, b) => a.ordre.compareTo(b.ordre));
        return list;
      });
});

final configZonesByVilleProvider = Provider.family<AsyncValue<List<ConfigZone>>, String>((ref, villeId) {
  return ref.watch(configZonesProvider).whenData(
    (zones) => zones.where((z) => z.villeId == villeId && z.actif).toList(),
  );
});

final configZonesActivesProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(configZonesProvider).whenData(
    (zones) => zones.where((z) => z.actif).map((z) => z.nom).toList(),
  );
});

final configZonesActivesFullProvider = Provider<AsyncValue<List<ConfigZone>>>((ref) {
  return ref.watch(configZonesProvider).whenData(
    (zones) => zones.where((z) => z.actif).toList(),
  );
});

// ─── CATÉGORIES ──────────────────────────────────────────────────────────────

final configCategoriesProvider = StreamProvider<List<ConfigCategorie>>((ref) {
  return _firestore
      .collection('config')
      .doc('categories')
      .snapshots()
      .map((snap) {
        if (!snap.exists || snap.data() == null) return _defaultCategories;
        final data = snap.data()!;
        final list = (data['items'] as List<dynamic>?)
            ?.map((e) => ConfigCategorie.fromJson(e as Map<String, dynamic>))
            .toList() ?? _defaultCategories;
        list.sort((a, b) => a.ordre.compareTo(b.ordre));
        return list;
      });
});

final configCategoriesActivesProvider = Provider<AsyncValue<List<ConfigCategorie>>>((ref) {
  return ref.watch(configCategoriesProvider).whenData(
    (cats) => cats.where((c) => c.actif).toList(),
  );
});

// ─── TARIFS ──────────────────────────────────────────────────────────────────

final configTarifsProvider = StreamProvider<ConfigTarifs>((ref) {
  return _firestore
      .collection('config')
      .doc('tarifs')
      .snapshots()
      .map((snap) {
        if (!snap.exists || snap.data() == null) return ConfigTarifs.defaults;
        return ConfigTarifs.fromJson(snap.data()!);
      });
});

// ─── APP ─────────────────────────────────────────────────────────────────────

final configAppProvider = StreamProvider<ConfigApp>((ref) {
  return _firestore
      .collection('config')
      .doc('app')
      .snapshots()
      .map((snap) {
        if (!snap.exists || snap.data() == null) return ConfigApp.defaults;
        return ConfigApp.fromJson(snap.data()!);
      });
});

// ─── NOTIFICATIONS ───────────────────────────────────────────────────────────

final configNotificationsProvider = StreamProvider<ConfigNotifications>((ref) {
  return _firestore
      .collection('config')
      .doc('notifications')
      .snapshots()
      .map((snap) {
        if (!snap.exists || snap.data() == null) return ConfigNotifications.defaults;
        return ConfigNotifications.fromJson(snap.data()!);
      });
});

// ─── SPONSORING ──────────────────────────────────────────────────────────────

final configSponsoringProvider = StreamProvider<ConfigSponsoring>((ref) {
  return _firestore
      .collection('config')
      .doc('sponsoring')
      .snapshots()
      .map((snap) {
        if (!snap.exists || snap.data() == null) return ConfigSponsoring.defaults;
        return ConfigSponsoring.fromJson(snap.data()!);
      });
});

// ─── VALEURS PAR DÉFAUT (FALLBACK) ───────────────────────────────────────────

final List<ConfigVille> _defaultVilles = [
  const ConfigVille(id: 'lome', nom: 'Lomé', pays: 'Togo', actif: true, ordre: 1),
  const ConfigVille(id: 'cotonou', nom: 'Cotonou', pays: 'Bénin', actif: true, ordre: 2),
  const ConfigVille(id: 'abidjan', nom: 'Abidjan', pays: "Côte d'Ivoire", actif: true, ordre: 3),
  const ConfigVille(id: 'dakar', nom: 'Dakar', pays: 'Sénégal', actif: true, ordre: 4),
  const ConfigVille(id: 'accra', nom: 'Accra', pays: 'Ghana', actif: true, ordre: 5),
  const ConfigVille(id: 'lagos', nom: 'Lagos', pays: 'Nigeria', actif: true, ordre: 6),
  const ConfigVille(id: 'bamako', nom: 'Bamako', pays: 'Mali', actif: true, ordre: 7),
  const ConfigVille(id: 'ouagadougou', nom: 'Ouagadougou', pays: 'Burkina Faso', actif: true, ordre: 8),
  const ConfigVille(id: 'douala', nom: 'Douala', pays: 'Cameroun', actif: true, ordre: 9),
  const ConfigVille(id: 'nairobi', nom: 'Nairobi', pays: 'Kenya', actif: true, ordre: 10),
];

final List<ConfigZone> _defaultZones = [
  // Lomé
  const ConfigZone(id: 'adidogome', nom: 'Adidogomé', villeId: 'lome', actif: true, ordre: 1),
  const ConfigZone(id: 'tokoin', nom: 'Tokoin', villeId: 'lome', actif: true, ordre: 2),
  const ConfigZone(id: 'be', nom: 'Bè', villeId: 'lome', actif: true, ordre: 3),
  const ConfigZone(id: 'kodjoviakope', nom: 'Kodjoviakopé', villeId: 'lome', actif: true, ordre: 4),
  const ConfigZone(id: 'agbalepedo', nom: 'Agbalépédo', villeId: 'lome', actif: true, ordre: 5),
  const ConfigZone(id: 'nyekonakpoe', nom: 'Nyékonakpoé', villeId: 'lome', actif: true, ordre: 6),
  const ConfigZone(id: 'hedzranawoe', nom: 'Hédzranawoé', villeId: 'lome', actif: true, ordre: 7),
  const ConfigZone(id: 'legos', nom: 'Légos', villeId: 'lome', actif: true, ordre: 8),
  const ConfigZone(id: 'agoe', nom: 'Agoè', villeId: 'lome', actif: true, ordre: 9),
  // Cotonou
  const ConfigZone(id: 'ganhi', nom: 'Ganhi', villeId: 'cotonou', actif: true, ordre: 10),
  const ConfigZone(id: 'akpakpa', nom: 'Akpakpa', villeId: 'cotonou', actif: true, ordre: 11),
  const ConfigZone(id: 'stelevie', nom: 'Sainte-Lévie', villeId: 'cotonou', actif: true, ordre: 12),
  const ConfigZone(id: 'jonquet', nom: 'Jonquet', villeId: 'cotonou', actif: true, ordre: 13),
  // Abidjan
  const ConfigZone(id: 'cocody', nom: 'Cocody', villeId: 'abidjan', actif: true, ordre: 14),
  const ConfigZone(id: 'plateau_abj', nom: 'Plateau', villeId: 'abidjan', actif: true, ordre: 15),
  const ConfigZone(id: 'yopougon', nom: 'Yopougon', villeId: 'abidjan', actif: true, ordre: 16),
  const ConfigZone(id: 'treichville', nom: 'Treichville', villeId: 'abidjan', actif: true, ordre: 17),
  // Dakar
  const ConfigZone(id: 'plateau_dkr', nom: 'Plateau', villeId: 'dakar', actif: true, ordre: 18),
  const ConfigZone(id: 'medina_dkr', nom: 'Médina', villeId: 'dakar', actif: true, ordre: 19),
  const ConfigZone(id: 'ouakam', nom: 'Ouakam', villeId: 'dakar', actif: true, ordre: 20),
];

final List<ConfigCategorie> _defaultCategories = [
  const ConfigCategorie(
    id: 'artisan', label: 'Artisan', labelPlural: 'Artisans',
    iconeSvg: 'ic_artisan.svg', actif: true, ordre: 1,
    sousCategories: ['Maçon', 'Peintre', 'Plombier', 'Électricien', 'Menuisier', 'Carreleur', 'Soudeur', 'Climatisation'],
  ),
  const ConfigCategorie(
    id: 'liberal', label: 'Libéral', labelPlural: 'Libéraux',
    iconeSvg: 'ic_liberal.svg', actif: true, ordre: 2,
    sousCategories: ['Avocat', 'Médecin', 'Comptable', 'Architecte', 'Notaire', 'Consultant', 'Pharmacien', 'Ingénieur'],
  ),
  const ConfigCategorie(
    id: 'vendeur', label: 'Vendeur', labelPlural: 'Vendeurs',
    iconeSvg: 'ic_vendeur.svg', actif: true, ordre: 3,
    sousCategories: ['Épicerie', 'Restaurant', 'Boulangerie', 'Pharmacie', 'Quincaillerie', 'Marché'],
  ),
  const ConfigCategorie(
    id: 'livreur', label: 'Livreur', labelPlural: 'Livreurs',
    iconeSvg: 'ic_livreur.svg', actif: true, ordre: 4,
    sousCategories: ['Moto', 'Voiture', 'Vélo', 'Tricycle'],
  ),
];
