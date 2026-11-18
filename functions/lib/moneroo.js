"use strict";
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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifierPaiement = exports.initierPublicite = exports.initierCommande = exports.initierInscription = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const axios_1 = __importDefault(require("axios"));
// Initialiser Firebase Admin si pas déjà fait
if (!admin.apps.length) {
    admin.initializeApp();
}
const MONEROO_API_BASE = 'https://api.moneroo.io/v1';
const db = admin.firestore();
const RATE_LIMITS = {
    inscription: { maxRequests: 3, windowMs: 60 * 60 * 1000 },
    commande: { maxRequests: 10, windowMs: 60 * 60 * 1000 },
    publicite: { maxRequests: 5, windowMs: 60 * 60 * 1000 },
    verification: { maxRequests: 30, windowMs: 60 * 1000 }, // 30/minute par IP
};
async function checkRateLimit(type, identifier) {
    const config = RATE_LIMITS[type];
    if (!config)
        return;
    const docRef = db.collection('rate_limits').doc(`${type}_${identifier}`);
    const now = Date.now();
    try {
        await db.runTransaction(async (tx) => {
            const doc = await tx.get(docRef);
            const data = doc.data() || { requests: [], lastCleanup: now };
            // Nettoyer les anciennes requêtes
            const validRequests = data.requests.filter((ts) => now - ts < config.windowMs);
            if (validRequests.length >= config.maxRequests) {
                throw new functions.https.HttpsError('resource-exhausted', `Trop de requêtes. Réessayez dans ${Math.ceil(config.windowMs / 60000)} minutes.`);
            }
            validRequests.push(now);
            tx.set(docRef, { requests: validRequests, lastCleanup: now });
        });
    }
    catch (err) {
        if (err.code === 'resource-exhausted')
            throw err;
        // En cas d'erreur Firestore, on laisse passer (fail-open pour ne pas bloquer)
        console.warn('Rate limit check failed:', err.message);
    }
}
async function getPaysConfig(paysId) {
    var _a;
    try {
        const doc = await db.collection('config').doc('pays').get();
        if (!doc.exists)
            return null;
        const items = ((_a = doc.data()) === null || _a === void 0 ? void 0 : _a.items) || [];
        return items.find((p) => p.id === paysId && p.actif) || null;
    }
    catch (err) {
        console.error('Erreur lecture config pays:', err);
        return null;
    }
}
function validateMontantInscription(montant, paysConfig) {
    const expected = paysConfig.inscription_montant;
    // Tolérance de 1% pour les arrondis de devises
    const tolerance = expected * 0.01;
    if (Math.abs(montant - expected) > tolerance) {
        throw new functions.https.HttpsError('invalid-argument', `Montant invalide pour ${paysConfig.id}. Attendu: ${expected} ${paysConfig.devise}`);
    }
}
function validateMethods(methods, paysConfig) {
    const allowed = paysConfig.moneroo_methods;
    const invalid = methods.filter((m) => !allowed.includes(m));
    if (invalid.length > 0) {
        throw new functions.https.HttpsError('invalid-argument', `Méthodes de paiement non autorisées pour ${paysConfig.id}: ${invalid.join(', ')}`);
    }
}
// ═══════════════════════════════════════════════════════════════════════════
// GESTION ERREURS RÉSEAU — Plus granulaire
// ═══════════════════════════════════════════════════════════════════════════
function handleMonerooError(err) {
    var _a, _b;
    if (axios_1.default.isAxiosError(err)) {
        const axiosErr = err;
        const status = (_a = axiosErr.response) === null || _a === void 0 ? void 0 : _a.status;
        const data = (_b = axiosErr.response) === null || _b === void 0 ? void 0 : _b.data;
        const message = (data === null || data === void 0 ? void 0 : data.message) || (data === null || data === void 0 ? void 0 : data.error) || axiosErr.message;
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
function getSecret() {
    const key = process.env.MONEROO_SECRET_KEY;
    if (!key)
        throw new functions.https.HttpsError('failed-precondition', 'Clé Moneroo non configurée');
    return key;
}
function getClientIP(context) {
    var _a, _b, _c;
    return ((_a = context.rawRequest) === null || _a === void 0 ? void 0 : _a.ip) || ((_c = (_b = context.rawRequest) === null || _b === void 0 ? void 0 : _b.headers['x-forwarded-for']) === null || _c === void 0 ? void 0 : _c.toString().split(',')[0]) || 'unknown';
}
// ═══════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════
exports.initierInscription = functions.https.onCall(async (data, context) => {
    const clientIP = getClientIP(context);
    // Rate limiting
    await checkRateLimit('inscription', clientIP);
    const { prenom, nom, email, telephone, pays_id = 'TG', devise = 'XOF', montant = 500, methods = ['moov_tg', 'togocel'], } = data || {};
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
            amount: paysConfig.inscription_montant,
            currency: paysConfig.devise,
            description: 'Inscription prestataire Miwodo',
            customer: { email, first_name: prenom, last_name: nom, phone: telephone },
            methods: methods,
            return_url: 'https://miwodo.app/payment/callback',
            metadata: { type: 'inscription', telephone, pays_id }
        };
        const resp = await axios_1.default.post(`${MONEROO_API_BASE}/payments/initialize`, body, {
            headers: { Authorization: `Bearer ${secret}` },
            timeout: 15000, // 15s timeout
        });
        const result = resp.data || {};
        return { id: result.id, checkout_url: result.checkout_url };
    }
    catch (err) {
        handleMonerooError(err);
    }
});
exports.initierCommande = functions.https.onCall(async (data, context) => {
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
            amount: montant,
            currency: paysConfig.devise,
            description: `Commande Miwodo #${commandeId}`,
            customer: { email: clientEmail, first_name: clientPrenom, last_name: clientNom },
            methods: paysConfig.moneroo_methods,
            return_url: 'https://miwodo.app/payment/callback',
            metadata: { type: 'commande', commande_id: commandeId, pays_id }
        };
        const resp = await axios_1.default.post(`${MONEROO_API_BASE}/payments/initialize`, body, {
            headers: { Authorization: `Bearer ${secret}` },
            timeout: 15000,
        });
        const result = resp.data || {};
        return { id: result.id, checkout_url: result.checkout_url };
    }
    catch (err) {
        handleMonerooError(err);
    }
});
exports.initierPublicite = functions.https.onCall(async (data, context) => {
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
            amount,
            currency: paysConfig.devise,
            description: `Publicité ${plan} - Miwodo`,
            customer: { email: prestataireEmail, first_name: prestataireNom, last_name: prestataireNom },
            methods: paysConfig.moneroo_methods,
            return_url: 'https://miwodo.app/payment/callback',
            metadata: { type: 'publicite', plan, pays_id }
        };
        const resp = await axios_1.default.post(`${MONEROO_API_BASE}/payments/initialize`, body, {
            headers: { Authorization: `Bearer ${secret}` },
            timeout: 15000,
        });
        const result = resp.data || {};
        return { id: result.id, checkout_url: result.checkout_url };
    }
    catch (err) {
        handleMonerooError(err);
    }
});
exports.verifierPaiement = functions.https.onCall(async (data, context) => {
    const clientIP = getClientIP(context);
    await checkRateLimit('verification', clientIP);
    const { paymentId } = data || {};
    if (!paymentId || typeof paymentId !== 'string' || paymentId.length > 100) {
        throw new functions.https.HttpsError('invalid-argument', 'paymentId invalide');
    }
    const secret = getSecret();
    try {
        const resp = await axios_1.default.get(`${MONEROO_API_BASE}/payments/${encodeURIComponent(paymentId)}`, {
            headers: { Authorization: `Bearer ${secret}` },
            timeout: 10000,
        });
        const result = resp.data || {};
        return { id: result.id, status: result.status, amount: result.amount };
    }
    catch (err) {
        handleMonerooError(err);
    }
});
