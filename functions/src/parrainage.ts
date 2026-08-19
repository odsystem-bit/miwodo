// functions/src/parrainage.ts
// Système de parrainage - Crédite 100 FCFA par filleul

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

const GAIN_PAR_PARRAINAGE = 100; // FCFA

/**
 * Cloud Function déclenchée à la création d'un prestataire
 * Vérifie si un code parrain a été utilisé et crédite le parrain
 */
export const onCreatePrestataire = functions.firestore
  .document('prestataires/{prestataireId}')
  .onCreate(async (snap, context) => {
    const prestataireId = context.params.prestataireId;
    const data = snap.data();
    
    const codeParrain = data?.parrainePar as string | undefined;
    
    // Si pas de code parrain, rien à faire
    if (!codeParrain || codeParrain.trim() === '') {
      functions.logger.info(`Prestataire ${prestataireId} créé sans parrain`);
      return null;
    }
    
    try {
      // 1. Trouver le parrain par son code
      const parrainQuery = await db
        .collection('prestataires')
        .where('codeParrain', '==', codeParrain.trim())
        .limit(1)
        .get();
      
      if (parrainQuery.empty) {
        functions.logger.warn(`Code parrain ${codeParrain} non trouvé pour prestataire ${prestataireId}`);
        return null;
      }
      
      const parrainDoc = parrainQuery.docs[0];
      const parrainId = parrainDoc.id;
      const parrainData = parrainDoc.data();
      
      // Ne pas se parrainer soi-même
      if (parrainId === prestataireId) {
        functions.logger.warn(`Auto-parrainage détecté pour ${prestataireId}`);
        return null;
      }
      
      // 2. Vérifier que ce prestataire n'a pas déjà été parrainé
      const parrainageExistant = await db
        .collection('parrainages')
        .where('filleulId', '==', prestataireId)
        .limit(1)
        .get();
      
      if (!parrainageExistant.empty) {
        functions.logger.warn(`Prestataire ${prestataireId} déjà parrainé auparavant`);
        return null;
      }
      
      // 3. Créditer le parrain dans une transaction
      await db.runTransaction(async (transaction) => {
        const parrainRef = db.collection('prestataires').doc(parrainId);
        const parrainSnap = await transaction.get(parrainRef);
        
        if (!parrainSnap.exists) {
          throw new Error(`Parrain ${parrainId} introuvable`);
        }
        
        const currentGains = (parrainSnap.data()?.gainsParrainage || 0) as number;
        const currentFilleuls = (parrainSnap.data()?.filleuls || 0) as number;
        
        // Mise à jour du parrain
        transaction.update(parrainRef, {
          gainsParrainage: currentGains + GAIN_PAR_PARRAINAGE,
          filleuls: currentFilleuls + 1,
        });
        
        // Enregistrement du parrainage
        const parrainageRef = db.collection('parrainages').doc();
        transaction.set(parrainageRef, {
          parrainId: parrainId,
          filleulId: prestataireId,
          filleulNom: `${data?.prenom || ''} ${data?.nom || ''}`.trim(),
          gain: GAIN_PAR_PARRAINAGE,
          date: admin.firestore.FieldValue.serverTimestamp(),
          status: 'complete',
        });
        
        // Notification au parrain (optionnel)
        const notifRef = db.collection('notifications').doc();
        transaction.set(notifRef, {
          userId: parrainId,
          type: 'parrainage',
          title: 'Nouveau filleul !',
          message: `Vous avez parrainé ${data?.prenom || 'un nouveau prestataire'}. +${GAIN_PAR_PARRAINAGE} FCFA crédités.`,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      
      functions.logger.info(`Parrainage réussi: ${parrainId} a parrainé ${prestataireId}, +${GAIN_PAR_PARRAINAGE} FCFA`);
      
      return {
        success: true,
        parrainId,
        gain: GAIN_PAR_PARRAINAGE,
      };
      
    } catch (error) {
      functions.logger.error(`Erreur lors du parrainage pour ${prestataireId}:`, error);
      throw error;
    }
  });

/**
 * Fonction pour générer un code parrain unique
 * Appelée via callable depuis l'app Flutter
 */
export const genererCodeParrain = functions.https.onCall(async (data, context) => {
  // Vérifier l'authentification
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise');
  }
  
  const userId = context.auth.uid;
  
  try {
    // Générer un code unique: MW + 6 caractères alphanumériques
    const code = generateUniqueCode();
    
    // Vérifier l'unicité
    const existing = await db
      .collection('prestataires')
      .where('codeParrain', '==', code)
      .limit(1)
      .get();
    
    if (!existing.empty) {
      // Si collision, réessayer une fois
      const code2 = generateUniqueCode();
      const existing2 = await db
        .collection('prestataires')
        .where('codeParrain', '==', code2)
        .limit(1)
        .get();
      
      if (!existing2.empty) {
        throw new functions.https.HttpsError('internal', 'Impossible de générer un code unique');
      }
      
      await db.collection('prestataires').doc(userId).update({
        codeParrain: code2,
      });
      
      return { code: code2, link: `https://miwodo.app/parrainage/${code2}` };
    }
    
    await db.collection('prestataires').doc(userId).update({
      codeParrain: code,
    });
    
    return { code, link: `https://miwodo.app/parrainage/${code}` };
    
  } catch (error) {
    functions.logger.error(`Erreur génération code parrain pour ${userId}:`, error);
    throw new functions.https.HttpsError('internal', 'Erreur lors de la génération du code');
  }
});

/**
 * Fonction pour récupérer les gains de parrainage
 */
export const getGainsParrainage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise');
  }
  
  const userId = context.auth.uid;
  
  try {
    const parrainSnap = await db.collection('prestataires').doc(userId).get();
    
    if (!parrainSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Prestataire introuvable');
    }
    
    const data = parrainSnap.data() || {};
    
    // Récupérer l'historique des parrainages
    const historique = await db
      .collection('parrainages')
      .where('parrainId', '==', userId)
      .orderBy('date', 'desc')
      .limit(50)
      .get();
    
    const filleuls = historique.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));
    
    return {
      gains: data.gainsParrainage || 0,
      filleulsCount: data.filleuls || 0,
      codeParrain: data.codeParrain || null,
      link: data.codeParrain ? `https://miwodo.app/parrainage/${data.codeParrain}` : null,
      historique: filleuls,
    };
    
  } catch (error) {
    functions.logger.error(`Erreur récupération gains pour ${userId}:`, error);
    throw new functions.https.HttpsError('internal', 'Erreur lors de la récupération');
  }
});

/**
 * Génère un code parrain unique aléatoire
 */
function generateUniqueCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Sans 0, O, I, 1 pour éviter confusion
  let code = 'MW';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}
