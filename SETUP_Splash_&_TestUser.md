# 🚀 Configuration Splash Screen & Utilisateur Test

## 1️⃣ Copier le Logo

Copie ton logo dans le dossier assets :

```powershell
# Commande PowerShell (à exécuter depuis le dossier MIWODO)
copy "C:\Users\DELL\Downloads\WhatsApp Image 2026-06-12 at 07.12.40.jpeg" assets\images\logo.png
```

**Ou manuellement :**
- Va dans `C:\Users\DELL\Downloads\`
- Copie l'image `WhatsApp Image 2026-06-12 at 07.12.40.jpeg`
- Colle-la dans `c:\Users\DELL\Desktop\MIWODO\assets\images\`
- Renomme-la en `logo.png`

## 2️⃣ Déployer les Cloud Functions

```bash
# Depuis le dossier MIWODO (racine du projet)
cd c:\Users\DELL\Desktop\MIWODO
firebase deploy --only functions
```

## 3️⃣ Créer l'Utilisateur de Test

**Option A : Via la Cloud Function (après déploiement)**
```bash
# Appeler la fonction HTTP
curl https://us-central1-miwodo-84ee5.cloudfunctions.net/createTestAccount
```

**Option B : Manuellement dans Firebase Console**
1. Va sur [Firebase Console](https://console.firebase.google.com)
2. Authentication → Users → Add User
3. Email : `test@miwodo.com`
4. Password : `Test123456`
5. Firestore → Collection `prestataires` → Ajouter document avec ID = UID de l'utilisateur

## 4️⃣ Test Login

| Champ | Valeur |
|-------|--------|
| Email | `test@miwodo.com` |
| Password | `Test123456` |

## 🎨 Splash Screen Animation

Le splash screen est maintenant configuré avec :
- Animation **scale** du logo (zoom progressif)
- Animation **fade** du texte
- Couleur de fond orange (`AppColors.primaryOrange`)
- Transition automatique vers `/accueil` après 3 secondes

**Fichiers créés/modifiés :**
- `lib/screens/splash/splash_screen.dart` ✅
- `lib/core/router/app_router.dart` ✅ (route `/splash` comme initial)
- `functions/src/seed.ts` ✅ (création utilisateur)
- `functions/src/index.ts` ✅ (export fonction)

## ⚠️ Important

Si l'image `logo.png` n'existe pas encore, le splash screen affichera un **"M"** par défaut avec fond blanc.

N'oublie pas de copier le logo avant de tester ! 🚀
