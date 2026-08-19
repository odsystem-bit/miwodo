# 🔥 CONFIGURATION FIREBASE - MIWODO

## Étape 1: Créer le projet Firebase

1. Va sur https://console.firebase.google.com
2. Clique sur "Ajouter un projet"
3. Nom du projet : `miwodo-app` (ou ton choix)
4. Désactive Google Analytics pour l'instant
5. Clique "Créer le projet"

## Étape 2: Ajouter l'application Android

1. Dans le projet Firebase, clique sur l'icône Android (</>)
2. **Nom du package** : trouve-le dans `android/app/build.gradle` (ex: `com.example.miwodo`)
3. **Surnom** : Miwodo Android
4. **Certificat SHA-1** (pour Auth) : à générer avec :
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Copie le SHA-1 de la variante `debug`

5. Télécharge `google-services.json`
6. Déplace-le dans : `android/app/google-services.json`

## Étape 3: Ajouter l'application iOS (si besoin)

1. Clique sur l'icône iOS (</>)
2. **ID de bundle** : trouve-le dans `ios/Runner.xcodeproj/project.pbxproj`
3. Télécharge `GoogleService-Info.plist`
4. Déplace-le dans : `ios/Runner/GoogleService-Info.plist`

## Étape 4: Configurer les identifiants

Dans Firebase Console > Paramètres du projet > Applications :

Copie ces valeurs et remplace dans `lib/firebase_options.dart` :

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXX',  // ← Web API Key
  authDomain: 'miwodo-app.firebaseapp.com',     // ← Auth domain
  projectId: 'miwodo-app',                      // ← Project ID
  storageBucket: 'miwodo-app.appspot.com',      // ← Storage bucket
  messagingSenderId: '123456789012',            // ← Sender ID
  appId: '1:123456789012:web:XXXXXXXXXX',       // ← App ID
);

static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXX',  // ← Android API Key (différent!)
  appId: '1:123456789012:android:XXXXXXXXXX',   // ← Android App ID
  messagingSenderId: '123456789012',
  projectId: 'miwodo-app',
  storageBucket: 'miwodo-app.appspot.com',
);

static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXX',  // ← iOS API Key
  appId: '1:123456789012:ios:XXXXXXXXXX',       // ← iOS App ID
  messagingSenderId: '123456789012',
  projectId: 'miwodo-app',
  storageBucket: 'miwodo-app.appspot.com',
  iosBundleId: 'com.example.miwodo',            // ← Bundle ID
);
```

## Étape 5: Activer les services Firebase

Dans Firebase Console, active ces services :

### 🔐 Authentication
- Méthode : **Email/Password** → Activer
- Méthode : **Google** → Activer (optionnel)

### 💾 Firestore Database
1. Clique sur "Créer une base de données"
2. Mode : **Production** (ou test pour dev)
3. Région : **europe-west** (ou la plus proche)
4. Règles de sécurité temporaires (pour dev) :
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

### 🗂️ Storage (pour les photos)
1. Activer Firebase Storage
2. Région : même que Firestore
3. Règles temporaires :
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

## Étape 6: Créer les collections Firestore

Dans Firestore, crée ces collections avec un document de test :

```
prestataires/ {test-doc}
  - nom: "Test"
  - prenom: "User"
  - telephone: "90000000"
  - categorie: "artisan"
  - zone: "Adidogomé"
  - estVerifie: false
  - actif: true
  - creeLe: timestamp

admins/ {test-admin-doc}
  - role: "super_admin"
  - nom: "Admin"
  - email: "admin@miwodo.tg"
  - actif: true
  - createdAt: timestamp
```

## Étape 7: Vérifier la connexion

Lance l'app et vérifie dans les logs :
```
[FirebaseService] Initialized
```

## 🔧 Android Gradle Configuration

Assure-toi que `android/build.gradle` contient :
```gradle
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
  }
}
```

Et `android/app/build.gradle` :
```gradle
apply plugin: 'com.google.gms.google-services'

dependencies {
  implementation platform('com.google.firebase:firebase-bom:32.7.0')
  implementation 'com.google.firebase:firebase-analytics'
}
```

## ✅ CHECKLIST

- [ ] Projet Firebase créé
- [ ] App Android ajoutée
- [ ] google-services.json téléchargé et placé
- [ ] Identifiants copiés dans firebase_options.dart
- [ ] Authentication activé (Email/Password)
- [ ] Firestore créé avec règles
- [ ] Storage créé avec règles
- [ ] Collections créées
- [ ] Test de connexion réussi

---

💡 **Besoin d'aide ?** Envoie-moi :
1. Le contenu de `google-services.json` (masque les valeurs sensibles si tu veux)
2. Ou les valeurs exactes : apiKey, projectId, appId, etc.
3. Je remplirai `firebase_options.dart` pour toi !
