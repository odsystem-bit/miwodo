# 🔍 RAPPORT D'AUDIT MIWODO - Pré-Production

**Date:** 14 Juin 2026  
**Auditeur:** Expert Flutter Senior  
**Version:** 1.0.0+1

---

## 📊 SYNTHÈSE EXÉCUTIVE

| Catégorie | Score | Status |
|-----------|-------|--------|
| Cohérence Globale | 85/100 | ✅ Bon |
| Modèles & Firestore | 70/100 | ⚠️ À compléter |
| Sécurité Critique | 90/100 | ✅ Excellent |
| Sécurité Firestore Rules | 75/100 | ⚠️ Améliorable |
| Paiement Moneroo | 80/100 | ⚠️ Partiel |
| Navigation & UX | 85/100 | ✅ Bon |
| Design System | 75/100 | ⚠️ Mixte |
| Fonctionnalités Métier | 65/100 | ❌ Incomplet |
| Production Readiness | 70/100 | ⚠️ Moyen |

**SCORE PRODUCTION GLOBAL: 75/100**

**PRÊT POUR PROD: NON** — Plusieurs fonctionnalités métier critiques sont manquantes ou incomplètes.

---

## 🔎 DÉTAIL PAR CATÉGORIE

### AUDIT 1: COHÉRENCE GLOBALE ✅

| Point | Status | Note |
|-------|--------|------|
| Structure fichiers | ✅ OK | Tous les dossiers présents (screens/, widgets/, services/, models/, etc.) |
| Fichiers en doublon | ⚠️ ATTENTION | `inscription_screen.dart` et `inscription_screen_v2.dart` coexistent — garder uniquement v2 pour prod |
| Imports corrects | ✅ OK | Aucun import mort détecté |
| Noms de fichiers | ✅ OK | Correspondent aux imports |
| pubspec.yaml | ✅ OK | Toutes les dépendances nécessaires déclarées |
| Assets SVG | ✅ OK | `assets/icons/` déclaré dans pubspec.yaml |

**Score: 85/100**

---

### AUDIT 2: MODÈLES & FIRESTORE ⚠️

| Modèle | fromJson | toJson | Champs Firestore | Status |
|--------|----------|--------|------------------|--------|
| Prestataire | ✅ | ✅ | Partiel | ⚠️ MANQUE: `sponsorise`, `codeParrain`, `filleuls`, `gainsParrainage`, `planPub` |
| Commande | ✅ | ✅ | Partiel | ⚠️ MANQUE: `clientTel`, `fraisLivraison`, `livreurId` dans modèle vs schéma attendu |
| Produit | ✅ | ✅ | OK | ✅ Bon |
| Avis | ✅ | ✅ | OK | ✅ Bon |
| Message | ✅ | ✅ | OK | ✅ Bon |
| AdminUser | ✅ | ✅ | OK | ✅ Bon |
| Signalement | ✅ | ✅ | OK | ✅ Bon |
| TransactionRecord | ✅ | ✅ | OK | ✅ Bon |

| Fonction | Status | Note |
|----------|--------|------|
| addAvis() transaction | ✅ OK | Transaction atomique avec recalcul note_moyenne correct |
| Streams cancel | ⚠️ ATTENTION | Aucun `StreamSubscription` explicitement annulé dans les widgets — utiliser `ref.watch()` qui gère automatiquement |

**⚠️ ATTENTION — Champs manquants dans Prestataire:**
```dart
// À AJOUTER dans models/prestataire.dart:
final bool sponsorise;        // Pour section sponsorisée accueil
final String? codeParrain;    // Code de parrainage unique
final int filleuls;           // Nombre de filleuls
final double gainsParrainage; // Gains cumulés
final String? planPub;         // 'standard' | 'premium' | null
```

**Score: 70/100**

---

### AUDIT 3: SÉCURITÉ CRITIQUE — CLÉ MONEROO ✅

| Point | Status | Preuve |
|-------|--------|--------|
| Clé secrète dans Flutter | ✅ OK | Recherche `sk_`, `MONEROO_SECRET` : 0 résultats dans lib/ |
| Clé uniquement dans Cloud Functions | ✅ OK | `functions/src/moneroo.ts` ligne 7: `process.env.MONEROO_SECRET_KEY` |
| Appels Moneroo | ✅ OK | `MonerooService` utilise uniquement `httpsCallable` vers Cloud Functions |
| Pas de fetch() direct | ✅ OK | Aucun appel direct à api.moneroo.io dans le code Flutter |
| .env dans .gitignore | ❌ CRITIQUE | **PAS DANS .gitignore** — risque de commit accidentel |
| functions/.env | ⚠️ ATTENTION | Vérifier manuellement si ignoré |

**✅ EXCELLENT — La sécurité clé API est correctement implémentée.**

**❌ BLOQUANT — Ajouter immédiatement dans .gitignore:**
```
.env
.env.local
functions/.env
```

**Score: 90/100 (si .gitignore corrigé → 100/100)**

---

### AUDIT 4: SÉCURITÉ FIRESTORE RULES ⚠️

| Collection | Read | Write | Status |
|------------|------|-------|--------|
| prestataires | ✅ public | ✅ propriétaire/admin | OK |
| produits | ✅ public | ✅ vendeur | OK |
| commandes | ✅ auth | ✅ vendeur/livreur | OK |
| avis | ✅ public | ✅ auth (create only) | OK |
| messages | ✅ participants | ✅ participants | OK |
| admins | ✅ admins actifs | ✅ super_admin uniquement | ✅ Excellent |
| signalements | ✅ admins actifs | ✅ auth (create) | OK |

| Point | Status | Note |
|-------|--------|------|
| firestore.rules présent | ✅ OK | Fichier présent à la racine |
| Règles couvrent collections | ✅ OK | Toutes les collections du CDC couvertes |
| Admin protégée | ✅ OK | Super admin requis pour écriture |
| Redirect guard /admin | ✅ OK | `_adminRedirect()` dans app_router.dart |

**⚠️ ATTENTION — Règles à renforcer avant prod:**
```
// Ajouter validation de données pour éviter injection:
allow create: if request.auth != null 
  && request.auth.uid == uid
  && request.resource.data.keys().hasAll(['nom', 'prenom', 'telephone']);
```

**Score: 75/100**

---

### AUDIT 5: PAIEMENT MONEROO ⚠️

| Cloud Function | Status | Montant | Méthodes | Devise |
|----------------|--------|---------|----------|--------|
| initierInscription | ✅ OK | 500 | flooz_tg, tmoney_tg | XOF |
| initierCommande | ✅ OK | variable | flooz_tg, tmoney_tg | XOF |
| initierPublicite | ✅ OK | 2000/5000 | flooz_tg, tmoney_tg | XOF |
| verifierPaiement | ✅ OK | — | — | — |

| Point | Status | Note |
|-------|--------|------|
| Header Authorization | ✅ OK | `Authorization: Bearer ${secret}` dans CF |
| Détection paymentStatus | ⚠️ ATTENTION | MonerooWebView détecte success/failed URL mais pas de vérification serveur après retour |
| Création compte après paiement | ✅ OK | `inscription_screen_v2.dart` ligne 113-127 |
| Notification livreur | ❌ MANQUANT | Aucune logique de notification push/SMS au livreur après commande |
| Vérification serveur post-paiement | ⚠️ ATTENTION | `verifierPaiement()` existe mais appel non visible dans le flow de confirmation |

**⚠️ PRIORITÉ HAUTE:**
```dart
// Après retour WebView, AJOUTER dans inscription_screen_v2:
final result = await MonerooService.instance.verifierPaiement(paymentId);
if (result.status != 'success') {
  // Gérer échec
}
```

**Score: 80/100**

---

### AUDIT 6: NAVIGATION & UX ✅

| Point | Status | Note |
|-------|--------|------|
| 4 onglets principaux | ✅ OK | Accueil, Commander, S'inscrire, Compte |
| 5ème onglet Admin caché | ✅ OK | Visible uniquement si `adminRole != null` |
| Routes GoRouter | ✅ OK | Toutes les routes du CDC présentes |
| Bouton retour | ✅ OK | `AppBar` avec `Icons.arrow_back_ios_rounded` |
| Loading states | ⚠️ PARTIEL | Shimmer présent mais pas sur tous les écrans |
| Error states | ⚠️ PARTIEL | Pas de widget ErrorRetry générique |

**Score: 85/100**

---

### AUDIT 7: DESIGN SYSTEM ⚠️

| Point | Status | Note |
|-------|--------|------|
| Couleur orange | ⚠️ MIXTE | `AppColors.primaryOrange` utilisé MAIS aussi `Color(0xFFF97316)` hardcodé dans miwodo_logo.dart, animated_button.dart, etc. |
| TextStyle | ⚠️ MIXTE | `AppTypography` existe mais `GoogleFonts.inter` utilisé directement dans plusieurs écrans |
| Icônes SVG | ⚠️ MIXTE | `MiwodoSvgIcon` existe MAIS `Icons.xxx` encore utilisé partout (30+ occurrences) |
| Boutons | ✅ OK | `MiwodoButton` utilisé partout |
| Cartes | ✅ OK | `GlassCard` et `Card` avec radius 16px |
| Badges | ✅ OK | `BadgeVerifie` utilise bonnes couleurs |

**❌ CRITIQUE — Non conforme au CDC:**
> "icônes 100% SVG, police Inter"

**30+ occurrences de `Icons.xxx` trouvées** dans:
- inscription_steps.dart (Icons.person_outline, Icons.email_outlined, etc.)
- panier_screen.dart (Icons.radio_button_checked, etc.)
- dashboard_screen.dart (Icons.copy, Icons.share)
- moneroo_webview.dart (Icons.close)

**⚠️ PRIORITÉ HAUTE:** Remplacer TOUTES les icônes Material par des SVG équivalents.

**Score: 75/100**

---

### AUDIT 8: FONCTIONNALITÉS MÉTIER ❌

| Fonctionnalité | Status | Note |
|----------------|--------|------|
| Parrainage lien unique | ⚠️ PARTIEL | Lien généré (`miwodo.tg/ref/MW...`) mais **pas de logique de crédit 100 FCFA** |
| Crédit automatique 100 FCFA | ❌ MANQUANT | Aucune Cloud Function ni logique côté client pour créditer le parrain |
| Publication sponsorisée | ✅ PARTIEL | `sponsorisePrestataire()` existe mais pas de tri sur l'accueil |
| Recherche full-text | ⚠️ PARTIEL | Filtre sur catégorie mais pas de recherche textuelle sur nom/métier |
| 9 zones Lomé | ✅ OK | `Zones.lome` contient 9 zones exactes |
| Inscription livreur | ✅ OK | Champs `typeEngin` et `tarifZone` présents |
| Admin vérifier/sponsoriser | ✅ OK | Méthodes présentes dans FirestoreService |
| Limite 5 membres équipe | ❌ MANQUANT | Aucune validation dans `admin_equipe_screen.dart` |

**❌ BLOQUANT — Système de parrainage incomplet:**

Le CDC exige: "100 F/filleul, lien unique miwodo.tg/ref/MW[CODE]"

**Ce qui manque:**
1. Génération de code parrain unique (pas juste substring ID)
2. Stockage du `codeParrain` dans le document prestataire
3. Cloud Function `onCreatePrestataire` qui vérifie le code parrain et crédite 100 FCFA
4. Mise à jour des gains dans le dashboard du parrain

**⚠️ PRIORITÉ HAUTE:**
```typescript
// À AJOUTER dans functions/src/index.ts:
export const onCreatePrestataire = functions.firestore
  .document('prestataires/{id}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const codeParrain = data.codeParrain;
    if (codeParrain) {
      // Trouver le parrain par son code
      // Créditer 100 FCFA à son gainsParrainage
      // Incrémenter filleuls
    }
  });
```

**Score: 65/100**

---

### AUDIT 9: PRODUCTION READINESS ⚠️

| Point | Status | Note |
|-------|--------|------|
| print() hors kDebugMode | ✅ OK | Tous les print protégés par `if (kDebugMode)` |
| Clés API en dur | ✅ OK | Aucune clé sensible en dur (sauf firebase_options qui est standard) |
| .gitignore complet | ⚠️ PARTIEL | Manque `.env`, `functions/.env` |
| Versions épinglées | ✅ OK | pubspec.yaml utilise des versions fixes `^x.y.z` |
| Nom application | ⚠️ ATTENTION | AndroidManifest.xml: `android:label="miwodo"` → devrait être "Miwodo" avec majuscule |
| Permissions Android | ⚠️ PARTIEL | Pas de `INTERNET`, `READ_EXTERNAL_STORAGE` déclarés explicitement |
| Permissions iOS | ❌ MANQUANT | `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` manquantes dans Info.plist |
| Firebase Analytics | ❌ MANQUANT | Package non inclus dans pubspec.yaml |
| Firebase Crashlytics | ❌ MANQUANT | Package non inclus dans pubspec.yaml |

**❌ BLOQUANT — Permissions iOS manquantes:**
Ajouter dans `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Cette application nécessite l'accès à la caméra pour prendre des photos de vos réalisations.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Cette application nécessite l'accès à la galerie pour sélectionner des photos.</string>
```

**Score: 70/100**

---

## 🎯 LISTE DES BLOQUANTS (❌)

Avant toute mise en production, **OBLIGATOIRE**:

1. **❌ .gitignore incomplet** — Ajouter `.env` et `functions/.env`
2. **❌ Permissions iOS manquantes** — Ajouter NSCameraUsageDescription et NSPhotoLibraryUsageDescription
3. **❌ Système de parrainage incomplet** — Cloud Function manquante pour créditer 100 FCFA
4. **❌ Icônes Material non remplacées** — 30+ icônes à convertir en SVG
5. **❌ Limite 5 membres équipe non implémentée** — Validation manquante

---

## ⚠️ LISTE PRIORITÉ HAUTE

À corriger dans la semaine suivant la mise en prod:

1. **Vérification serveur post-paiement** — Appeler `verifierPaiement()` après retour WebView
2. **Notification livreur** — Envoyer notification après nouvelle commande
3. **Champs manquants Prestataire** — Ajouter sponsorise, codeParrain, filleuls, gainsParrainage
4. **Recherche full-text** — Implémenter la recherche sur nom ET métier
5. **Firebase Analytics + Crashlytics** — Ajouter pour monitoring production

---

## ✅ POINTS FORTS

- **Architecture propre** — Riverpod + GoRouter bien structuré
- **Sécurité clé API** — Moneroo correctement isolé dans Cloud Functions
- **Firestore Rules** — Bonne couverture des permissions
- **Design System v2** — Glassmorphism, animations, typographie moderne
- **Transactions Firestore** — addAvis() utilise des transactions atomiques
- **Navigation admin sécurisée** — Redirect guard fonctionnel

---

## 📋 CONCLUSION

**SCORE PRODUCTION: 75/100**

**PRÊT POUR PROD: NON**

### Délai estimé pour mise en production:
- **5 bloquants**: ~3-5 jours de travail
- **Corrections + tests**: +2-3 jours
- **Total**: **1 semaine** pour une version production-ready

### Recommandation:
**Ne pas déployer en production** avant résolution des 5 bloquants critiques. Le système de paiement fonctionne mais le parrainage (feature clé du marketing) est inopérant.

---

*Rapport généré par Expert Flutter Senior — 14 Juin 2026*
