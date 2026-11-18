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
Object.defineProperty(exports, "__esModule", { value: true });
exports.createTestAccount = exports.hasAdmin = exports.getAdminRole = exports.listAdmins = exports.deleteAdmin = exports.toggleAdmin = exports.addModerator = exports.logAdminChanges = exports.onAdminDeleted = exports.onAdminDisabled = exports.setupAdminForExistingUser = exports.createInitialAdminHttp = exports.createInitialAdmin = exports.onLitigeCreated = exports.onCommandeUpdate = exports.monerooWebhookCommande = exports.rembourserClient = exports.libererEscrowVendeur = exports.autoConfirmDeliveries = exports.createTestUser = exports.seedTestUser = exports.getGainsParrainage = exports.genererCodeParrain = exports.onCreatePrestataire = exports.verifierPaiement = exports.initierPublicite = exports.initierCommande = exports.initierInscription = void 0;
var moneroo_1 = require("./moneroo");
Object.defineProperty(exports, "initierInscription", { enumerable: true, get: function () { return moneroo_1.initierInscription; } });
Object.defineProperty(exports, "initierCommande", { enumerable: true, get: function () { return moneroo_1.initierCommande; } });
Object.defineProperty(exports, "initierPublicite", { enumerable: true, get: function () { return moneroo_1.initierPublicite; } });
Object.defineProperty(exports, "verifierPaiement", { enumerable: true, get: function () { return moneroo_1.verifierPaiement; } });
var parrainage_1 = require("./parrainage");
Object.defineProperty(exports, "onCreatePrestataire", { enumerable: true, get: function () { return parrainage_1.onCreatePrestataire; } });
Object.defineProperty(exports, "genererCodeParrain", { enumerable: true, get: function () { return parrainage_1.genererCodeParrain; } });
Object.defineProperty(exports, "getGainsParrainage", { enumerable: true, get: function () { return parrainage_1.getGainsParrainage; } });
var seed_1 = require("./seed");
Object.defineProperty(exports, "seedTestUser", { enumerable: true, get: function () { return seed_1.seedTestUser; } });
Object.defineProperty(exports, "createTestUser", { enumerable: true, get: function () { return seed_1.createTestUser; } });
var commande_vendeur_1 = require("./commande_vendeur");
Object.defineProperty(exports, "autoConfirmDeliveries", { enumerable: true, get: function () { return commande_vendeur_1.autoConfirmDeliveries; } });
Object.defineProperty(exports, "libererEscrowVendeur", { enumerable: true, get: function () { return commande_vendeur_1.libererEscrowVendeur; } });
Object.defineProperty(exports, "rembourserClient", { enumerable: true, get: function () { return commande_vendeur_1.rembourserClient; } });
Object.defineProperty(exports, "monerooWebhookCommande", { enumerable: true, get: function () { return commande_vendeur_1.monerooWebhookCommande; } });
Object.defineProperty(exports, "onCommandeUpdate", { enumerable: true, get: function () { return commande_vendeur_1.onCommandeUpdate; } });
Object.defineProperty(exports, "onLitigeCreated", { enumerable: true, get: function () { return commande_vendeur_1.onLitigeCreated; } });
var admin_1 = require("./admin");
Object.defineProperty(exports, "createInitialAdmin", { enumerable: true, get: function () { return admin_1.createInitialAdmin; } });
Object.defineProperty(exports, "createInitialAdminHttp", { enumerable: true, get: function () { return admin_1.createInitialAdminHttp; } });
Object.defineProperty(exports, "setupAdminForExistingUser", { enumerable: true, get: function () { return admin_1.setupAdminForExistingUser; } });
Object.defineProperty(exports, "onAdminDisabled", { enumerable: true, get: function () { return admin_1.onAdminDisabled; } });
Object.defineProperty(exports, "onAdminDeleted", { enumerable: true, get: function () { return admin_1.onAdminDeleted; } });
Object.defineProperty(exports, "logAdminChanges", { enumerable: true, get: function () { return admin_1.logAdminChanges; } });
Object.defineProperty(exports, "addModerator", { enumerable: true, get: function () { return admin_1.addModerator; } });
Object.defineProperty(exports, "toggleAdmin", { enumerable: true, get: function () { return admin_1.toggleAdmin; } });
Object.defineProperty(exports, "deleteAdmin", { enumerable: true, get: function () { return admin_1.deleteAdmin; } });
Object.defineProperty(exports, "listAdmins", { enumerable: true, get: function () { return admin_1.listAdmins; } });
Object.defineProperty(exports, "getAdminRole", { enumerable: true, get: function () { return admin_1.getAdminRole; } });
Object.defineProperty(exports, "hasAdmin", { enumerable: true, get: function () { return admin_1.hasAdmin; } });
// Fonction HTTP pour créer un utilisateur de test
const functions = __importStar(require("firebase-functions"));
const seed_2 = require("./seed");
exports.createTestAccount = functions.https.onRequest(async (req, res) => {
    // Autoriser CORS
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'GET, POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type');
        res.status(204).send('');
        return;
    }
    const result = await (0, seed_2.createTestUser)();
    res.json(result);
});
