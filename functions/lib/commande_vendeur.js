"use strict";
// functions/src/commande_vendeur.ts
// Cloud Functions pour la gestion des commandes vendeur, escrow et litiges
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onLitigeCreated = exports.onCommandeUpdate = exports.monerooWebhookCommande = exports.rembourserClient = exports.libererEscrowVendeur = exports.autoConfirmDeliveries = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
// ═══════════════════════════════════════════════════════════════════════════
// CONFIRMATION AUTOMATIQUE (24H APRÈS LIVRAISON)
// ═══════════════════════════════════════════════════════════════════════════
/**
 * Fonction planifiée qui s'exécute toutes les heures pour vérifier
 * les commandes livrées depuis plus de 24h sans confirmation client
 * et les confirme automatiquement.
 */
exports.autoConfirmDeliveries = functions.pubsub
    .schedule('every 1 hours')
    .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const twentyFourHoursAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);
    // Récupérer les commandes livrées depuis plus de 24h sans confirmation client
    const snapshot = await db
        .collection('commandes')
        .where('statut', '==', 'livre')
        .where('confirmationClient', '==', false)
        .where('confirmationLivreurAt', '<=', twentyFourHoursAgo)
        .get();
    if (snapshot.empty) {
        console.log('Aucune commande à confirmer automatiquement');
        return null;
    }
    console.log(`${snapshot.size} commande(s) à confirmer automatiquement`);
    const batch = db.batch();
    for (const doc of snapshot.docs) {
        const commande = doc.data();
        // Mettre à jour la commande
        batch.update(doc.ref, {
            statut: 'confirme',
            escrowStatut: 'libere',
            confirmationClient: true,
            confirmationClientAt: now,
            autoConfirmed: true,
            autoConfirmedAt: now,
        });
        // Créditer le solde vendeur
        const soldeRef = db.collection('soldes_vendeurs').doc(commande.vendeurId);
        batch.set(soldeRef, {
            soldeDisponible: admin.firestore.FieldValue.increment(commande.montantVendeur),
            soldeEnAttente: admin.firestore.FieldValue.increment(-commande.montantVendeur),
            totalEncaisse: admin.firestore.FieldValue.increment(commande.montantVendeur),
            nbCommandesTerminees: admin.firestore.FieldValue.increment(1),
            updatedAt: now,
        }, { merge: true });
        // Créditer le solde livreur (frais de livraison)
        const soldeLivreurRef = db.collection('soldes_vendeurs').doc(commande.livreurId);
        batch.set(soldeLivreurRef, {
            soldeDisponible: admin.firestore.FieldValue.increment(commande.fraisLivraison),
            soldeEnAttente: admin.firestore.FieldValue.increment(-commande.fraisLivraison),
            totalEncaisse: admin.firestore.FieldValue.increment(commande.fraisLivraison),
            nbLivraisonsTerminees: admin.firestore.FieldValue.increment(1),
            updatedAt: now,
        }, { merge: true });
        console.log(`Commande ${commande.numero} confirmée automatiquement`);
    }
    await batch.commit();
    console.log('Batch de confirmation automatique terminé');
    return null;
});
// ═══════════════════════════════════════════════════════════════════════════
// LIBÉRATION ESCROW (CALLABLE)
// ═══════════════════════════════════════════════════════════════════════════
/**
 * Fonction appelable pour libérer l'escrow vers le vendeur
 * Utilisée par l'admin pour résoudre un litige en faveur du vendeur
 */
exports.libererEscrowVendeur = functions.https.onCall(async (data, context) => {
    var _a;
    // Vérifier l'authentification admin
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentification requise');
    }
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists || ((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Accès admin requis');
    }
    const { commandeId, noteAdmin } = data;
    if (!commandeId) {
        throw new functions.https.HttpsError('invalid-argument', 'commandeId requis');
    }
    const commandeRef = db.collection('commandes').doc(commandeId);
    const commandeDoc = await commandeRef.get();
    if (!commandeDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Commande introuvable');
    }
    const commande = commandeDoc.data();
    if (commande.escrowStatut !== 'en_attente') {
        throw new functions.https.HttpsError('failed-precondition', 'Escrow déjà traité');
    }
    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    // Mettre à jour la commande
    batch.update(commandeRef, {
        statut: 'confirme',
        escrowStatut: 'libere',
        litigeResolvedAt: now,
        litigeResolvedBy: context.auth.uid,
        litigeNoteAdmin: noteAdmin || '',
        litigeResolution: 'vendeur',
    });
    // Créditer le vendeur
    const soldeVendeurRef = db.collection('soldes_vendeurs').doc(commande.vendeurId);
    batch.set(soldeVendeurRef, {
        soldeDisponible: admin.firestore.FieldValue.increment(commande.montantVendeur),
        soldeEnAttente: admin.firestore.FieldValue.increment(-commande.montantVendeur),
        totalEncaisse: admin.firestore.FieldValue.increment(commande.montantVendeur),
        nbCommandesTerminees: admin.firestore.FieldValue.increment(1),
        updatedAt: now,
    }, { merge: true });
    // Créditer le livreur
    const soldeLivreurRef = db.collection('soldes_vendeurs').doc(commande.livreurId);
    batch.set(soldeLivreurRef, {
        soldeDisponible: admin.firestore.FieldValue.increment(commande.fraisLivraison),
        soldeEnAttente: admin.firestore.FieldValue.increment(-commande.fraisLivraison),
        totalEncaisse: admin.firestore.FieldValue.increment(commande.fraisLivraison),
        nbLivraisonsTerminees: admin.firestore.FieldValue.increment(1),
        updatedAt: now,
    }, { merge: true });
    await batch.commit();
    // TODO: Envoyer notification au vendeur et livreur
    return { success: true, message: 'Escrow libéré vers le vendeur' };
});
// ═══════════════════════════════════════════════════════════════════════════
// REMBOURSEMENT CLIENT (CALLABLE)
// ═══════════════════════════════════════════════════════════════════════════
/**
 * Fonction appelable pour rembourser le client
 * Utilisée par l'admin pour résoudre un litige en faveur du client
 */
exports.rembourserClient = functions.https.onCall(async (data, context) => {
    var _a;
    // Vérifier l'authentification admin
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentification requise');
    }
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists || ((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Accès admin requis');
    }
    const { commandeId, noteAdmin } = data;
    if (!commandeId) {
        throw new functions.https.HttpsError('invalid-argument', 'commandeId requis');
    }
    const commandeRef = db.collection('commandes').doc(commandeId);
    const commandeDoc = await commandeRef.get();
    if (!commandeDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Commande introuvable');
    }
    const commande = commandeDoc.data();
    if (commande.escrowStatut !== 'en_attente') {
        throw new functions.https.HttpsError('failed-precondition', 'Escrow déjà traité');
    }
    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    // Mettre à jour la commande
    batch.update(commandeRef, {
        statut: 'rembourse',
        escrowStatut: 'rembourse',
        litigeResolvedAt: now,
        litigeResolvedBy: context.auth.uid,
        litigeNoteAdmin: noteAdmin || '',
        litigeResolution: 'client',
    });
    // Retirer des soldes en attente
    const soldeVendeurRef = db.collection('soldes_vendeurs').doc(commande.vendeurId);
    batch.set(soldeVendeurRef, {
        soldeEnAttente: admin.firestore.FieldValue.increment(-commande.montantVendeur),
        nbRemboursements: admin.firestore.FieldValue.increment(1),
        updatedAt: now,
    }, { merge: true });
    const soldeLivreurRef = db.collection('soldes_vendeurs').doc(commande.livreurId);
    batch.set(soldeLivreurRef, {
        soldeEnAttente: admin.firestore.FieldValue.increment(-commande.fraisLivraison),
        updatedAt: now,
    }, { merge: true });
    await batch.commit();
    // TODO: Initier le remboursement via Moneroo
    // TODO: Envoyer notification au client
    return { success: true, message: 'Client remboursé' };
});
// ═══════════════════════════════════════════════════════════════════════════
// WEBHOOK MONEROO - PAIEMENT COMMANDE
// ═══════════════════════════════════════════════════════════════════════════
/**
 * Webhook appelé par Moneroo lors de la confirmation d'un paiement
 */
exports.monerooWebhookCommande = functions.https.onRequest(async (req, res) => {
    // Vérifier la signature Moneroo (à implémenter selon leur doc)
    const signature = req.headers['x-moneroo-signature'];
    // TODO: Valider la signature
    const { event, data } = req.body;
    if (event !== 'payment.success') {
        res.status(200).json({ received: true });
        return;
    }
    const { metadata, amount, id: paymentId } = data;
    const { commandeId, type } = metadata || {};
    if (type !== 'commande_vendeur' || !commandeId) {
        res.status(200).json({ received: true });
        return;
    }
    const commandeRef = db.collection('commandes').doc(commandeId);
    const commandeDoc = await commandeRef.get();
    if (!commandeDoc.exists) {
        console.error(`Commande ${commandeId} introuvable`);
        res.status(404).json({ error: 'Commande introuvable' });
        return;
    }
    const commande = commandeDoc.data();
    // Vérifier que le montant correspond
    if (amount !== commande.totalClient) {
        console.error(`Montant incorrect: ${amount} vs ${commande.totalClient}`);
        res.status(400).json({ error: 'Montant incorrect' });
        return;
    }
    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    // Mettre à jour la commande
    batch.update(commandeRef, {
        statut: 'paye',
        escrowStatut: 'en_attente',
        monerooPaymentId: paymentId,
        paidAt: now,
    });
    // Initialiser les soldes en attente
    const soldeVendeurRef = db.collection('soldes_vendeurs').doc(commande.vendeurId);
    batch.set(soldeVendeurRef, {
        soldeEnAttente: admin.firestore.FieldValue.increment(commande.montantVendeur),
        nbCommandesEnCours: admin.firestore.FieldValue.increment(1),
        updatedAt: now,
    }, { merge: true });
    const soldeLivreurRef = db.collection('soldes_vendeurs').doc(commande.livreurId);
    batch.set(soldeLivreurRef, {
        soldeEnAttente: admin.firestore.FieldValue.increment(commande.fraisLivraison),
        nbLivraisonsEnCours: admin.firestore.FieldValue.increment(1),
        updatedAt: now,
    }, { merge: true });
    await batch.commit();
    // TODO: Envoyer notifications (vendeur, livreur, client)
    res.status(200).json({ success: true });
});
// ═══════════════════════════════════════════════════════════════════════════
// TRIGGER: CONFIRMATION DOUBLE
// ═══════════════════════════════════════════════════════════════════════════
/**
 * Trigger Firestore qui détecte quand les deux confirmations sont faites
 * et libère automatiquement l'escrow
 */
exports.onCommandeUpdate = functions.firestore
    .document('commandes/{commandeId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    // Vérifier si les deux confirmations viennent d'être complétées
    const wasNotConfirmed = !before.confirmationClient || !before.confirmationLivreur;
    const isNowConfirmed = after.confirmationClient && after.confirmationLivreur;
    if (!wasNotConfirmed || !isNowConfirmed) {
        return null;
    }
    // Vérifier que l'escrow est toujours en attente
    if (after.escrowStatut !== 'en_attente') {
        return null;
    }
    console.log(`Double confirmation détectée pour commande ${context.params.commandeId}`);
    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    // Mettre à jour la commande
    batch.update(change.after.ref, {
        statut: 'confirme',
        escrowStatut: 'libere',
        escrowReleasedAt: now,
    });
    // Créditer le vendeur
    const soldeVendeurRef = db.collection('soldes_vendeurs').doc(after.vendeurId);
    batch.set(soldeVendeurRef, {
        soldeDisponible: admin.firestore.FieldValue.increment(after.montantVendeur),
        soldeEnAttente: admin.firestore.FieldValue.increment(-after.montantVendeur),
        totalEncaisse: admin.firestore.FieldValue.increment(after.montantVendeur),
        nbCommandesTerminees: admin.firestore.FieldValue.increment(1),
        nbCommandesEnCours: admin.firestore.FieldValue.increment(-1),
        updatedAt: now,
    }, { merge: true });
    // Créditer le livreur
    const soldeLivreurRef = db.collection('soldes_vendeurs').doc(after.livreurId);
    batch.set(soldeLivreurRef, {
        soldeDisponible: admin.firestore.FieldValue.increment(after.fraisLivraison),
        soldeEnAttente: admin.firestore.FieldValue.increment(-after.fraisLivraison),
        totalEncaisse: admin.firestore.FieldValue.increment(after.fraisLivraison),
        nbLivraisonsTerminees: admin.firestore.FieldValue.increment(1),
        nbLivraisonsEnCours: admin.firestore.FieldValue.increment(-1),
        updatedAt: now,
    }, { merge: true });
    await batch.commit();
    // TODO: Envoyer notifications de confirmation finale
    console.log(`Escrow libéré pour commande ${context.params.commandeId}`);
    return null;
});
// ═══════════════════════════════════════════════════════════════════════════
// TRIGGER: NOUVEAU LITIGE
// ═══════════════════════════════════════════════════════════════════════════
/**
 * Trigger Firestore qui détecte un nouveau litige et notifie les admins
 */
exports.onLitigeCreated = functions.firestore
    .document('commandes/{commandeId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    // Vérifier si un litige vient d'être créé
    if (before.statut === 'litige' || after.statut !== 'litige') {
        return null;
    }
    console.log(`Nouveau litige détecté pour commande ${context.params.commandeId}`);
    // Créer une notification pour les admins
    const adminsSnapshot = await db.collection('users').where('role', '==', 'admin').get();
    const batch = db.batch();
    const now = admin.firestore.Timestamp.now();
    for (const adminDoc of adminsSnapshot.docs) {
        const notifRef = db.collection('notifications').doc();
        batch.set(notifRef, {
            userId: adminDoc.id,
            type: 'litige',
            title: 'Nouveau litige',
            body: `Litige signalé sur la commande ${after.numero}`,
            data: {
                commandeId: context.params.commandeId,
                numero: after.numero,
            },
            read: false,
            createdAt: now,
        });
    }
    await batch.commit();
    // TODO: Envoyer push notification aux admins
    return null;
});
