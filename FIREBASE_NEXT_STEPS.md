# 🔥 PROCHAINES ÉTAPES FIREBASE

## ✅ Configuration technique TERMINÉE

Fichiers configurés :
- ✅ `android/build.gradle.kts` - Plugin Firebase
- ✅ `android/app/build.gradle.kts` - Dépendances Firebase
- ✅ `android/app/google-services.json` - Fichier de config
- ✅ `lib/firebase_options.dart` - Identifiants Flutter

---

## ⚠️ ACTIVER LES SERVICES DANS FIREBASE CONSOLE

Va sur https://console.firebase.google.com/project/miwodo-84ee5

### 1️⃣ Authentication (Connexion utilisateurs)

1. Menu latéral → **Authentication**
2. Clique **"Commencer"**
3. Active **"Email/Mot de passe"** → Activer
4. (Optionnel) Active **"Google"** → Activer + configure l'écran de consentement OAuth

### 2️⃣ Firestore Database (Base de données)

1. Menu latéral → **Firestore Database**
2. Clique **"Créer une base de données"**
3. Choisis **"Mode production"** (ou test pour le dev)
4. Région : **eur3 (europe-west)**
5. Règles de sécurité temporaires (pour le développement) :

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

6. Publier les règles

### 3️⃣ Storage (Photos des prestataires)

1. Menu latéral → **Storage**
2. Clique **"Commencer"**
3. Mode production
4. Région : même que Firestore (eur3)
5. Règles temporaires :

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if true;
    }
  }
}
```

---

## 🗂️ CRÉER LES COLLECTIONS (Structure minimale)

Dans Firestore Database → Données → **"Commencer une collection"**

### Collection : `prestataires`

Crée un document test avec ces champs :

```json
{
  "nom": "Test",
  "prenom": "Prestataire",
  "telephone": "90000000",
  "email": "test@example.com",
  "categorie": "artisan",
  "zone": "Adidogomé",
  "metier": "Plombier",
  "description": "Test description",
  "estVerifie": false,
  "actif": true,
  "creeLe": (timestamp)
}
```

### Collection : `admins` (pour toi)

Crée un document avec ton UID Firebase :

1. D'abord, lance l'app et connecte-toi (ça crée un utilisateur Auth)
2. Va dans Authentication → Utilisateurs → copie l'UID
3. Crée le document dans `admins/{TON_UID}` :

```json
{
  "email": "ton-email@gmail.com",
  "nom": "Ton Nom",
  "role": "super_admin",
  "actif": true,
  "createdAt": (timestamp)
}
```

---

## 🧪 TESTER LA CONNEXION

```bash
cd C:\Users\DELL\Desktop\MIWODO
flutter pub get
flutter run
```

Dans les logs, cherche :
```
[FirebaseService] Initialized
```

Si tu vois ça → **Firebase est connecté !** 🎉

---

## 🚨 ERREURS COURANTES

### "FirebaseApp with name [DEFAULT] doesn't exist"
→ Relance `flutter clean` puis `flutter pub get`

### "Google Play services missing"
→ L'appareil/émulateur doit avoir Google Play Services à jour

### "Permission denied" dans Firestore
→ Vérifie les règles de sécurité (mets `allow read, write: if true` temporairement)

---

## 📱 POUR DÉPLOYER PLUS TARD

### Changer les règles de sécurité en production :

**Firestore :**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /prestataires/{id} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /admins/{id} {
      allow read: if request.auth != null;
      allow write: if false; // Seulement via console admin
    }
  }
}
```

**Storage :**
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /prestataires/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

✅ **Prochaine étape :** Active les 3 services dans Firebase Console puis teste avec `flutter run` !
