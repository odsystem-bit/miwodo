// providers/pays_provider.dart
// Providers Riverpod pour la gestion multi-pays

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pays.dart';
import '../core/utils/formatters.dart';

const _kPrefsKeyPays = 'miwodo_pays_id';

final _firestore = FirebaseFirestore.instance;

// ─── Stream tous les pays depuis Firestore ────────────────────────────────

final tousLesPaysProvider = StreamProvider<List<Pays>>((ref) {
  return _firestore
      .collection('config')
      .doc('pays')
      .snapshots()
      .map((snap) {
        if (!snap.exists || snap.data() == null) return _defaultPays;
        final data = snap.data()!;
        final list = (data['items'] as List<dynamic>?)
            ?.map((e) => Pays.fromJson(e as Map<String, dynamic>))
            .toList() ?? _defaultPays;
        // Override: toujours utiliser les monerooMethods locales (corrigées)
        // car Firestore peut contenir des méthodes obsolètes (card_xof, etc.)
        final corrected = list.map((p) {
          final local = _defaultPays.where((d) => d.id == p.id).firstOrNull;
          if (local != null && local.monerooMethods != p.monerooMethods) {
            return p.copyWith(monerooMethods: local.monerooMethods);
          }
          return p;
        }).toList();
        corrected.sort((a, b) => a.ordre.compareTo(b.ordre));
        return corrected;
      });
});

// ─── Pays actifs uniquement ───────────────────────────────────────────────

final paysDisponiblesProvider = Provider<AsyncValue<List<Pays>>>((ref) {
  return ref.watch(tousLesPaysProvider).whenData(
    (list) => list.where((p) => p.actif).toList(),
  );
});

// ─── Pays sélectionné (stocké en SharedPreferences) ─────────────────────

final paysSelectionneProvider = StateNotifierProvider<PaysNotifier, Pays?>((ref) {
  return PaysNotifier(ref);
});

class PaysNotifier extends StateNotifier<Pays?> {
  final Ref _ref;

  PaysNotifier(this._ref) : super(null) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_kPrefsKeyPays);
    if (savedId == null) return;

    // Attendre que les pays soient chargés
    final paysAsync = _ref.read(tousLesPaysProvider);
    paysAsync.whenData((list) {
      final found = list.where((p) => p.id == savedId && p.actif);
      if (found.isNotEmpty) state = found.first;
    });
  }

  Future<void> selectionner(Pays pays) async {
    state = pays;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKeyPays, pays.id);
  }

  Future<void> selectionnerParId(String paysId, List<Pays> tousPays) async {
    final found = tousPays.where((p) => p.id == paysId && p.actif);
    if (found.isNotEmpty) {
      await selectionner(found.first);
    }
  }

  void reset() => state = null;
}

// ─── Providers dérivés ───────────────────────────────────────────────────

final deviseProvider = Provider<String>((ref) {
  final pays = ref.watch(paysSelectionneProvider);
  return pays?.devise ?? 'XOF';
});

final symboleProvider = Provider<String>((ref) {
  final pays = ref.watch(paysSelectionneProvider);
  return pays?.symbole ?? 'F CFA';
});

final inscriptionMontantProvider = Provider<num>((ref) {
  final pays = ref.watch(paysSelectionneProvider);
  return pays?.inscriptionMontant ?? 500;
});

final pubStandardMontantProvider = Provider<num>((ref) {
  final pays = ref.watch(paysSelectionneProvider);
  return pays?.pubStandardMontant ?? 2000;
});

final pubPremiumMontantProvider = Provider<num>((ref) {
  final pays = ref.watch(paysSelectionneProvider);
  return pays?.pubPremiumMontant ?? 5000;
});

final gainParrainageProvider = Provider<num>((ref) {
  final pays = ref.watch(paysSelectionneProvider);
  return pays?.gainParrainage ?? 100;
});

final monerooMethodsProvider = Provider<List<String>>((ref) {
  final pays = ref.watch(paysSelectionneProvider);
  return pays?.monerooMethods ?? ['moov_tg', 'togocel'];
});

final regionProvider = Provider<String>((ref) {
  final pays = ref.watch(paysSelectionneProvider);
  return pays?.region ?? 'afrique_ouest';
});

/// Retourne un prix formaté avec la devise du pays sélectionné.
final formatPrixProvider = Provider.family<String, num>((ref, montant) {
  final symbole = ref.watch(symboleProvider);
  return formatPrix(montant, symbole);
});

// ─── Données par défaut (fallback si Firestore indisponible) ─────────────

final List<Pays> _defaultPays = [
  // Afrique de l'Ouest
  Pays.togo,
  const Pays(
    id: 'CI',
    nom: 'Côte d\'Ivoire',
    drapeauEmoji: '🇨🇮',
    region: 'afrique_ouest',
    actif: true,
    devise: 'XOF',
    symbole: 'F CFA',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: ['orange_ci', 'mtn_ci', 'moov_ci', 'wave_ci'],
    villesActives: ['Abidjan','Bouaké','Yamoussoukro','Korhogo','San-Pédro','Daloa','Man','Duékoué','Abengourou','Grand-Bassam','Divo','Gagnoa'],
    ordre: 2,
  ),
  const Pays(
    id: 'BJ',
    nom: 'Bénin',
    drapeauEmoji: '🇧🇯',
    region: 'afrique_ouest',
    actif: true,
    devise: 'XOF',
    symbole: 'F CFA',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: ['mtn_bj', 'moov_bj'],
    villesActives: ['Cotonou','Porto-Novo','Parakou','Abomey','Djougou','Ouidah','Savè','Bohicon','Kandi','Natitingou','Lokossa','Abomey-Calavi'],
    ordre: 3,
  ),
  const Pays(
    id: 'SN',
    nom: 'Sénégal',
    drapeauEmoji: '🇸🇳',
    region: 'afrique_ouest',
    actif: true,
    devise: 'XOF',
    symbole: 'F CFA',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: ['orange_sn', 'wave_sn', 'freemoney_sn'],
    villesActives: ['Dakar','Touba','Thiès','Kaolack','Saint-Louis','Rufisque','Ziguinchor','Diourbel','Louga','Mbour','Tambacounda','Kaolack'],
    ordre: 4,
  ),
  const Pays(
    id: 'GH',
    nom: 'Ghana',
    drapeauEmoji: '🇬🇭',
    region: 'afrique_ouest',
    actif: true,
    devise: 'GHS',
    symbole: 'GH₵',
    inscriptionMontant: 10,
    gainParrainage: 5,
    commissionFixeCommande: 2,
    pubStandardMontant: 30,
    pubPremiumMontant: 80,
    retraitMinimum: 10,
    monerooMethods: ['mtn_gh', 'tigo_gh', 'vodafone_gh'],
    villesActives: ['Accra','Kumasi','Tamale','Takoradi','Cape Coast','Tema','Obuasi','Koforidua','Sunyani','Ho','Wa','Bolgatanga'],
    ordre: 5,
  ),
  const Pays(
    id: 'NG',
    nom: 'Nigeria',
    drapeauEmoji: '🇳🇬',
    region: 'afrique_ouest',
    actif: true,
    devise: 'NGN',
    symbole: '₦',
    inscriptionMontant: 500,
    gainParrainage: 200,
    commissionFixeCommande: 100,
    pubStandardMontant: 3000,
    pubPremiumMontant: 8000,
    retraitMinimum: 1000,
    monerooMethods: ['airtel_ng'],
    villesActives: ['Lagos','Abuja','Kano','Ibadan','Port Harcourt','Benin City','Kaduna','Enugu','Aba','Jos','Ilorin','Owerri'],
    ordre: 6,
  ),
  const Pays(
    id: 'ML',
    nom: 'Mali',
    drapeauEmoji: '🇲🇱',
    region: 'afrique_ouest',
    actif: true,
    devise: 'XOF',
    symbole: 'F CFA',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: ['orange_ml'],
    villesActives: ['Bamako','Sikasso','Ségou','Kayes','Mopti','Tombouctou','Gao','Koutiala','San','Bougouni'],
    ordre: 7,
  ),
  const Pays(
    id: 'BF',
    nom: 'Burkina Faso',
    drapeauEmoji: '🇧🇫',
    region: 'afrique_ouest',
    actif: true,
    devise: 'XOF',
    symbole: 'F CFA',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: ['orange_bf', 'moov_bf'],
    villesActives: ['Ouagadougou','Bobo-Dioulasso','Koudougou','Banfora','Ouahigouya','Kaya','Tenkodogo','Fada N\'Gourma','Dédougou','Dori'],
    ordre: 8,
  ),
  const Pays(
    id: 'NE',
    nom: 'Niger',
    drapeauEmoji: '🇳🇪',
    region: 'afrique_ouest',
    actif: true,
    devise: 'XOF',
    symbole: 'F CFA',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: ['airtel_ne'],
    villesActives: ['Niamey','Zinder','Maradi','Agadez','Tahoua','Diffa','Dosso','Tillabéri','Mirriah','Birni-N\'Konni'],
    ordre: 9,
  ),
  const Pays(
    id: 'GN',
    nom: 'Guinée',
    drapeauEmoji: '🇬🇳',
    region: 'afrique_ouest',
    actif: true,
    devise: 'GNF',
    symbole: 'GNF',
    inscriptionMontant: 5000,
    gainParrainage: 1000,
    commissionFixeCommande: 500,
    pubStandardMontant: 20000,
    pubPremiumMontant: 50000,
    retraitMinimum: 5000,
    monerooMethods: ['mtn_gn'],
    villesActives: ['Conakry','Kankan','Kindia','Nzérékoré','Labé','Boké','Siguiri','Guéckédou','Mamou','Kamsar'],
    ordre: 10,
  ),
  // Afrique Centrale
  const Pays(
    id: 'CM',
    nom: 'Cameroun',
    drapeauEmoji: '🇨🇲',
    region: 'afrique_centrale',
    actif: true,
    devise: 'XAF',
    symbole: 'F CFA',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: [],
    villesActives: ['Douala','Yaoundé','Bafoussam','Garoua','Kousseri','Bamenda','Maroua','Nkongsamba','Edéa','Kribi','Buea','Limbé'],
    ordre: 10,
  ),
  const Pays(
    id: 'GA',
    nom: 'Gabon',
    drapeauEmoji: '🇬🇦',
    region: 'afrique_centrale',
    actif: true,
    devise: 'XAF',
    symbole: 'F CFA',
    inscriptionMontant: 1000,
    gainParrainage: 200,
    commissionFixeCommande: 200,
    pubStandardMontant: 4000,
    pubPremiumMontant: 10000,
    retraitMinimum: 1000,
    monerooMethods: [],
    villesActives: ['Libreville','Port-Gentil','Franceville','Oyem','Moanda','Lambaréné','Tchibanga','Mouila','Koulamoutou','Bitam'],
    ordre: 11,
  ),
  const Pays(
    id: 'CD',
    nom: 'République Démocratique du Congo',
    drapeauEmoji: '🇨🇩',
    region: 'afrique_centrale',
    actif: true,
    devise: 'CDF',
    symbole: 'FC',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: [],
    villesActives: ['Kinshasa','Lubumbashi','Goma','Mbuji-Mayi','Kananga','Kisangani','Bukavu','Likasi','Kolwezi','Matadi'],
    ordre: 12,
  ),
  // Afrique de l'Est
  const Pays(
    id: 'KE',
    nom: 'Kenya',
    drapeauEmoji: '🇰🇪',
    region: 'afrique_est',
    actif: true,
    devise: 'KES',
    symbole: 'KSh',
    inscriptionMontant: 100,
    gainParrainage: 50,
    commissionFixeCommande: 20,
    pubStandardMontant: 500,
    pubPremiumMontant: 1500,
    retraitMinimum: 100,
    monerooMethods: [],
    villesActives: ['Nairobi','Mombasa','Kisumu','Nakuru','Eldoret','Ruiru','Kikuyu','Kangundo-Tala','Malindi','Naivasha'],
    ordre: 13,
  ),
  const Pays(
    id: 'UG',
    nom: 'Ouganda',
    drapeauEmoji: '🇺�',
    region: 'afrique_est',
    actif: true,
    devise: 'UGX',
    symbole: 'USh',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: [],
    villesActives: ['Kampala','Wakiso','Mukono','Mbarara','Lugazi','Jinja','Gulu','Mbale','Mityana','Masaka'],
    ordre: 14,
  ),
  const Pays(
    id: 'TZ',
    nom: 'Tanzanie',
    drapeauEmoji: '🇹🇿',
    region: 'afrique_est',
    actif: true,
    devise: 'TZS',
    symbole: 'TSh',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: [],
    villesActives: ['Dar es Salaam','Mwanza','Arusha','Dodoma','Mbeya','Morogoro','Tanga','Kahama','Tabora','Zanzibar'],
    ordre: 15,
  ),
  // Europe
  const Pays(
    id: 'FR',
    nom: 'France',
    drapeauEmoji: '�🇫🇷',
    region: 'europe',
    actif: true,
    devise: 'EUR',
    symbole: '€',
    inscriptionMontant: 1,
    gainParrainage: 0.15,
    commissionFixeCommande: 0,
    pubStandardMontant: 3,
    pubPremiumMontant: 8,
    retraitMinimum: 5,
    monerooMethods: ['card_eur', 'crypto_eur'],
    villesActives: ['Paris','Marseille','Lyon','Toulouse','Nice','Nantes','Strasbourg','Montpellier','Bordeaux','Lille','Rennes','Reims'],
    ordre: 20,
  ),
  const Pays(
    id: 'BE',
    nom: 'Belgique',
    drapeauEmoji: '🇧🇪',
    region: 'europe',
    actif: true,
    devise: 'EUR',
    symbole: '€',
    inscriptionMontant: 1,
    gainParrainage: 0.15,
    commissionFixeCommande: 0,
    pubStandardMontant: 3,
    pubPremiumMontant: 8,
    retraitMinimum: 5,
    monerooMethods: ['card_eur', 'crypto_eur'],
    villesActives: ['Bruxelles','Anvers','Liège','Gand','Charleroi','Bruges','Namur','Louvain','Mons','Malines'],
    ordre: 21,
  ),
  // Amériques
  const Pays(
    id: 'CA',
    nom: 'Canada',
    drapeauEmoji: '🇨🇦',
    region: 'amerique',
    actif: true,
    devise: 'CAD',
    symbole: r'CA$',
    inscriptionMontant: 2,
    gainParrainage: 0.3,
    commissionFixeCommande: 0,
    pubStandardMontant: 5,
    pubPremiumMontant: 12,
    retraitMinimum: 10,
    monerooMethods: ['card_cad'],
    villesActives: ['Toronto','Montréal','Vancouver','Calgary','Edmonton','Ottawa','Québec','Winnipeg','Hamilton','Kitchener'],
    ordre: 30,
  ),
  const Pays(
    id: 'US',
    nom: 'États-Unis',
    drapeauEmoji: '🇺🇸',
    region: 'amerique',
    actif: true,
    devise: 'USD',
    symbole: r'$',
    inscriptionMontant: 2,
    gainParrainage: 0.3,
    commissionFixeCommande: 0,
    pubStandardMontant: 5,
    pubPremiumMontant: 12,
    retraitMinimum: 10,
    monerooMethods: ['card_usd', 'crypto_usd'],
    villesActives: ['New York','Los Angeles','Chicago','Houston','Phoenix','Philadelphia','San Antonio','San Diego','Dallas','San José'],
    ordre: 31,
  ),
];
