// functions/src/sponsoring_validation.ts
// Cloud Function : validation automatique intelligente des campagnes de sponsoring
// Écoute la création dans sponsoring_campaigns et déclenche l'analyse

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface SponsoringSettings {
  autoValidationActive: boolean;
  seuilConfianceAuto: number;
  seuilJournalisation: number;
  motsInterdits: string[];
  motsSuspects: string[];
  maxEmojisAutorises: number;
  maxCaracteresRepetition: number;
}

const DEFAULT_SETTINGS: SponsoringSettings = {
  autoValidationActive: true,
  seuilConfianceAuto: 95.0,
  seuilJournalisation: 80.0,
  motsInterdits: [
    'arnaque', 'escroquerie', 'fraude', 'illégal', 'drogue', 'armes', 'munition',
    'porno', 'sexe', 'escort', 'prostitution', 'casino', 'pari',
    'haine', 'raciste', 'discrimination', 'terrorisme', 'violence', 'tuer',
    'blanchiment', 'contrebande', 'trafic', 'corruption', 'extorsion',
  ],
  motsSuspects: [
    'gratuit', 'gagnez', 'cliquez ici', 'offre limitée', 'urgent', '100%',
    'garanti', 'aucun risque', 'investissement', 'crypto', 'bitcoin',
    'prêt rapide', 'crédit facile', 'sans condition', 'richesse rapide',
  ],
  maxEmojisAutorises: 5,
  maxCaracteresRepetition: 4,
};

interface ValidationCheck {
  name: string;
  passed: boolean;
  reason?: string;
  weight: number;
}

async function getSettings(): Promise<SponsoringSettings> {
  try {
    const doc = await db.collection('config').doc('sponsoring_settings').get();
    if (doc.exists) {
      return { ...DEFAULT_SETTINGS, ...doc.data() } as SponsoringSettings;
    }
    return DEFAULT_SETTINGS;
  } catch {
    return DEFAULT_SETTINGS;
  }
}

function calculateScore(checks: ValidationCheck[]): number {
  if (checks.length === 0) return 0;
  let totalWeight = 0;
  let earnedWeight = 0;
  for (const check of checks) {
    totalWeight += check.weight;
    if (check.passed) {
      earnedWeight += check.weight;
    }
  }
  if (totalWeight === 0) return 0;
  return (earnedWeight / totalWeight) * 100;
}

async function validateCampaign(
  campaignId: string,
  campaignData: admin.firestore.DocumentData
): Promise<void> {
  const settings = await getSettings();
  const checks: ValidationCheck[] = [];
  const reasons: string[] = [];

  const serviceId: string = campaignData.serviceId || '';
  const prestataireId: string = campaignData.prestataireId || '';
  const paymentId: string | null = campaignData.paymentId || null;
  const plan: string = campaignData.plan || 'standard';
  const montant: number = campaignData.montant || 0;
  const dateDebut: admin.firestore.Timestamp = campaignData.dateDebut;
  const dateFin: admin.firestore.Timestamp = campaignData.dateFin;

  // 1. Service existe
  let serviceDoc: admin.firestore.DocumentSnapshot | null = null;
  try {
    serviceDoc = await db.collection('services').doc(serviceId).get();
    if (!serviceDoc.exists) {
      reasons.push('Le service n\'existe pas');
      checks.push({ name: 'service_exists', passed: false, reason: 'Service introuvable', weight: 2.0 });
    } else {
      checks.push({ name: 'service_exists', passed: true, weight: 2.0 });
    }
  } catch (e) {
    reasons.push('Erreur vérification service');
    checks.push({ name: 'service_exists', passed: false, reason: String(e), weight: 2.0 });
  }

  // 2. Propriété du service
  if (serviceDoc && serviceDoc.exists) {
    const serviceData = serviceDoc.data()!;
    const owner = serviceData.prestataireId || serviceData.prestataire_id || '';
    if (owner !== prestataireId) {
      reasons.push('Le prestataire n\'est pas propriétaire du service');
      checks.push({ name: 'service_ownership', passed: false, reason: 'Propriétaire mismatch', weight: 2.0 });
    } else {
      checks.push({ name: 'service_ownership', passed: true, weight: 2.0 });
    }
  } else {
    checks.push({ name: 'service_ownership', passed: false, reason: 'Service introuvable', weight: 2.0 });
  }

  // 3. Paiement confirmé
  if (!paymentId || paymentId.isEmpty) {
    reasons.push('Aucun paiement associé');
    checks.push({ name: 'payment_confirmed', passed: false, reason: 'PaymentId manquant', weight: 2.0 });
  } else {
    checks.push({ name: 'payment_confirmed', passed: true, weight: 2.0 });
  }

  // 4-8. Vérifications du contenu du service
  if (serviceDoc && serviceDoc.exists) {
    const sd = serviceDoc.data()!;
    const nom: string = (sd.nom || '').trim();
    const description: string = (sd.description || '').trim();
    const images: string[] = sd.images || [];
    const prixMin: number | null = sd.prixMin ?? null;
    const prixMax: number | null = sd.prixMax ?? null;

    // 4. Complétude
    const completenessIssues: string[] = [];
    if (nom.length < 3) completenessIssues.push('titre trop court');
    if (description.isEmpty) completenessIssues.push('description manquante');
    if (prixMin === null && prixMax === null) completenessIssues.push('prix manquant');
    if (images.length === 0) completenessIssues.push('aucune image');
    if (completenessIssues.length > 0) {
      reasons.push(`Service incomplet: ${completenessIssues.join(', ')}`);
      checks.push({ name: 'service_completeness', passed: false, reason: completenessIssues.join(', '), weight: 1.5 });
    } else {
      checks.push({ name: 'service_completeness', passed: true, weight: 1.5 });
    }

    // 5. Images valides
    const invalidUrls = images.filter((url: string) => !url.startsWith('http://') && !url.startsWith('https://'));
    if (images.length === 0) {
      reasons.push('Aucune image');
      checks.push({ name: 'images_valid', passed: false, reason: 'Aucune image', weight: 1.0 });
    } else if (invalidUrls.length > 0) {
      reasons.push(`${invalidUrls.length} image(s) avec URL invalide`);
      checks.push({ name: 'images_valid', passed: false, reason: 'URLs invalides', weight: 1.0 });
    } else {
      checks.push({ name: 'images_valid', passed: true, weight: 1.0 });
    }

    // 6. Cohérence du contenu
    const coherenceIssues: string[] = [];
    if (nom.replace(/[\s\W]/g, '').length === 0) coherenceIssues.push('nom incohérent');
    if (description.length > 0 && description.length < 10) coherenceIssues.push('description trop courte');
    if (nom === description && nom.length > 0) coherenceIssues.push('nom et description identiques');
    if (coherenceIssues.length > 0) {
      reasons.push(`Contenu incohérent: ${coherenceIssues.join(', ')}`);
      checks.push({ name: 'content_coherent', passed: false, reason: coherenceIssues.join(', '), weight: 1.0 });
    } else {
      checks.push({ name: 'content_coherent', passed: true, weight: 1.0 });
    }

    // 7. Contenu interdit
    const fullText = `${nom} ${description}`.toLowerCase();
    const foundForbidden = settings.motsInterdits.filter((w) => fullText.includes(w.toLowerCase()));
    if (foundForbidden.length > 0) {
      reasons.push(`Contenu interdit: ${foundForbidden.join(', ')}`);
      checks.push({ name: 'forbidden_content', passed: false, reason: `Mots interdits: ${foundForbidden.join(', ')}`, weight: 2.5 });
    } else {
      const foundSuspicious = settings.motsSuspects.filter((w) => fullText.includes(w.toLowerCase()));
      if (foundSuspicious.length > 0) {
        checks.push({ name: 'forbidden_content', passed: true, reason: `Mots suspects: ${foundSuspicious.join(', ')}`, weight: 0.7 });
      } else {
        checks.push({ name: 'forbidden_content', passed: true, weight: 2.5 });
      }
    }

    // 8. Spam
    const spamIssues: string[] = [];
    const repRegex = new RegExp(`(.)\\1{${settings.maxCaracteresRepetition},}`);
    if (repRegex.test(fullText)) spamIssues.push('répétition excessive');
    const upperCount = fullText.replace(/[^A-Z]/g, '').length;
    const letterCount = fullText.replace(/[^A-Za-z]/g, '').length;
    if (letterCount > 10 && upperCount / letterCount > 0.5) spamIssues.push('majuscules excessives');
    if (spamIssues.length > 0) {
      reasons.push(`Spam: ${spamIssues.join(', ')}`);
      checks.push({ name: 'spam_content', passed: false, reason: spamIssues.join(', '), weight: 1.5 });
    } else {
      checks.push({ name: 'spam_content', passed: true, weight: 1.5 });
    }
  }

  // 9. Doublon de campagne active
  try {
    const dupSnap = await db
      .collection('sponsoring_campaigns')
      .where('serviceId', '==', serviceId)
      .where('statut', '==', 'active')
      .get();
    const duplicates = dupSnap.docs.filter((d) => d.id !== campaignId);
    if (duplicates.length > 0) {
      reasons.push('Une campagne active existe déjà pour ce service');
      checks.push({ name: 'no_duplicate_active', passed: false, reason: 'Doublon', weight: 1.5 });
    } else {
      checks.push({ name: 'no_duplicate_active', passed: true, weight: 1.5 });
    }
  } catch (e) {
    checks.push({ name: 'no_duplicate_active', passed: false, reason: String(e), weight: 1.5 });
  }

  // 10. Prestataire actif
  try {
    const prestDoc = await db.collection('prestataires').doc(prestataireId).get();
    if (!prestDoc.exists) {
      reasons.push('Compte prestataire introuvable');
      checks.push({ name: 'prestataire_active', passed: false, reason: 'Introuvable', weight: 2.0 });
    } else if (!prestDoc.data()?.actif) {
      reasons.push('Compte prestataire suspendu');
      checks.push({ name: 'prestataire_active', passed: false, reason: 'Suspendu', weight: 2.0 });
    } else {
      checks.push({ name: 'prestataire_active', passed: true, weight: 2.0 });
    }
  } catch (e) {
    checks.push({ name: 'prestataire_active', passed: false, reason: String(e), weight: 2.0 });
  }

  // 11. Dates cohérentes
  const now = new Date();
  const debut = dateDebut.toDate();
  const fin = dateFin.toDate();
  const durationDays = (fin.getTime() - debut.getTime()) / (1000 * 60 * 60 * 24);
  const dateIssues: string[] = [];
  if (debut > fin) dateIssues.push('date début après fin');
  if (fin < now) dateIssues.push('date fin passée');
  if (durationDays > 90) dateIssues.push('durée > 90 jours');
  if (durationDays < 1) dateIssues.push('durée < 1 jour');
  if (dateIssues.length > 0) {
    reasons.push(`Dates incohérentes: ${dateIssues.join(', ')}`);
    checks.push({ name: 'dates_coherent', passed: false, reason: dateIssues.join(', '), weight: 1.0 });
  } else {
    checks.push({ name: 'dates_coherent', passed: true, weight: 1.0 });
  }

  // 12. Budget et plan
  const budgetIssues: string[] = [];
  if (montant <= 0) budgetIssues.push('montant invalide');
  if (plan !== 'standard' && plan !== 'premium') budgetIssues.push('plan invalide');
  if (plan === 'standard' && montant < 500) budgetIssues.push('montant trop bas');
  if (plan === 'premium' && montant < 1000) budgetIssues.push('montant trop bas');
  if (budgetIssues.length > 0) {
    reasons.push(`Budget/plan: ${budgetIssues.join(', ')}`);
    checks.push({ name: 'budget_plan', passed: false, reason: budgetIssues.join(', '), weight: 1.0 });
  } else {
    checks.push({ name: 'budget_plan', passed: true, weight: 1.0 });
  }

  // Calcul du score
  const score = calculateScore(checks);
  const autoApproved = settings.autoValidationActive && score >= settings.seuilConfianceAuto && reasons.length === 0;

  // Journaliser
  const logData = {
    campaignId,
    serviceId,
    serviceName: campaignData.serviceName || '',
    prestataireId,
    prestataireNom: campaignData.prestataireNom || '',
    score,
    mode: autoApproved ? 'automatique' : 'manuelle',
    checks,
    reasons,
    autoApproved,
    analyseLe: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection('sponsoring_validation_logs').add(logData);

  // Appliquer la décision
  if (autoApproved) {
    // Activer la campagne
    await db.collection('sponsoring_campaigns').doc(campaignId).update({
      statut: 'active',
      modifieLe: admin.firestore.FieldValue.serverTimestamp(),
      adminNote: `Validation automatique (score: ${score.toFixed(1)}%)`,
    });

    // Activer le sponsoring sur le service
    await db.collection('services').doc(serviceId).update({
      sponsorise: true,
      sponsoringPlan: plan,
      sponsoringExpireLe: dateFin,
      sponsoringCampaignId: campaignId,
    });

    // Notifier le prestataire
    await db.collection('notifications').add({
      userId: prestataireId,
      title: 'Campagne approuvée automatiquement',
      body: `Votre campagne pour "${campaignData.serviceName}" a été approuvée automatiquement (score: ${score.toFixed(1)}%).`,
      type: 'sponsoring_auto_approved',
      estLu: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[SponsoringValidation] Campaign ${campaignId} auto-approved (score: ${score.toFixed(1)}%)`);
  } else {
    // Notifier les admins
    const adminsSnap = await db.collection('admins').where('actif', '==', true).get();
    for (const adminDoc of adminsSnap.docs) {
      await db.collection('notifications').add({
        userId: adminDoc.id,
        title: 'Campagne à vérifier',
        body: `La campagne "${campaignData.serviceName}" (${campaignData.prestataireNom}) nécessite une vérification. Score: ${score.toFixed(1)}%. Raisons: ${reasons.join(', ')}`,
        type: 'sponsoring_manual_review',
        estLu: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    console.log(`[SponsoringValidation] Campaign ${campaignId} sent to manual review (score: ${score.toFixed(1)}%, reasons: ${reasons.length})`);
  }
}

/**
 * Trigger Firestore : à chaque création dans sponsoring_campaigns
 * Déclenche la validation automatique intelligente.
 */
export const onSponsoringCampaignCreated = functions.firestore
  .document('sponsoring_campaigns/{campaignId}')
  .onCreate(async (snap, context) => {
    const campaignData = snap.data();
    if (!campaignData) {
      console.log('[SponsoringValidation] No data in snapshot');
      return null;
    }

    const campaignId = context.params.campaignId;
    console.log(`[SponsoringValidation] Validating campaign ${campaignId}`);

    try {
      await validateCampaign(campaignId, campaignData);
    } catch (error) {
      console.error(`[SponsoringValidation] Error validating campaign ${campaignId}:`, error);
    }

    return null;
  });
