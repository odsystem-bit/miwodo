# Migration du paiement Moneroo → MySQL

## Objectif
- Remplacer les appels actuels via Supabase/Firebase par une API backend qui enregistre les paiements dans une base MySQL.
- Conserver Firebase/Supabase uniquement pour l'envoi de notifications push (optionnel).

## Portée
- Backend minimal (Node/Express) exposant les endpoints: `/initiate`, `/verify`, `/webhook`.
- Schéma MySQL pour stocker `payment_requests` et `transactions`.
- Mise à jour client Flutter (`lib/services/moneroo_service.dart`) pour appeler l'API.
- Configuration via variables d'environnement: `PAYMENT_API_URL`, `PAYMENT_API_KEY`, `DB_*`, `MONEROO_SECRET_KEY`.

## Schéma MySQL (exemple)
```sql
CREATE TABLE payment_requests (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(128),
  amount DECIMAL(18,8) NOT NULL,
  currency VARCHAR(8) NOT NULL DEFAULT 'XMR',
  status VARCHAR(32) NOT NULL DEFAULT 'pending',
  moneroo_id VARCHAR(128),
  meta JSON NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transactions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  payment_request_id BIGINT NOT NULL,
  status VARCHAR(32) NOT NULL,
  provider_response JSON NULL,
  verified_at TIMESTAMP NULL,
  foreign key (payment_request_id) references payment_requests(id) ON DELETE CASCADE
);
```

## API Backend — contract
- POST `/initiate` — body: `{ userId, amount, currency, returnUrl }` → crée `payment_request`, appelle Moneroo, retourne `{ checkoutUrl, paymentRequestId }`.
- POST `/verify` — body: `{ paymentRequestId, monerooTxId }` → vérifie statut auprès de Moneroo et met à jour `transactions`.
- POST `/webhook` — Moneroo webhook: vérifie signature, met à jour `transactions` et `payment_requests`, envoie notification push via Firebase/Supabase si configuré.

Sécurité:
- API protégée par `PAYMENT_API_KEY` dans les headers `x-api-key`.
- Côté serveur, stocker `MONEROO_SECRET_KEY` et DB creds en variables d'environnement.

## Migration & Déploiement — étapes
1. Créer schema MySQL sur environnement de staging.
2. Développer backend minimal (Express) + tests unitaires pour endpoints.
3. Déployer backend en staging (ex: VPS, Render, Fly.io, Heroku) avec TLS.
4. Mettre à jour client Flutter: remplacer appel Supabase par `PAYMENT_API_URL` configurable.
5. Tester flux E2E sur appareil (staging): initier → ouvrir `checkoutUrl` → webhook → verify.
6. Basculer production après validation et surveiller logs.

## Rollback
- Rebasculer le client vers le mode mock (`enableMock`) si erreur critique.
- Garder scripts SQL de rollback (drop/restore) et sauvegarder DB avant migration.

## Fichiers à créer / modifier
- Backend: `server/` → `index.js`, `package.json`, `src/db.js`, `src/moneroo.js`, `src/routes/payments.js`.
- DB: `migrations/001_payments.sql`.
- Client: `lib/services/moneroo_service.dart` (ou nouveau `payments_mysql_service.dart`) — utiliser `PAYMENT_API_URL`.
- Config: `.env.example` → ajouter `PAYMENT_API_URL`, `PAYMENT_API_KEY`, `DB_HOST`, `DB_USER`, `DB_PASS`, `DB_NAME`.

## Tests recommandés
- Unit tests pour les handlers d'API et validations.
- Tests d'intégration Moneroo (mock) pour webhook et verify.
- E2E manuel sur appareil avec capture `adb logcat`.

---
Auteur: équipe Miwodo — plan initial généré automatiquement
