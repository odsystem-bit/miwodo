# Audit MIWODO - Rapport de Bugs

**Date:** 31 Août 2026

---

## 1. Problème de reconnexion après inscription ✅ CORRIGÉ

### Symptôme
L'utilisateur ne peut pas se reconnecter après s'être inscrit.

### Cause racine
Le login convertit le téléphone en `{telephone}@miwodo.app`, mais l'inscription crée le compte Firebase Auth avec l'email réel saisi par l'utilisateur. La connexion échoue car les identifiants ne correspondent pas.

### Correction appliquée
**Fichier:** `lib/screens/auth/login_screen_v2.dart`
- Ajout d'une recherche Firestore: quand l'utilisateur saisit un téléphone, on cherche le prestataire par `telephone` dans Firestore pour récupérer son vrai `email`
- Fallback sur `{phone}@miwodo.app` si non trouvé

---

## 2. Problème de réception de messages ✅ CORRIGÉ

### Symptôme
Les messages des clients/invités ne sont pas reçus par les prestataires.

### Causes identifiées et corrigées

#### A) _otherUserId cassé pour les conversations invité
**Fichier:** `lib/screens/conversation_screen.dart`
- Les guest IDs contiennent des underscores (ex: `guest_1234567890`)
- `widget.id.split('_')` produisait 3+ parties au lieu de 2
- **Fix:** Ajout de `_loadOtherUserId()` qui charge les participants depuis Firestore

#### B) ID de conversation non trié dans prestataire_profile_screen
**Fichier:** `lib/screens/prestataire/prestataire_profile_screen.dart`
- Le bouton "Message" créait `${p.id}_$currentUid` sans trier
- Les autres écrans trient les IDs (`ids.sort()`)
- **Fix:** Tri des IDs avant création de l'ID de conversation

#### C) _sendMessage écrasait les participants existants
**Fichier:** `lib/screens/conversation_screen.dart`
- `convRef.set({participants: [...]}, merge: true)` écrasait les participants des conversations invité
- **Fix:** Vérifier si la conversation existe avant de définir les participants

#### D) Canal Android FCM incorrect
**Fichier:** `functions/src/notifications.ts`
- La Cloud Function utilisait `miwodo_notifications` au lieu de `miwodo_default`
- **Fix:** Alignement du nom du canal avec l'app Flutter

---

## 3. Images qui ne s'affichent pas ⚠️ PARTIELLEMENT CORRIGÉ

### Symptôme
Les photos de profil et portfolio ne s'affichent pas.

### Causes identifiées

#### A) API PHP limitée aux images ✅ CORRIGÉ
**Fichier:** `server/api/upload.php`
- L'API n'acceptait que `image/jpeg, image/png, image/webp, image/gif`
- **Fix:** Ajout du support vidéo (`video/mp4`, etc.) et audio (`audio/mpeg`, etc.)
- Augmentation de la limite à 50MB pour les vidéos

#### B) CDN Hostinger intercepte /uploads/ ⚠️ ACTION SERVEUR REQUISE
- Le CDN Hostinger (hcdn) intercepte les requêtes vers `/uploads/*.jpg`
- Retourne `422 Invalid source image` au lieu de servir l'image
- **Solution:** Désactiver l'optimisation d'images du CDN pour le dossier `/uploads/`
  - Dans hPanel Hostinger → CDN → Exclure `/uploads/` de l'optimisation
  - Ou utiliser un sous-domaine (ex: `cdn.odsysteme.tech`) non proxyfié

---

## 4. Panier qui ne s'ouvre pas ✅ CORRIGÉ

### Symptôme
Après sélection des articles, le panier ne s'ouvre pas automatiquement.

### Cause
Le bouton "Ajouter" ajoutait le produit au panier mais ne proposait pas de navigation vers celui-ci.

### Correction appliquée
**Fichier:** `lib/screens/home/home_screen.dart`
- Ajout d'un `SnackBarAction` "Voir panier" avec `context.push('/panier')`

---

## Autres problèmes détectés

### 5. Avertissement Kotlin Gradle Plugin
Plugins à mettre à jour: `audioplayers_android`, `image_picker_android`, `share_plus`, `shared_preferences_android`, `webview_flutter_android`

### 6. Icône CupertinoIcons
Avertissement sur les fonts non incluses au build.

---

## Fichiers modifiés

| Fichier | Correction |
|---------|-----------|
| `lib/screens/auth/login_screen_v2.dart` | Login: recherche email par téléphone dans Firestore |
| `lib/screens/conversation_screen.dart` | _otherUserId: chargement depuis Firestore pour guests |
| `lib/screens/conversation_screen.dart` | _sendMessage: ne pas écraser les participants existants |
| `lib/screens/prestataire/prestataire_profile_screen.dart` | Tri des IDs pour ID de conversation cohérent |
| `lib/screens/home/home_screen.dart` | SnackBar "Voir panier" après ajout produit |
| `server/api/upload.php` | Support vidéo/audio + limite 50MB |
| `functions/src/notifications.ts` | Canal FCM `miwodo_default` au lieu de `miwodo_notifications` |

## Actions serveur requises

1. [ ] **CDN Hostinger:** Exclure `/uploads/` de l'optimisation d'images (hPanel → CDN)
2. [ ] **Déployer Cloud Functions:** `cd functions && npm run deploy` (correction canal FCM)
3. [ ] **Déployer API PHP:** Uploader `upload.php` mis à jour sur le serveur
