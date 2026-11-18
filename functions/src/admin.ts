import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialiser Firebase Admin si pas déjà fait
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

/**
 * Crée le premier administrateur super_admin de l'application.
 * Cette fonction n'est utilisable qu'une seule fois : elle vérifie qu'aucun
 * document n'existe dans la collection `admins`, et qu'un secret de setup
 * est fourni (configurable via la variable d'environnement ADMIN_SETUP_SECRET).
 */
export const createInitialAdmin = functions.https.onCall(async (data, context) => {
  // 1. Vérifier qu'il n'y a pas déjà un admin (création unique)
  const existingAdmins = await db.collection('admins').limit(1).get();
  if (!existingAdmins.empty) {
    throw new functions.https.HttpsError(
      'already-exists',
      'Un administrateur existe déjà. Utilisez le panel admin pour en créer d\'autres.'
    );
  }

  // 2. Vérifier le secret de setup
  const setupSecret = process.env.ADMIN_SETUP_SECRET;
  if (!setupSecret) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Secret de setup non configuré. Définissez ADMIN_SETUP_SECRET avant d\'appeler cette fonction.'
    );
  }
  if (data.secret !== setupSecret) {
    throw new functions.https.HttpsError('permission-denied', 'Secret de setup invalide');
  }

  // 3. Validation des données requises
  const { email, password, nom } = data || {};
  if (!email || !password || !nom) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email, mot de passe et nom sont requis'
    );
  }
  if (typeof email !== 'string' || typeof password !== 'string' || typeof nom !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Types de données invalides');
  }
  if (password.length < 8) {
    throw new functions.https.HttpsError('invalid-argument', 'Le mot de passe doit faire au moins 8 caractères');
  }

  // 4. Créer le compte Firebase Auth
  let userRecord: admin.auth.UserRecord;
  try {
    userRecord = await auth.createUser({
      email,
      password,
      displayName: nom,
    });
  } catch (err: any) {
    console.error('Erreur création admin auth:', err);
    throw new functions.https.HttpsError(
      'internal',
      `Erreur création utilisateur: ${err.message || 'inconnue'}`
    );
  }

  // 5. Créer le document admin dans Firestore
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('admins').doc(userRecord.uid).set({
    role: 'super_admin',
    nom,
    email,
    actif: true,
    createdAt: now,
    updatedAt: now,
  });

  console.log(`[Admin] Premier super_admin créé: ${email} (${userRecord.uid})`);

  return {
    uid: userRecord.uid,
    email,
    nom,
    role: 'super_admin',
  };
});

/**
 * Fonction HTTP simple (pour usage avec curl/scripts) créant le premier admin.
 * Méthode POST uniquement, protégée par le secret ADMIN_SETUP_SECRET.
 */
export const createInitialAdminHttp = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Méthode non autorisée' });
    return;
  }

  try {
    const existingAdmins = await db.collection('admins').limit(1).get();
    if (!existingAdmins.empty) {
      res.status(403).json({ error: 'Un administrateur existe déjà.' });
      return;
    }

    const setupSecret = process.env.ADMIN_SETUP_SECRET;
    if (!setupSecret) {
      res.status(500).json({ error: 'ADMIN_SETUP_SECRET non configuré' });
      return;
    }

    const { email, password, nom, secret } = req.body || {};
    if (secret !== setupSecret) {
      res.status(403).json({ error: 'Secret invalide' });
      return;
    }
    if (!email || !password || !nom || password.length < 8) {
      res.status(400).json({ error: 'Email, nom et mot de passe (8 caractères min) requis' });
      return;
    }

    const userRecord = await auth.createUser({
      email,
      password,
      displayName: nom,
    });

    const now = admin.firestore.FieldValue.serverTimestamp();
    await db.collection('admins').doc(userRecord.uid).set({
      role: 'super_admin',
      nom,
      email,
      actif: true,
      createdAt: now,
      updatedAt: now,
    });

    res.status(201).json({
      uid: userRecord.uid,
      email,
      nom,
      role: 'super_admin',
    });
  } catch (err: any) {
    console.error('Erreur création admin HTTP:', err);
    res.status(500).json({ error: err.message || 'Erreur interne' });
  }
});

/**
 * Révoque tous les tokens d'un administrateur désactivé.
 * Déclenché automatiquement quand un document admin passe actif=false.
 */
export const onAdminDisabled = functions.firestore
  .document('admins/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before?.actif === true && after?.actif === false) {
      await auth.revokeRefreshTokens(context.params.uid);
      console.log(`[Admin] Tokens révoqués pour admin désactivé: ${context.params.uid}`);
    }
  });

/**
 * Révoque les tokens d'un administrateur supprimé.
 */
export const onAdminDeleted = functions.firestore
  .document('admins/{uid}')
  .onDelete(async (snap, context) => {
    try {
      await auth.revokeRefreshTokens(context.params.uid);
      await auth.deleteUser(context.params.uid);
      console.log(`[Admin] Utilisateur supprimé: ${context.params.uid}`);
    } catch (err) {
      console.warn(`[Admin] Impossible de supprimer l'utilisateur auth ${context.params.uid}:`, err);
    }
  });

/**
 * Log toutes les actions sensibles sur les documents admin.
 */
export const logAdminChanges = functions.firestore
  .document('admins/{uid}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const eventType = !change.before.exists ? 'create' : !change.after.exists ? 'delete' : 'update';
    
    await db.collection('admin_logs').add({
      adminId: context.params.uid,
      eventType,
      before,
      after,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

/**
 * Ajoute un modérateur (super_admin uniquement).
 */
export const addModerator = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise');
  }

  const caller = await db.collection('admins').doc(context.auth.uid).get();
  if (!caller.exists || caller.data()?.role !== 'super_admin' || caller.data()?.actif !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Super admin requis');
  }

  const { email, password, nom, zone } = data || {};
  if (!email || !password || !nom || password.length < 8) {
    throw new functions.https.HttpsError('invalid-argument', 'Email, nom et mot de passe (8 caractères min) requis');
  }

  let userRecord: admin.auth.UserRecord;
  try {
    userRecord = await auth.createUser({
      email,
      password,
      displayName: nom,
    });
  } catch (err: any) {
    throw new functions.https.HttpsError('internal', err.message || 'Erreur création utilisateur');
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('admins').doc(userRecord.uid).set({
    role: 'moderateur',
    nom,
    email,
    zone: zone || null,
    actif: true,
    createdBy: context.auth.uid,
    createdAt: now,
    updatedAt: now,
  });

  return {
    uid: userRecord.uid,
    email,
    nom,
    role: 'moderateur',
  };
});

/**
 * Désactive un administrateur (super_admin uniquement, sauf soi-même).
 */
export const toggleAdmin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise');
  }

  const caller = await db.collection('admins').doc(context.auth.uid).get();
  if (!caller.exists || caller.data()?.role !== 'super_admin' || caller.data()?.actif !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Super admin requis');
  }

  const { uid, active } = data || {};
  if (!uid || typeof active !== 'boolean') {
    throw new functions.https.HttpsError('invalid-argument', 'uid et active (boolean) requis');
  }
  if (uid === context.auth.uid) {
    throw new functions.https.HttpsError('invalid-argument', 'Vous ne pouvez pas désactiver votre propre compte');
  }

  await db.collection('admins').doc(uid).update({
    actif: active,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

/**
 * Supprime un administrateur (super_admin uniquement, sauf soi-même).
 */
export const deleteAdmin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise');
  }

  const caller = await db.collection('admins').doc(context.auth.uid).get();
  if (!caller.exists || caller.data()?.role !== 'super_admin' || caller.data()?.actif !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Super admin requis');
  }

  const { uid } = data || {};
  if (!uid) {
    throw new functions.https.HttpsError('invalid-argument', 'uid requis');
  }
  if (uid === context.auth.uid) {
    throw new functions.https.HttpsError('invalid-argument', 'Vous ne pouvez pas supprimer votre propre compte');
  }

  await db.collection('admins').doc(uid).delete();
  return { success: true };
});

/**
 * Récupère la liste des administrateurs (admin actif requis).
 */
export const listAdmins = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise');
  }

  const caller = await db.collection('admins').doc(context.auth.uid).get();
  if (!caller.exists || caller.data()?.actif !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin actif requis');
  }

  const snapshot = await db.collection('admins').orderBy('createdAt', 'desc').get();
  return snapshot.docs.map((doc) => {
    const d = doc.data();
    return {
      uid: doc.id,
      role: d.role,
      nom: d.nom,
      email: d.email,
      zone: d.zone,
      actif: d.actif,
      createdAt: d.createdAt?.toMillis(),
    };
  });
});

/**
 * Vérifie si l'utilisateur authentifié est admin.
 * Retourne { role, actif } ou null.
 */
export const getAdminRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    return null;
  }
  const doc = await db.collection('admins').doc(context.auth.uid).get();
  if (!doc.exists) return null;
  const d = doc.data()!;
  return {
    uid: doc.id,
    role: d.role,
    nom: d.nom,
    email: d.email,
    zone: d.zone,
    actif: d.actif,
  };
});

/**
 * Vérifie si un administrateur existe (appel public, sans auth, pour le setup initial).
 */
export const hasAdmin = functions.https.onCall(async (data, context) => {
  const snapshot = await db.collection('admins').limit(1).get();
  return { hasAdmin: !snapshot.empty };
});

/**
 * Déclencheur pour créer le compte admin par défaut si la collection est vide.
 * Attention : ce trigger ne contient pas de mot de passe, il ne fait rien sans
 * variables d'environnement. Il sert principalement à documenter la procédure.
 */
export const ensureDefaultAdmin = functions.https.onCall(async (data, context) => {
  throw new functions.https.HttpsError(
    'unimplemented',
    'Utilisez createInitialAdmin avec ADMIN_SETUP_SECRET pour créer le premier admin.'
  );
});

/**
 * Fonction temporaire pour créer un document admin pour un utilisateur Firebase Auth existant.
 * Protégée par ADMIN_SETUP_SECRET.
 */
export const setupAdminForExistingUser = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Méthode non autorisée' });
    return;
  }

  try {
    const setupSecret = process.env.ADMIN_SETUP_SECRET;
    if (!setupSecret) {
      res.status(500).json({ error: 'ADMIN_SETUP_SECRET non configuré' });
      return;
    }

    const { uid, email, secret } = req.body || {};
    if (secret !== setupSecret) {
      res.status(403).json({ error: 'Secret invalide' });
      return;
    }
    if (!uid || !email) {
      res.status(400).json({ error: 'uid et email requis' });
      return;
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    await db.collection('admins').doc(uid).set({
      role: 'super_admin',
      email,
      actif: true,
      createdAt: now,
      updatedAt: now,
    }, { merge: true });

    res.status(200).json({
      success: true,
      uid,
      email,
      role: 'super_admin',
    });
  } catch (err: any) {
    console.error('Erreur setupAdminForExistingUser:', err);
    res.status(500).json({ error: err.message || 'Erreur interne' });
  }
});
