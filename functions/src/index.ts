export { initierInscription, initierCommande, initierPublicite, verifierPaiement } from './moneroo';
export { onCreatePrestataire, genererCodeParrain, getGainsParrainage } from './parrainage';
export { seedTestUser, createTestUser } from './seed';
export { onNotificationCreated } from './notifications';
export { onSponsoringCampaignCreated } from './sponsoring_validation';
export { 
  autoConfirmDeliveries, 
  libererEscrowVendeur, 
  rembourserClient, 
  monerooWebhookCommande,
  onCommandeUpdate,
  onLitigeCreated 
} from './commande_vendeur';
export {
  createInitialAdmin,
  createInitialAdminHttp,
  setupAdminForExistingUser,
  onAdminDisabled,
  onAdminDeleted,
  logAdminChanges,
  addModerator,
  toggleAdmin,
  deleteAdmin,
  listAdmins,
  getAdminRole,
  hasAdmin,
} from './admin';

// Fonction HTTP pour créer un utilisateur de test
import * as functions from 'firebase-functions';
import { createTestUser } from './seed';

export const createTestAccount = functions.https.onRequest(async (req, res) => {
  // Autoriser CORS
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  
  const result = await createTestUser();
  res.json(result);
});
