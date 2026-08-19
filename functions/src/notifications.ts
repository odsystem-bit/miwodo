// functions/src/notifications.ts
// Cloud Function : écoute la création de documents dans 'notifications'
// et envoie une push notification via FCM si l'utilisateur a un token device.

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Trigger Firestore : à chaque création dans /notifications/{notifId}
 * Envoie une push notification FCM au destinataire si il a un token.
 */
export const onNotificationCreated = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const notif = snap.data();

    if (!notif) {
      console.log('[onNotificationCreated] No data in snapshot');
      return null;
    }

    const userId: string = notif.userId || '';
    const title: string = notif.title || 'Miwodo';
    const body: string = notif.body || '';
    const type: string = notif.type || 'general';
    const data: Record<string, string> = {};

    // Convertir les données supplémentaires en strings pour FCM
    if (notif.data && typeof notif.data === 'object') {
      for (const [key, value] of Object.entries(notif.data)) {
        data[key] = String(value);
      }
    }
    data['type'] = type;
    data['notificationId'] = context.params.notifId;

    if (!userId) {
      console.log('[onNotificationCreated] No userId, skipping');
      return null;
    }

    try {
      // Récupérer le token FCM depuis le document prestataires ou admins
      const tokens: string[] = [];

      // Vérifier dans prestataires
      const prestataireDoc = await db.collection('prestataires').doc(userId).get();
      if (prestataireDoc.exists) {
        const token = prestataireDoc.data()?.fcmToken;
        if (token && typeof token === 'string') {
          tokens.push(token);
        }
      }

      // Vérifier dans admins (si pas trouvé dans prestataires)
      if (tokens.length === 0) {
        const adminDoc = await db.collection('admins').doc(userId).get();
        if (adminDoc.exists) {
          const token = adminDoc.data()?.fcmToken;
          if (token && typeof token === 'string') {
            tokens.push(token);
          }
        }
      }

      // Vérifier aussi dans fcm_tokens (collection alternative)
      if (tokens.length === 0) {
        const tokensSnap = await db
          .collection('fcm_tokens')
          .where('userId', '==', userId)
          .where('active', '==', true)
          .get();

        tokensSnap.docs.forEach((doc) => {
          const token = doc.data().token;
          if (token && typeof token === 'string') {
            tokens.push(token);
          }
        });
      }

      if (tokens.length === 0) {
        console.log(`[onNotificationCreated] No valid tokens for user ${userId}`);
        return null;
      }

      // Construire le message FCM
      const payload: admin.messaging.MulticastMessage = {
        notification: {
          title: title,
          body: body,
        },
        data: data,
        android: {
          notification: {
            channelId: 'miwodo_notifications',
            priority: 'high',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
        tokens: tokens,
      };

      // Envoyer le message multicast
      const response = await admin.messaging().sendEachForMulticast(payload);

      console.log(`[onNotificationCreated] Sent to ${response.successCount}/${tokens.length} tokens`);

      // Désactiver les tokens invalides
      if (response.failureCount > 0) {
        const invalidTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const error = resp.error;
            if (
              error &&
              (error.code === 'messaging/invalid-registration-token' ||
                error.code === 'messaging/registration-token-not-registered')
            ) {
              invalidTokens.push(tokens[idx]);
            }
          }
        });

        // Supprimer les tokens invalides des documents prestataires/admins
        for (const invalidToken of invalidTokens) {
          // Tentative sur prestataires
          const prestataireDocs = await db
            .collection('prestataires')
            .where('fcmToken', '==', invalidToken)
            .get();
          const batch1 = db.batch();
          prestataireDocs.docs.forEach((doc) => {
            batch1.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
          });
          await batch1.commit();

          // Tentative sur admins
          const adminDocs = await db
            .collection('admins')
            .where('fcmToken', '==', invalidToken)
            .get();
          const batch2 = db.batch();
          adminDocs.docs.forEach((doc) => {
            batch2.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
          });
          await batch2.commit();

          // Tentative sur fcm_tokens
          const tokenDocs = await db
            .collection('fcm_tokens')
            .where('token', '==', invalidToken)
            .get();
          const batch3 = db.batch();
          tokenDocs.docs.forEach((doc) => {
            batch3.update(doc.ref, { active: false });
          });
          await batch3.commit();
        }

        if (invalidTokens.length > 0) {
          console.log(`[onNotificationCreated] Deactivated ${invalidTokens.length} invalid tokens`);
        }
      }

      return null;
    } catch (error) {
      console.error('[onNotificationCreated] Error:', error);
      return null;
    }
  });
