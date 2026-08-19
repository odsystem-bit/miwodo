# API Paiement MIWODO — Déploiement sur hébergement mutualisé PHP/MySQL

## Structure

```
server/
├── api/
│   ├── .env              ← Vos secrets (à créer depuis .env.example)
│   ├── .env.example      ← Template
│   ├── .htaccess         ← Routing + sécurité
│   ├── config.php        ← Configuration centrale (DB, CORS, rate limiting)
│   ├── initiate.php      ← POST /initiate — initie un paiement Moneroo
│   ├── verify.php        ← POST /verify — vérifie le statut d'un paiement
│   └── webhook.php       ← POST /webhook — reçoit les webhooks Moneroo
├── migrations/
│   └── 001_payments.sql  ← Schéma MySQL à exécuter
└── README.md             ← Ce fichier
```

## Déploiement — Étapes

### 1. Créer la base de données MySQL

Dans phpMyAdmin ou via cPanel :
1. Créer une base de données (ex: `miwodo_payments`)
2. Créer un utilisateur et lui donner les privilèges sur cette base
3. Exécuter le script `migrations/001_payments.sql` dans phpMyAdmin

### 2. Uploader les fichiers PHP

Uploader le contenu du dossier `server/api/` sur votre hébergement, par exemple dans :
```
public_html/api/
```

Ou dans un sous-domaine :
```
api.miwodo.tg/
```

### 3. Configurer le fichier .env

Créer le fichier `api/.env` (à partir de `.env.example`) et remplir :

```env
MONEROO_SECRET_KEY=sk_votre_cle_moneroo
PAYMENT_API_KEY=une_cle_aleatoire_longue_pour_authentifier_l_app
DB_HOST=localhost
DB_NAME=miwodo_payments
DB_USER=votre_user
DB_PASS=votre_mot_de_passe
```

**Important :** Le fichier `.env` doit être dans le même dossier que `config.php`.

### 4. Protéger le fichier .env

Vérifier que le `.htaccess` bloque bien l'accès au `.env` (déjà configuré) :
```
<FilesMatch "^(config|\.env)">
    Require all denied
</FilesMatch>
```

### 5. Tester l'API

```bash
# Test initiate
curl -X POST https://miwodo.tg/api/initiate \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: votre_payement_api_key" \
  -d '{"type":"inscription","amount":500,"currency":"XOF","description":"Test","customer":{"email":"test@test.com","first_name":"Test","last_name":"User"},"methods":["moov_tg"],"pays_id":"TG","metadata":{"type":"inscription"}}'

# Test verify
curl -X POST https://miwodo.tg/api/verify \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: votre_payement_api_key" \
  -d '{"payment_id":"payment_id_a_verifier"}'
```

### 6. Configurer le webhook Moneroo

Dans le dashboard Moneroo, configurer l'URL du webhook :
```
https://miwodo.tg/api/webhook
```

### 7. Configurer l'app Flutter

Au build, passer les variables via `--dart-define` :
```bash
flutter run \
  --dart-define=PAYMENT_API_URL=https://miwodo.tg/api \
  --dart-define=PAYMENT_API_KEY=votre_payement_api_key
```

Ou pour un build release :
```bash
flutter build apk \
  --dart-define=PAYMENT_API_URL=https://miwodo.tg/api \
  --dart-define=PAYMENT_API_KEY=votre_payement_api_key
```

## Sécurité

- **Clé Moneroo** : Stockée uniquement dans `api/.env`, jamais exposée côté client
- **Clé API** : Authentifie l'app Flutter auprès de l'API PHP (header `X-Api-Key`)
- **Rate limiting** : Implémenté en MySQL (anti-abus)
- **Validation des montants** : Côté serveur selon le pays
- **CORS** : Seuls les domaines autorisés peuvent appeler l'API
- **Webhook** : Vérification de signature HMAC SHA256

## Endpoints

| Endpoint | Méthode | Auth | Description |
|----------|---------|------|-------------|
| `/initiate` | POST | X-Api-Key | Initie un paiement Moneroo |
| `/verify` | POST | X-Api-Key | Vérifie le statut d'un paiement |
| `/webhook` | POST | Signature Moneroo | Reçoit les notifications Moneroo |
