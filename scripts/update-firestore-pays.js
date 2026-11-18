/**
 * Script Node.js pour mettre à jour config/pays dans Firestore
 * avec les méthodes Moneroo corrigées (sans card_* pour l'Afrique).
 *
 * Usage:
 *   1. Aller sur Firebase Console > Project Settings > Service Accounts
 *   2. Générer une nouvelle clé privée → sauvegarder comme scripts/serviceAccountKey.json
 *   3. Run: node scripts/update-firestore-pays.js
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Charger la clé service account
const keyPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('❌ Fichier serviceAccountKey.json introuvable dans scripts/');
  console.error('   → Firebase Console > Project Settings > Service Accounts > Generate New Private Key');
  console.error('   → Sauvegarder le fichier dans: scripts/serviceAccountKey.json');
  process.exit(1);
}

const serviceAccount = require(keyPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'miwodo-84ee5',
});

const db = admin.firestore();

// ─── Méthodes Moneroo corrigées (sans card_* pour l'Afrique) ───────────────
const paysDefaults = [
  // Afrique de l'Ouest
  { id: 'TG', nom: 'Togo', drapeau_emoji: '🇹🇬', region: 'afrique_ouest', actif: true, devise: 'XOF', symbole: 'F CFA', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: ['moov_tg', 'togocel'], villes_actives: ['Lomé','Sokodé','Kara','Kpalimé','Atakpamé','Tsévié','Aného','Bafilo','Notsé','Bassar','Dapaong','Mango'], ordre: 1 },
  { id: 'CI', nom: 'Côte d\'Ivoire', drapeau_emoji: '🇨🇮', region: 'afrique_ouest', actif: true, devise: 'XOF', symbole: 'F CFA', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: ['orange_ci', 'mtn_ci', 'moov_ci', 'wave_ci'], villes_actives: ['Abidjan','Bouaké','Yamoussoukro','Korhogo','San-Pédro','Daloa','Man','Duékoué','Abengourou','Grand-Bassam','Divo','Gagnoa'], ordre: 2 },
  { id: 'SN', nom: 'Sénégal', drapeau_emoji: '🇸🇳', region: 'afrique_ouest', actif: true, devise: 'XOF', symbole: 'F CFA', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: ['orange_sn', 'wave_sn', 'freemoney_sn'], villes_actives: ['Dakar','Touba','Thiès','Kaolack','Saint-Louis','Rufisque','Ziguinchor','Diourbel','Louga','Mbour','Tambacounda','Kaolack'], ordre: 3 },
  { id: 'BJ', nom: 'Bénin', drapeau_emoji: '🇧🇯', region: 'afrique_ouest', actif: true, devise: 'XOF', symbole: 'F CFA', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: ['mtn_bj', 'moov_bj'], villes_actives: ['Cotonou','Porto-Novo','Parakou','Abomey','Djougou','Ouidah','Savè','Bohicon','Kandi','Natitingou','Lokossa','Abomey-Calavi'], ordre: 4 },
  { id: 'GH', nom: 'Ghana', drapeau_emoji: '🇬🇭', region: 'afrique_ouest', actif: true, devise: 'GHS', symbole: 'GH₵', inscription_montant: 10, gain_parrainage: 5, commission_fixe_commande: 2, pub_standard_montant: 30, pub_premium_montant: 80, retrait_minimum: 10, moneroo_methods: ['mtn_gh', 'tigo_gh', 'vodafone_gh'], villes_actives: ['Accra','Kumasi','Tamale','Takoradi','Cape Coast','Tema','Obuasi','Koforidua','Sunyani','Ho','Wa','Bolgatanga'], ordre: 5 },
  { id: 'NG', nom: 'Nigeria', drapeau_emoji: '🇳🇬', region: 'afrique_ouest', actif: true, devise: 'NGN', symbole: '₦', inscription_montant: 500, gain_parrainage: 200, commission_fixe_commande: 100, pub_standard_montant: 3000, pub_premium_montant: 8000, retrait_minimum: 1000, moneroo_methods: ['airtel_ng'], villes_actives: ['Lagos','Abuja','Kano','Ibadan','Port Harcourt','Benin City','Kaduna','Enugu','Aba','Jos','Ilorin','Owerri'], ordre: 6 },
  { id: 'ML', nom: 'Mali', drapeau_emoji: '🇲🇱', region: 'afrique_ouest', actif: true, devise: 'XOF', symbole: 'F CFA', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: ['orange_ml'], villes_actives: ['Bamako','Sikasso','Ségou','Kayes','Mopti','Tombouctou','Gao','Koutiala','San','Bougouni'], ordre: 7 },
  { id: 'BF', nom: 'Burkina Faso', drapeau_emoji: '🇧🇫', region: 'afrique_ouest', actif: true, devise: 'XOF', symbole: 'F CFA', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: ['orange_bf', 'moov_bf'], villes_actives: ['Ouagadougou','Bobo-Dioulasso','Koudougou','Banfora','Ouahigouya','Kaya','Tenkodogo','Fada N\'Gourma','Dédougou','Dori'], ordre: 8 },
  { id: 'NE', nom: 'Niger', drapeau_emoji: '🇳🇪', region: 'afrique_ouest', actif: true, devise: 'XOF', symbole: 'F CFA', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: ['airtel_ne'], villes_actives: ['Niamey','Zinder','Maradi','Agadez','Tahoua','Diffa','Dosso','Tillabéri','Mirriah','Birni-N\'Konni'], ordre: 9 },
  { id: 'GN', nom: 'Guinée', drapeau_emoji: '🇬🇳', region: 'afrique_ouest', actif: true, devise: 'GNF', symbole: 'GNF', inscription_montant: 5000, gain_parrainage: 1000, commission_fixe_commande: 500, pub_standard_montant: 20000, pub_premium_montant: 50000, retrait_minimum: 5000, moneroo_methods: ['mtn_gn'], villes_actives: ['Conakry','Kankan','Kindia','Nzérékoré','Labé','Boké','Siguiri','Guéckédou','Mamou','Kamsar'], ordre: 10 },
  // Afrique Centrale
  { id: 'CM', nom: 'Cameroun', drapeau_emoji: '🇨🇲', region: 'afrique_centrale', actif: true, devise: 'XAF', symbole: 'F CFA', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: [], villes_actives: ['Douala','Yaoundé','Bafoussam','Garoua','Kousseri','Bamenda','Maroua','Nkongsamba','Edéa','Kribi','Buea','Limbé'], ordre: 11 },
  { id: 'GA', nom: 'Gabon', drapeau_emoji: '🇬🇦', region: 'afrique_centrale', actif: true, devise: 'XAF', symbole: 'F CFA', inscription_montant: 1000, gain_parrainage: 200, commission_fixe_commande: 200, pub_standard_montant: 4000, pub_premium_montant: 10000, retrait_minimum: 1000, moneroo_methods: [], villes_actives: ['Libreville','Port-Gentil','Franceville','Oyem','Moanda','Lambaréné','Tchibanga','Mouila','Koulamoutou','Bitam'], ordre: 12 },
  { id: 'CD', nom: 'RD Congo', drapeau_emoji: '🇨🇩', region: 'afrique_centrale', actif: true, devise: 'CDF', symbole: 'FC', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: [], villes_actives: ['Kinshasa','Lubumbashi','Goma','Mbuji-Mayi','Kananga','Kisangani','Bukavu','Likasi','Kolwezi','Matadi'], ordre: 13 },
  // Afrique de l'Est
  { id: 'KE', nom: 'Kenya', drapeau_emoji: '🇰🇪', region: 'afrique_est', actif: true, devise: 'KES', symbole: 'KSh', inscription_montant: 100, gain_parrainage: 50, commission_fixe_commande: 20, pub_standard_montant: 500, pub_premium_montant: 1500, retrait_minimum: 100, moneroo_methods: [], villes_actives: ['Nairobi','Mombasa','Kisumu','Nakuru','Eldoret','Ruiru','Kikuyu','Kangundo-Tala','Malindi','Naivasha'], ordre: 14 },
  { id: 'UG', nom: 'Ouganda', drapeau_emoji: '🇺🇬', region: 'afrique_est', actif: true, devise: 'UGX', symbole: 'USh', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: [], villes_actives: ['Kampala','Wakiso','Mukono','Mbarara','Lugazi','Jinja','Gulu','Mbale','Mityana','Masaka'], ordre: 15 },
  { id: 'TZ', nom: 'Tanzanie', drapeau_emoji: '🇹🇿', region: 'afrique_est', actif: true, devise: 'TZS', symbole: 'TSh', inscription_montant: 500, gain_parrainage: 100, commission_fixe_commande: 100, pub_standard_montant: 2000, pub_premium_montant: 5000, retrait_minimum: 500, moneroo_methods: [], villes_actives: ['Dar es Salaam','Mwanza','Arusha','Dodoma','Mbeya','Morogoro','Tanga','Kahama','Tabora','Zanzibar'], ordre: 16 },
  // Europe
  { id: 'FR', nom: 'France', drapeau_emoji: '🇫🇷', region: 'europe', actif: true, devise: 'EUR', symbole: '€', inscription_montant: 1, gain_parrainage: 0.15, commission_fixe_commande: 0, pub_standard_montant: 3, pub_premium_montant: 8, retrait_minimum: 5, moneroo_methods: ['card_eur', 'crypto_eur'], villes_actives: ['Paris','Marseille','Lyon','Toulouse','Nice','Nantes','Strasbourg','Montpellier','Bordeaux','Lille','Rennes','Reims'], ordre: 20 },
  { id: 'BE', nom: 'Belgique', drapeau_emoji: '🇧🇪', region: 'europe', actif: true, devise: 'EUR', symbole: '€', inscription_montant: 1, gain_parrainage: 0.15, commission_fixe_commande: 0, pub_standard_montant: 3, pub_premium_montant: 8, retrait_minimum: 5, moneroo_methods: ['card_eur', 'crypto_eur'], villes_actives: ['Bruxelles','Anvers','Liège','Gand','Charleroi','Bruges','Namur','Louvain','Mons','Malines'], ordre: 21 },
  // Amériques
  { id: 'CA', nom: 'Canada', drapeau_emoji: '🇨🇦', region: 'amerique', actif: true, devise: 'CAD', symbole: 'CA$', inscription_montant: 2, gain_parrainage: 0.3, commission_fixe_commande: 0, pub_standard_montant: 5, pub_premium_montant: 12, retrait_minimum: 10, moneroo_methods: ['card_cad'], villes_actives: ['Toronto','Montréal','Vancouver','Calgary','Edmonton','Ottawa','Québec','Winnipeg','Hamilton','Kitchener'], ordre: 30 },
  { id: 'US', nom: 'États-Unis', drapeau_emoji: '🇺🇸', region: 'amerique', actif: true, devise: 'USD', symbole: '$', inscription_montant: 2, gain_parrainage: 0.3, commission_fixe_commande: 0, pub_standard_montant: 5, pub_premium_montant: 12, retrait_minimum: 10, moneroo_methods: ['card_usd', 'crypto_usd'], villes_actives: ['New York','Los Angeles','Chicago','Houston','Phoenix','Philadelphia','San Antonio','San Diego','Dallas','San José'], ordre: 31 },
];

async function main() {
  console.log('🔄 Mise à jour de config/pays dans Firestore...');
  console.log(`   ${paysDefaults.length} pays à écrire`);

  try {
    await db.collection('config').doc('pays').set({ items: paysDefaults });
    console.log('✅ Firestore mis à jour avec succès !');

    // Vérification
    const doc = await db.collection('config').doc('pays').get();
    if (doc.exists) {
      const items = doc.data().items;
      const bj = items.find(p => p.id === 'BJ');
      const cm = items.find(p => p.id === 'CM');
      const fr = items.find(p => p.id === 'FR');
      console.log('\n📊 Vérification:');
      console.log(`   BJ methods: ${JSON.stringify(bj?.moneroo_methods)}`);
      console.log(`   CM methods: ${JSON.stringify(cm?.moneroo_methods)}`);
      console.log(`   FR methods: ${JSON.stringify(fr?.moneroo_methods)}`);
    }

    process.exit(0);
  } catch (err) {
    console.error('❌ Erreur:', err.message);
    process.exit(1);
  }
}

main();
