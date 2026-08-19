// services/config_service.dart
// Service pour la gestion de la configuration Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/config_models.dart';
import '../models/pays.dart';

class ConfigService {
  ConfigService._();
  static final ConfigService instance = ConfigService._();

  final _configRef = FirebaseFirestore.instance.collection('config');

  // ─── VILLES ────────────────────────────────────────────────────────────────

  Future<void> addVille(ConfigVille ville) async {
    try {
      final doc = await _configRef.doc('villes').get();
      List<Map<String, dynamic>> items = [];
      if (doc.exists && doc.data() != null) {
        items = List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
      }
      items.add(ville.toJson());
      await _configRef.doc('villes').set({'items': items});
    } catch (e) {
      if (kDebugMode) print('[ConfigService] addVille error: $e');
      rethrow;
    }
  }

  Future<void> updateVille(String villeId, Map<String, dynamic> updates) async {
    try {
      final doc = await _configRef.doc('villes').get();
      if (!doc.exists) return;
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
      final index = items.indexWhere((v) => v['id'] == villeId);
      if (index != -1) {
        items[index] = {...items[index], ...updates};
        await _configRef.doc('villes').set({'items': items});
      }
    } catch (e) {
      if (kDebugMode) print('[ConfigService] updateVille error: $e');
      rethrow;
    }
  }

  Future<void> deleteVille(String villeId) async {
    try {
      final doc = await _configRef.doc('villes').get();
      if (!doc.exists) return;
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
      items.removeWhere((v) => v['id'] == villeId);
      await _configRef.doc('villes').set({'items': items});
    } catch (e) {
      if (kDebugMode) print('[ConfigService] deleteVille error: $e');
      rethrow;
    }
  }

  // ─── ZONES ─────────────────────────────────────────────────────────────────

  Future<void> addZone(ConfigZone zone) async {
    try {
      final doc = await _configRef.doc('zones').get();
      List<Map<String, dynamic>> items = [];
      if (doc.exists && doc.data() != null) {
        items = List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
      }
      items.add(zone.toJson());
      await _configRef.doc('zones').set({'items': items});
    } catch (e) {
      if (kDebugMode) print('[ConfigService] addZone error: $e');
      rethrow;
    }
  }

  Future<void> updateZone(String zoneId, Map<String, dynamic> updates) async {
    try {
      final doc = await _configRef.doc('zones').get();
      if (!doc.exists) return;
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
      final index = items.indexWhere((z) => z['id'] == zoneId);
      if (index != -1) {
        items[index] = {...items[index], ...updates};
        await _configRef.doc('zones').set({'items': items});
      }
    } catch (e) {
      if (kDebugMode) print('[ConfigService] updateZone error: $e');
      rethrow;
    }
  }

  Future<void> deleteZone(String zoneId) async {
    try {
      final doc = await _configRef.doc('zones').get();
      if (!doc.exists) return;
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
      items.removeWhere((z) => z['id'] == zoneId);
      await _configRef.doc('zones').set({'items': items});
    } catch (e) {
      if (kDebugMode) print('[ConfigService] deleteZone error: $e');
      rethrow;
    }
  }

  Future<void> reorderZones(List<ConfigZone> zones) async {
    try {
      final items = zones.asMap().entries.map((e) {
        return e.value.copyWith(ordre: e.key + 1).toJson();
      }).toList();
      await _configRef.doc('zones').set({'items': items});
    } catch (e) {
      if (kDebugMode) print('[ConfigService] reorderZones error: $e');
      rethrow;
    }
  }

  // ─── CATÉGORIES ────────────────────────────────────────────────────────────

  Future<void> updateCategorie(String catId, Map<String, dynamic> updates) async {
    try {
      final doc = await _configRef.doc('categories').get();
      if (!doc.exists) return;
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
      final index = items.indexWhere((c) => c['id'] == catId);
      if (index != -1) {
        items[index] = {...items[index], ...updates};
        await _configRef.doc('categories').set({'items': items});
      }
    } catch (e) {
      if (kDebugMode) print('[ConfigService] updateCategorie error: $e');
      rethrow;
    }
  }

  Future<void> addSousCategorie(String catId, String sousCategorie) async {
    try {
      final doc = await _configRef.doc('categories').get();
      if (!doc.exists) return;
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
      final index = items.indexWhere((c) => c['id'] == catId);
      if (index != -1) {
        List<String> sousCats = List<String>.from(items[index]['sous_categories'] ?? []);
        if (!sousCats.contains(sousCategorie)) {
          sousCats.add(sousCategorie);
          items[index]['sous_categories'] = sousCats;
          await _configRef.doc('categories').set({'items': items});
        }
      }
    } catch (e) {
      if (kDebugMode) print('[ConfigService] addSousCategorie error: $e');
      rethrow;
    }
  }

  Future<void> removeSousCategorie(String catId, String sousCategorie) async {
    try {
      final doc = await _configRef.doc('categories').get();
      if (!doc.exists) return;
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
      final index = items.indexWhere((c) => c['id'] == catId);
      if (index != -1) {
        List<String> sousCats = List<String>.from(items[index]['sous_categories'] ?? []);
        sousCats.remove(sousCategorie);
        items[index]['sous_categories'] = sousCats;
        await _configRef.doc('categories').set({'items': items});
      }
    } catch (e) {
      if (kDebugMode) print('[ConfigService] removeSousCategorie error: $e');
      rethrow;
    }
  }

  // ─── TARIFS ────────────────────────────────────────────────────────────────

  Future<void> updateTarifs(Map<String, dynamic> updates) async {
    try {
      await _configRef.doc('tarifs').set(updates, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('[ConfigService] updateTarifs error: $e');
      rethrow;
    }
  }

  // ─── APP ───────────────────────────────────────────────────────────────────

  Future<void> updateAppConfig(Map<String, dynamic> updates) async {
    try {
      await _configRef.doc('app').set(updates, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('[ConfigService] updateAppConfig error: $e');
      rethrow;
    }
  }

  // ─── NOTIFICATIONS ─────────────────────────────────────────────────────────

  Future<void> updateNotificationsConfig(Map<String, dynamic> updates) async {
    try {
      await _configRef.doc('notifications').set(updates, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('[ConfigService] updateNotificationsConfig error: $e');
      rethrow;
    }
  }

  // ─── SPONSORING ────────────────────────────────────────────────────────────

  Future<void> updateSponsoringConfig(Map<String, dynamic> updates) async {
    try {
      await _configRef.doc('sponsoring').set(updates, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('[ConfigService] updateSponsoringConfig error: $e');
      rethrow;
    }
  }

  // ─── INITIALISATION DES DONNÉES PAR DÉFAUT ─────────────────────────────────

  Future<void> initializeDefaultConfig() async {
    try {
      // Villes
      final villesDoc = await _configRef.doc('villes').get();
      if (!villesDoc.exists) {
        await _configRef.doc('villes').set({
          'items': [
            {'id': 'lome', 'nom': 'Lomé', 'pays': 'Togo', 'actif': true, 'ordre': 1},
            {'id': 'cotonou', 'nom': 'Cotonou', 'pays': 'Bénin', 'actif': true, 'ordre': 2},
            {'id': 'abidjan', 'nom': 'Abidjan', 'pays': "Côte d'Ivoire", 'actif': true, 'ordre': 3},
            {'id': 'dakar', 'nom': 'Dakar', 'pays': 'Sénégal', 'actif': true, 'ordre': 4},
            {'id': 'accra', 'nom': 'Accra', 'pays': 'Ghana', 'actif': true, 'ordre': 5},
            {'id': 'lagos', 'nom': 'Lagos', 'pays': 'Nigeria', 'actif': true, 'ordre': 6},
            {'id': 'bamako', 'nom': 'Bamako', 'pays': 'Mali', 'actif': true, 'ordre': 7},
            {'id': 'ouagadougou', 'nom': 'Ouagadougou', 'pays': 'Burkina Faso', 'actif': true, 'ordre': 8},
            {'id': 'douala', 'nom': 'Douala', 'pays': 'Cameroun', 'actif': true, 'ordre': 9},
            {'id': 'nairobi', 'nom': 'Nairobi', 'pays': 'Kenya', 'actif': true, 'ordre': 10},
          ],
        });
      }

      // Zones
      final zonesDoc = await _configRef.doc('zones').get();
      if (!zonesDoc.exists) {
        await _configRef.doc('zones').set({
          'items': [
            {'id': 'adidogome', 'nom': 'Adidogomé', 'ville_id': 'lome', 'actif': true, 'ordre': 1},
            {'id': 'tokoin', 'nom': 'Tokoin', 'ville_id': 'lome', 'actif': true, 'ordre': 2},
            {'id': 'be', 'nom': 'Bè', 'ville_id': 'lome', 'actif': true, 'ordre': 3},
            {'id': 'kodjoviakope', 'nom': 'Kodjoviakopé', 'ville_id': 'lome', 'actif': true, 'ordre': 4},
            {'id': 'agbalepedo', 'nom': 'Agbalépédo', 'ville_id': 'lome', 'actif': true, 'ordre': 5},
            {'id': 'nyekonakpoe', 'nom': 'Nyékonakpoé', 'ville_id': 'lome', 'actif': true, 'ordre': 6},
            {'id': 'hedzranawoe', 'nom': 'Hédzranawoé', 'ville_id': 'lome', 'actif': true, 'ordre': 7},
            {'id': 'legos', 'nom': 'Légos', 'ville_id': 'lome', 'actif': true, 'ordre': 8},
            {'id': 'agoe', 'nom': 'Agoè', 'ville_id': 'lome', 'actif': true, 'ordre': 9},
            {'id': 'ganhi', 'nom': 'Ganhi', 'ville_id': 'cotonou', 'actif': true, 'ordre': 10},
            {'id': 'akpakpa', 'nom': 'Akpakpa', 'ville_id': 'cotonou', 'actif': true, 'ordre': 11},
            {'id': 'stelevie', 'nom': 'Sainte-Lévie', 'ville_id': 'cotonou', 'actif': true, 'ordre': 12},
            {'id': 'jonquet', 'nom': 'Jonquet', 'ville_id': 'cotonou', 'actif': true, 'ordre': 13},
            {'id': 'cocody', 'nom': 'Cocody', 'ville_id': 'abidjan', 'actif': true, 'ordre': 14},
            {'id': 'plateau_abj', 'nom': 'Plateau', 'ville_id': 'abidjan', 'actif': true, 'ordre': 15},
            {'id': 'yopougon', 'nom': 'Yopougon', 'ville_id': 'abidjan', 'actif': true, 'ordre': 16},
            {'id': 'treichville', 'nom': 'Treichville', 'ville_id': 'abidjan', 'actif': true, 'ordre': 17},
            {'id': 'plateau_dkr', 'nom': 'Plateau', 'ville_id': 'dakar', 'actif': true, 'ordre': 18},
            {'id': 'medina_dkr', 'nom': 'Médina', 'ville_id': 'dakar', 'actif': true, 'ordre': 19},
            {'id': 'ouakam', 'nom': 'Ouakam', 'ville_id': 'dakar', 'actif': true, 'ordre': 20},
          ],
        });
      }

      // Catégories
      final catsDoc = await _configRef.doc('categories').get();
      if (!catsDoc.exists) {
        await _configRef.doc('categories').set({
          'items': [
            {
              'id': 'artisan', 'label': 'Artisan', 'label_plural': 'Artisans',
              'icone_svg': 'ic_artisan.svg', 'actif': true, 'ordre': 1,
              'sous_categories': ['Maçon', 'Peintre', 'Plombier', 'Électricien', 'Menuisier', 'Carreleur', 'Soudeur', 'Climatisation'],
            },
            {
              'id': 'liberal', 'label': 'Libéral', 'label_plural': 'Libéraux',
              'icone_svg': 'ic_liberal.svg', 'actif': true, 'ordre': 2,
              'sous_categories': ['Avocat', 'Médecin', 'Comptable', 'Architecte', 'Notaire', 'Consultant', 'Pharmacien', 'Ingénieur'],
            },
            {
              'id': 'vendeur', 'label': 'Vendeur', 'label_plural': 'Vendeurs',
              'icone_svg': 'ic_vendeur.svg', 'actif': true, 'ordre': 3,
              'sous_categories': ['Épicerie', 'Restaurant', 'Boulangerie', 'Pharmacie', 'Quincaillerie', 'Marché'],
            },
            {
              'id': 'livreur', 'label': 'Livreur', 'label_plural': 'Livreurs',
              'icone_svg': 'ic_livreur.svg', 'actif': true, 'ordre': 4,
              'sous_categories': ['Moto', 'Voiture', 'Vélo', 'Tricycle'],
            },
          ],
        });
      }

      // Tarifs
      final tarifsDoc = await _configRef.doc('tarifs').get();
      if (!tarifsDoc.exists) {
        await _configRef.doc('tarifs').set(ConfigTarifs.defaults.toJson());
      }

      // App
      final appDoc = await _configRef.doc('app').get();
      if (!appDoc.exists) {
        await _configRef.doc('app').set(ConfigApp.defaults.toJson());
      }

      // Notifications
      final notifsDoc = await _configRef.doc('notifications').get();
      if (!notifsDoc.exists) {
        await _configRef.doc('notifications').set(ConfigNotifications.defaults.toJson());
      }

      // Sponsoring
      final sponsoDoc = await _configRef.doc('sponsoring').get();
      if (!sponsoDoc.exists) {
        await _configRef.doc('sponsoring').set(ConfigSponsoring.defaults.toJson());
      }

      if (kDebugMode) print('[ConfigService] Default config initialized');
    } catch (e) {
      if (kDebugMode) print('[ConfigService] initializeDefaultConfig error: $e');
    }
  }

  // ─── PAYS ───────────────────────────────────────────────────────────────────

  /// Upsert un pays dans config/pays.items (par son id ISO)
  Future<void> updatePays(Pays pays) async {
    try {
      final doc = await _configRef.doc('pays').get();
      List<Map<String, dynamic>> items = [];
      if (doc.exists && doc.data() != null) {
        items = List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
      }
      final index = items.indexWhere((p) => p['id'] == pays.id);
      if (index != -1) {
        items[index] = pays.toJson();
      } else {
        items.add(pays.toJson());
      }
      items.sort((a, b) => ((a['ordre'] as int?) ?? 99).compareTo((b['ordre'] as int?) ?? 99));
      await _configRef.doc('pays').set({'items': items});
    } catch (e) {
      if (kDebugMode) print('[ConfigService] updatePays error: \$e');
      rethrow;
    }
  }

  /// Seed les données pays par défaut si le document n'existe pas encore
  /// ou force la mise à jour si [force] est true
  Future<void> initializePaysDefaults({bool force = false}) async {
    try {
      final doc = await _configRef.doc('pays').get();
      if (doc.exists && !force) return;
      final defaults = [
        // Afrique de l'Ouest
        {'id':'TG','nom':'Togo','drapeau_emoji':'🇹🇬','region':'afrique_ouest','actif':true,'devise':'XOF','symbole':'F CFA','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':['moov_tg','togocel'],'villes_actives':['Lomé','Sokodé','Kara','Kpalimé','Atakpamé','Tsévié','Aného','Bafilo','Notsé','Bassar','Dapaong','Mango'],'ordre':1},
        {'id':'CI','nom':'Côte d\'Ivoire','drapeau_emoji':'🇨🇮','region':'afrique_ouest','actif':true,'devise':'XOF','symbole':'F CFA','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':['orange_ci','mtn_ci','moov_ci','wave_ci'],'villes_actives':['Abidjan','Bouaké','Yamoussoukro','Korhogo','San-Pédro','Daloa','Man','Duékoué','Abengourou','Grand-Bassam','Divo','Gagnoa'],'ordre':2},
        {'id':'SN','nom':'Sénégal','drapeau_emoji':'🇸🇳','region':'afrique_ouest','actif':true,'devise':'XOF','symbole':'F CFA','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':['orange_sn','wave_sn','freemoney_sn'],'villes_actives':['Dakar','Touba','Thiès','Kaolack','Saint-Louis','Rufisque','Ziguinchor','Diourbel','Louga','Mbour','Tambacounda','Kaolack'],'ordre':3},
        {'id':'BJ','nom':'Bénin','drapeau_emoji':'🇧🇯','region':'afrique_ouest','actif':true,'devise':'XOF','symbole':'F CFA','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':['mtn_bj','moov_bj'],'villes_actives':['Cotonou','Porto-Novo','Parakou','Abomey','Djougou','Ouidah','Savè','Bohicon','Kandi','Natitingou','Lokossa','Abomey-Calavi'],'ordre':4},
        {'id':'GH','nom':'Ghana','drapeau_emoji':'🇬🇭','region':'afrique_ouest','actif':true,'devise':'GHS','symbole':'GH₵','inscription_montant':10,'gain_parrainage':5,'commission_fixe_commande':2,'pub_standard_montant':30,'pub_premium_montant':80,'retrait_minimum':10,'moneroo_methods':['mtn_gh','tigo_gh','vodafone_gh'],'villes_actives':['Accra','Kumasi','Tamale','Takoradi','Cape Coast','Tema','Obuasi','Koforidua','Sunyani','Ho','Wa','Bolgatanga'],'ordre':5},
        {'id':'NG','nom':'Nigeria','drapeau_emoji':'🇳🇬','region':'afrique_ouest','actif':true,'devise':'NGN','symbole':'₦','inscription_montant':500,'gain_parrainage':200,'commission_fixe_commande':100,'pub_standard_montant':3000,'pub_premium_montant':8000,'retrait_minimum':1000,'moneroo_methods':['airtel_ng'],'villes_actives':['Lagos','Abuja','Kano','Ibadan','Port Harcourt','Benin City','Kaduna','Enugu','Aba','Jos','Ilorin','Owerri'],'ordre':6},
        {'id':'ML','nom':'Mali','drapeau_emoji':'🇲🇱','region':'afrique_ouest','actif':true,'devise':'XOF','symbole':'F CFA','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':['orange_ml'],'villes_actives':['Bamako','Sikasso','Ségou','Kayes','Mopti','Tombouctou','Gao','Koutiala','San','Bougouni'],'ordre':7},
        {'id':'BF','nom':'Burkina Faso','drapeau_emoji':'🇧🇫','region':'afrique_ouest','actif':true,'devise':'XOF','symbole':'F CFA','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':['orange_bf','moov_bf'],'villes_actives':['Ouagadougou','Bobo-Dioulasso','Koudougou','Banfora','Ouahigouya','Kaya','Tenkodogo','Fada N\'Gourma','Dédougou','Dori'],'ordre':8},
        {'id':'NE','nom':'Niger','drapeau_emoji':'🇳🇪','region':'afrique_ouest','actif':true,'devise':'XOF','symbole':'F CFA','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':['airtel_ne'],'villes_actives':['Niamey','Zinder','Maradi','Agadez','Tahoua','Diffa','Dosso','Tillabéri','Mirriah','Birni-N\'Konni'],'ordre':9},
        {'id':'GN','nom':'Guinée','drapeau_emoji':'🇬🇳','region':'afrique_ouest','actif':true,'devise':'GNF','symbole':'GNF','inscription_montant':5000,'gain_parrainage':1000,'commission_fixe_commande':500,'pub_standard_montant':20000,'pub_premium_montant':50000,'retrait_minimum':5000,'moneroo_methods':['mtn_gn'],'villes_actives':['Conakry','Kankan','Kindia','Nzérékoré','Labé','Boké','Siguiri','Guéckédou','Mamou','Kamsar'],'ordre':10},
        // Afrique Centrale
        {'id':'CM','nom':'Cameroun','drapeau_emoji':'🇨🇲','region':'afrique_centrale','actif':true,'devise':'XAF','symbole':'F CFA','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':[],'villes_actives':['Douala','Yaoundé','Bafoussam','Garoua','Kousseri','Bamenda','Maroua','Nkongsamba','Edéa','Kribi','Buea','Limbé'],'ordre':11},
        {'id':'GA','nom':'Gabon','drapeau_emoji':'🇬🇦','region':'afrique_centrale','actif':true,'devise':'XAF','symbole':'F CFA','inscription_montant':1000,'gain_parrainage':200,'commission_fixe_commande':200,'pub_standard_montant':4000,'pub_premium_montant':10000,'retrait_minimum':1000,'moneroo_methods':[],'villes_actives':['Libreville','Port-Gentil','Franceville','Oyem','Moanda','Lambaréné','Tchibanga','Mouila','Koulamoutou','Bitam'],'ordre':12},
        {'id':'CD','nom':'RD Congo','drapeau_emoji':'🇨🇩','region':'afrique_centrale','actif':true,'devise':'CDF','symbole':'FC','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':[],'villes_actives':['Kinshasa','Lubumbashi','Goma','Mbuji-Mayi','Kananga','Kisangani','Bukavu','Likasi','Kolwezi','Matadi'],'ordre':13},
        // Afrique de l'Est
        {'id':'KE','nom':'Kenya','drapeau_emoji':'🇰🇪','region':'afrique_est','actif':true,'devise':'KES','symbole':'KSh','inscription_montant':100,'gain_parrainage':50,'commission_fixe_commande':20,'pub_standard_montant':500,'pub_premium_montant':1500,'retrait_minimum':100,'moneroo_methods':[],'villes_actives':['Nairobi','Mombasa','Kisumu','Nakuru','Eldoret','Ruiru','Kikuyu','Kangundo-Tala','Malindi','Naivasha'],'ordre':14},
        {'id':'UG','nom':'Ouganda','drapeau_emoji':'🇺🇬','region':'afrique_est','actif':true,'devise':'UGX','symbole':'USh','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':[],'villes_actives':['Kampala','Wakiso','Mukono','Mbarara','Lugazi','Jinja','Gulu','Mbale','Mityana','Masaka'],'ordre':15},
        {'id':'TZ','nom':'Tanzanie','drapeau_emoji':'🇹🇿','region':'afrique_est','actif':true,'devise':'TZS','symbole':'TSh','inscription_montant':500,'gain_parrainage':100,'commission_fixe_commande':100,'pub_standard_montant':2000,'pub_premium_montant':5000,'retrait_minimum':500,'moneroo_methods':[],'villes_actives':['Dar es Salaam','Mwanza','Arusha','Dodoma','Mbeya','Morogoro','Tanga','Kahama','Tabora','Zanzibar'],'ordre':16},
        // Europe
        {'id':'FR','nom':'France','drapeau_emoji':'🇫🇷','region':'europe','actif':true,'devise':'EUR','symbole':'€','inscription_montant':1,'gain_parrainage':0.15,'commission_fixe_commande':0,'pub_standard_montant':3,'pub_premium_montant':8,'retrait_minimum':5,'moneroo_methods':['card_eur','crypto_eur'],'villes_actives':['Paris','Marseille','Lyon','Toulouse','Nice','Nantes','Strasbourg','Montpellier','Bordeaux','Lille','Rennes','Reims'],'ordre':20},
        {'id':'BE','nom':'Belgique','drapeau_emoji':'🇧🇪','region':'europe','actif':true,'devise':'EUR','symbole':'€','inscription_montant':1,'gain_parrainage':0.15,'commission_fixe_commande':0,'pub_standard_montant':3,'pub_premium_montant':8,'retrait_minimum':5,'moneroo_methods':['card_eur','crypto_eur'],'villes_actives':['Bruxelles','Anvers','Liège','Gand','Charleroi','Bruges','Namur','Louvain','Mons','Malines'],'ordre':21},
        // Amériques
        {'id':'CA','nom':'Canada','drapeau_emoji':'🇨🇦','region':'amerique','actif':true,'devise':'CAD','symbole':'CA\$','inscription_montant':2,'gain_parrainage':0.3,'commission_fixe_commande':0,'pub_standard_montant':5,'pub_premium_montant':12,'retrait_minimum':10,'moneroo_methods':['card_cad'],'villes_actives':['Toronto','Montréal','Vancouver','Calgary','Edmonton','Ottawa','Québec','Winnipeg','Hamilton','Kitchener'],'ordre':30},
        {'id':'US','nom':'États-Unis','drapeau_emoji':'🇺🇸','region':'amerique','actif':true,'devise':'USD','symbole':'\$','inscription_montant':2,'gain_parrainage':0.3,'commission_fixe_commande':0,'pub_standard_montant':5,'pub_premium_montant':12,'retrait_minimum':10,'moneroo_methods':['card_usd','crypto_usd'],'villes_actives':['New York','Los Angeles','Chicago','Houston','Phoenix','Philadelphia','San Antonio','San Diego','Dallas','San José'],'ordre':31},
      ];
      await _configRef.doc('pays').set({'items': defaults});
      if (kDebugMode) print('[ConfigService] Pays defaults initialized');
    } catch (e) {
      if (kDebugMode) print('[ConfigService] initializePaysDefaults error: \$e');
    }
  }
}
