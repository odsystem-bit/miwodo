"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.seedTestUser = exports.createTestUser = void 0;
// Seed script pour créer des données de test
const auth_1 = require("firebase-admin/auth");
const firestore_1 = require("firebase-admin/firestore");
const db = (0, firestore_1.getFirestore)();
const auth = (0, auth_1.getAuth)();
async function createTestUser() {
    const email = 'test@miwodo.com';
    const password = 'Test123456';
    try {
        // Vérifier si l'utilisateur existe déjà
        try {
            await auth.getUserByEmail(email);
            console.log('✅ Utilisateur de test existe déjà:', email);
            return { success: true, email, message: 'Utilisateur existant' };
        }
        catch (e) {
            // L'utilisateur n'existe pas, on le crée
        }
        // Créer l'utilisateur dans Firebase Auth
        const userRecord = await auth.createUser({
            email,
            password,
            displayName: 'Utilisateur Test',
        });
        // Créer le document prestataire dans Firestore
        await db.collection('prestataires').doc(userRecord.uid).set({
            nom: 'Dupont',
            prenom: 'Jean',
            email: email,
            telephone: '+228 90 00 00 00',
            categorie: 'coiffure',
            zone: 'Adidogome',
            description: 'Prestataire test pour Miwodo',
            tarifHoraire: 5000,
            estVerifie: true,
            estDisponible: true,
            noteMoyenne: 4.5,
            nombreAvis: 3,
            totalCommandes: 5,
            dateInscription: new Date(),
            codeParrain: 'TEST123',
            gainsParrainage: 0,
            filleuls: 0,
        });
        console.log('✅ Utilisateur de test créé avec succès!');
        console.log('📧 Email:', email);
        console.log('🔑 Password:', password);
        return {
            success: true,
            uid: userRecord.uid,
            email,
            password,
            message: 'Utilisateur créé avec succès'
        };
    }
    catch (error) {
        console.error('❌ Erreur création utilisateur:', error);
        return { success: false, error: error.message };
    }
}
exports.createTestUser = createTestUser;
// Fonction callable pour créer l'utilisateur depuis l'app
const seedTestUser = async (req, res) => {
    // Sécurité : vérifier si on est en dev uniquement
    const result = await createTestUser();
    res.json(result);
};
exports.seedTestUser = seedTestUser;
