import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios, { AxiosError } from 'axios';

// Initialiser Firebase Admin si pas déjà fait
if (!admin.apps.length) {
  admin.initializeApp();
}

const MONEROO_API_BASE = 'https://api.moneroo.io/v1';
const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════
// RATE LIMITING — Anti-abus simple basé sur Firestore
// ═══════════════════════════════════════════════════════════════════════════

interface RateLimitConfig {
  maxRequests: number;  // Nombre max de requêtes
  windowMs: number;     // Fenêtre de temps en ms
}

const RATE_LIMITS: Record<string, RateLimitConfig> = {
  inscription: { maxRequests: 20, windowMs: 60 * 60 * 1000 },  // 20/heure par IP
  commande: { maxRequests: 30, windowMs: 60 * 60 * 1000 },    // 30/heure par IP
  publicite: { maxRequests: 15, windowMs: 60 * 60 * 1000 },    // 15/heure par IP
  verification: { maxRequests: 60, windowMs: 60 * 1000 },     // 60/minute par IP
};

async function checkRateLimit(type: string, identifier: string): Promise<void> {
  const config = RATE_LIMITS[type];
  if (!config) return;

  const docRef = db.collection('rate_limits').doc(`${type}_${identifier}`);
  const now = Date.now();

  try {
    await db.runTransaction(async (tx) => {
      const doc = await tx.get(docRef);
      const data = doc.data() || { requests: [], lastCleanup: now };
      
      // Nettoyer les anciennes requêtes
      const validRequests = (data.requests as number[]).filter(
        (ts: number) => now - ts < config.windowMs
      );

      if (validRequests.length >= config.maxRequests) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          `Trop de requêtes. Réessayez dans ${Math.ceil(config.windowMs / 60000)} minutes.`
        );
      }

      validRequests.push(now);
      tx.set(docRef, { requests: validRequests, lastCleanup: now });
    });
  } catch (err: any) {
    if (err.code === 'resource-exhausted') throw err;
    // En cas d'erreur Firestore, on laisse passer (fail-open pour ne pas bloquer)
    console.warn('Rate limit check failed:', err.message);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VALIDATION MONTANT — Vérifie que le montant correspond au pays dans Firestore
// ═══════════════════════════════════════════════════════════════════════════

interface PaysConfig {
  id: string;
  actif: boolean;
  devise: string;
  inscription_montant: number;
  pub_standard_montant: number;
  pub_premium_montant: number;
  moneroo_methods: string[];
}

async function getPaysConfig(paysId: string): Promise<PaysConfig | null> {
  try {
    const doc = await db.collection('config').doc('pays').get();
    if (!doc.exists) return null;
    
    const items = doc.data()?.items as PaysConfig[] || [];
    return items.find((p) => p.id === paysId && p.actif) || null;
  } catch (err) {
    console.error('Erreur lecture config pays:', err);
    return null;
  }
}

function validateMontantInscription(montant: number, paysConfig: PaysConfig): void {
  const expected = paysConfig.inscription_montant;
  // Tolérance de 1% pour les arrondis de devises
  const tolerance = expected * 0.01;
  
  if (Math.abs(montant - expected) > tolerance) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Montant invalide pour ${paysConfig.id}. Attendu: ${expected} ${paysConfig.devise}`
    );
  }
}

function validateMethods(methods: string[], paysConfig: PaysConfig): void {
  const allowed = paysConfig.moneroo_methods;
  const invalid = methods.filter((m) => !allowed.includes(m));
  
  if (invalid.length > 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Méthodes de paiement non autorisées pour ${paysConfig.id}: ${invalid.join(', ')}`
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GESTION ERREURS RÉSEAU — Plus granulaire
// ═══════════════════════════════════════════════════════════════════════════

function handleMonerooError(err: unknown): never {
  if (axios.isAxiosError(err)) {
    const axiosErr = err as AxiosError<{ message?: string; error?: string }>;
    const status = axiosErr.response?.status;
    const data = axiosErr.response?.data;
    const message = data?.message || data?.error || axiosErr.message;

    // Erreurs client (4xx)
    if (status === 400) {
      throw new functions.https.HttpsError('invalid-argument', `Moneroo: ${message}`);
    }
    if (status === 401 || status === 403) {
      throw new functions.https.HttpsError('permission-denied', 'Erreur d\'authentification Moneroo');
    }
    if (status === 404) {
      throw new functions.https.HttpsError('not-found', `Moneroo: ${message}`);
    }
    if (status === 429) {
      throw new functions.https.HttpsError('resource-exhausted', 'Limite Moneroo atteinte. Réessayez plus tard.');
    }

    // Erreurs serveur (5xx)
    if (status && status >= 500) {
      throw new functions.https.HttpsError('unavailable', 'Service Moneroo temporairement indisponible');
    }

    // Erreurs réseau (timeout, DNS, etc.)
    if (axiosErr.code === 'ECONNABORTED' || axiosErr.code === 'ETIMEDOUT') {
      throw new functions.https.HttpsError('deadline-exceeded', 'Timeout connexion Moneroo');
    }
    if (axiosErr.code === 'ENOTFOUND' || axiosErr.code === 'ECONNREFUSED') {
      throw new functions.https.HttpsError('unavailable', 'Impossible de joindre Moneroo');
    }

    throw new functions.https.HttpsError('internal', `Erreur Moneroo: ${message}`);
  }

  // Erreur non-Axios
  const message = err instanceof Error ? err.message : 'Erreur inconnue';
  throw new functions.https.HttpsError('internal', message);
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

function getSecret(): string {
  const key = process.env.MONEROO_SECRET_KEY;
  if (!key) throw new functions.https.HttpsError('failed-precondition', 'Clé Moneroo non configurée');
  return key;
}

function getClientIP(context: functions.https.CallableContext): string {
  return context.rawRequest?.ip || context.rawRequest?.headers['x-forwarded-for']?.toString().split(',')[0] || 'unknown';
}

// ═══════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

export const initierInscription = functions.https.onCall(async (data, context) => {
  const clientIP = getClientIP(context);
  
  // Rate limiting
  await checkRateLimit('inscription', clientIP);

  const {
    prenom, nom, email, telephone,
    pays_id = 'TG',
    devise = 'XOF',
    montant = 500,
    methods = ['moov_tg', 'togocel'],
  } = data || {};

  // Validation données requises
  if (!prenom || !nom || !telephone) {
    throw new functions.https.HttpsError('invalid-argument', 'Données manquantes pour initier l\'inscription');
  }

  // Validation du pays et du montant côté serveur
  const paysConfig = await getPaysConfig(pays_id);
  if (!paysConfig) {
    throw new functions.https.HttpsError('invalid-argument', `Pays non supporté ou inactif: ${pays_id}`);
  }

  // Vérifier que le montant correspond au pays
  validateMontantInscription(montant, paysConfig);

  // Vérifier que les méthodes sont autorisées pour ce pays
  validateMethods(methods, paysConfig);

  // Vérifier la devise
  if (devise !== paysConfig.devise) {
    throw new functions.https.HttpsError('invalid-argument', `Devise invalide. Attendu: ${paysConfig.devise}`);
  }

  const secret = getSecret();

  try {
    const body = {
      amount: Math.floor(paysConfig.inscription_montant), // Utiliser le montant serveur, pas client
      currency: paysConfig.devise,
      description: 'Inscription prestataire Miwodo',
      customer: { email, first_name: prenom, last_name: nom, phone: telephone },
      methods: methods,
      return_url: 'https://miwodo.app/payment/callback',
      metadata: { type: 'inscription', telephone, pays_id }
    };

    const resp = await axios.post(`${MONEROO_API_BASE}/payments/initialize`, body, {
      headers: { Authorization: `Bearer ${secret}` },
      timeout: 15000, // 15s timeout
    });

    const result = resp.data || {};
    return { id: result.id, checkout_url: result.checkout_url };
  } catch (err) {
    handleMonerooError(err);
  }
});

export const initierCommande = functions.https.onCall(async (data, context) => {
  const clientIP = getClientIP(context);
  await checkRateLimit('commande', clientIP);

  const { montant, clientEmail, clientPrenom, clientNom, commandeId, pays_id = 'TG' } = data || {};
  if (!montant || !commandeId) {
    throw new functions.https.HttpsError('invalid-argument', 'Données manquantes pour initier la commande');
  }

  // Valider le pays
  const paysConfig = await getPaysConfig(pays_id);
  if (!paysConfig) {
    throw new functions.https.HttpsError('invalid-argument', `Pays non supporté: ${pays_id}`);
  }

  // Valider le montant (doit être positif et raisonnable)
  if (typeof montant !== 'number' || montant <= 0 || montant > 10000000) {
    throw new functions.https.HttpsError('invalid-argument', 'Montant invalide');
  }

  const secret = getSecret();
  try {
    const body = {
      amount: Math.floor(montant),
      currency: paysConfig.devise,
      description: `Commande Miwodo #${commandeId}`,
      customer: { email: clientEmail, first_name: clientPrenom, last_name: clientNom },
      methods: paysConfig.moneroo_methods,
      return_url: 'https://miwodo.app/payment/callback',
      metadata: { type: 'commande', commande_id: commandeId, pays_id }
    };

    const resp = await axios.post(`${MONEROO_API_BASE}/payments/initialize`, body, {
      headers: { Authorization: `Bearer ${secret}` },
      timeout: 15000,
    });
    const result = resp.data || {};
    return { id: result.id, checkout_url: result.checkout_url };
  } catch (err) {
    handleMonerooError(err);
  }
});

export const initierPublicite = functions.https.onCall(async (data, context) => {
  const clientIP = getClientIP(context);
  await checkRateLimit('publicite', clientIP);

  const { plan, prestataireEmail, prestataireNom, pays_id = 'TG' } = data || {};
  if (!plan || !['standard', 'premium'].includes(plan)) {
    throw new functions.https.HttpsError('invalid-argument', 'Plan invalide (standard ou premium)');
  }

  // Valider le pays et récupérer le montant serveur
  const paysConfig = await getPaysConfig(pays_id);
  if (!paysConfig) {
    throw new functions.https.HttpsError('invalid-argument', `Pays non supporté: ${pays_id}`);
  }

  const amount = plan === 'premium' ? paysConfig.pub_premium_montant : paysConfig.pub_standard_montant;
  const secret = getSecret();

  try {
    const body = {
      amount: Math.floor(amount),
      currency: paysConfig.devise,
      description: `Publicité ${plan} - Miwodo`,
      customer: { email: prestataireEmail, first_name: prestataireNom, last_name: prestataireNom },
      methods: paysConfig.moneroo_methods,
      return_url: 'https://miwodo.app/payment/callback',
      metadata: { type: 'publicite', plan, pays_id }
    };

    const resp = await axios.post(`${MONEROO_API_BASE}/payments/initialize`, body, {
      headers: { Authorization: `Bearer ${secret}` },
      timeout: 15000,
    });
    const result = resp.data || {};
    return { id: result.id, checkout_url: result.checkout_url };
  } catch (err) {
    handleMonerooError(err);
  }
});

export const verifierPaiement = functions.https.onCall(async (data, context) => {
  const clientIP = getClientIP(context);
  await checkRateLimit('verification', clientIP);

  const { paymentId } = data || {};
  if (!paymentId || typeof paymentId !== 'string' || paymentId.length > 100) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentId invalide');
  }

  const secret = getSecret();
  try {
    const resp = await axios.get(`${MONEROO_API_BASE}/payments/${encodeURIComponent(paymentId)}`, {
      headers: { Authorization: `Bearer ${secret}` },
      timeout: 10000,
    });
    const result = resp.data || {};
    return { id: result.id, status: result.status, amount: result.amount };
  } catch (err) {
    handleMonerooError(err);
  }
});
