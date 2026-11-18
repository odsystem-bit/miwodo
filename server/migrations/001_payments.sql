-- ═══════════════════════════════════════════════════════════════════════════
-- MIWODO — Schéma MySQL pour les paiements
-- À exécuter dans phpMyAdmin ou en ligne de commande MySQL
-- ═══════════════════════════════════════════════════════════════════════════

-- Table des demandes de paiement
CREATE TABLE IF NOT EXISTS payment_requests (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  payment_id VARCHAR(128) UNIQUE,
  user_id VARCHAR(128),
  type VARCHAR(32) NOT NULL DEFAULT 'commande',
  amount DECIMAL(18,2) NOT NULL,
  currency VARCHAR(8) NOT NULL DEFAULT 'XOF',
  status VARCHAR(32) NOT NULL DEFAULT 'pending',
  moneroo_id VARCHAR(128),
  checkout_url TEXT,
  customer_email VARCHAR(255),
  customer_first_name VARCHAR(128),
  customer_last_name VARCHAR(128),
  customer_phone VARCHAR(64),
  methods VARCHAR(512),
  pays_id VARCHAR(8) DEFAULT 'TG',
  metadata JSON NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_payment_id (payment_id),
  INDEX idx_user_id (user_id),
  INDEX idx_status (status),
  INDEX idx_type (type),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des transactions (historique des vérifications)
CREATE TABLE IF NOT EXISTS transactions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  payment_request_id BIGINT NOT NULL,
  moneroo_id VARCHAR(128),
  status VARCHAR(32) NOT NULL,
  amount DECIMAL(18,2),
  provider_response JSON NULL,
  verified_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (payment_request_id) REFERENCES payment_requests(id) ON DELETE CASCADE,
  INDEX idx_payment_request_id (payment_request_id),
  INDEX idx_status (status),
  INDEX idx_moneroo_id (moneroo_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table de rate limiting (anti-abus)
CREATE TABLE IF NOT EXISTS rate_limits (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  rate_key VARCHAR(255) UNIQUE NOT NULL,
  requests JSON DEFAULT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_rate_key (rate_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table de configuration des pays (miroir de Firestore config/pays)
CREATE TABLE IF NOT EXISTS pays_config (
  id VARCHAR(8) PRIMARY KEY,
  nom VARCHAR(64) NOT NULL,
  actif TINYINT(1) DEFAULT 1,
  devise VARCHAR(8) NOT NULL DEFAULT 'XOF',
  symbole VARCHAR(16) DEFAULT 'F CFA',
  inscription_montant DECIMAL(18,2) DEFAULT 500,
  gain_parrainage DECIMAL(18,2) DEFAULT 100,
  commission_fixe_commande DECIMAL(18,2) DEFAULT 100,
  pub_standard_montant DECIMAL(18,2) DEFAULT 2000,
  pub_premium_montant DECIMAL(18,2) DEFAULT 5000,
  retrait_minimum DECIMAL(18,2) DEFAULT 500,
  moneroo_methods VARCHAR(512) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertion des pays par défaut
INSERT INTO pays_config (id, nom, actif, devise, symbole, inscription_montant, gain_parrainage, commission_fixe_commande, pub_standard_montant, pub_premium_montant, retrait_minimum, moneroo_methods) VALUES
('TG', 'Togo', 1, 'XOF', 'F CFA', 500, 100, 100, 2000, 5000, 500, 'moov_tg,togocel'),
('CI', 'Côte d''Ivoire', 1, 'XOF', 'F CFA', 500, 100, 100, 2000, 5000, 500, 'orange_ci,mtn_ci,moov_ci,wave_ci'),
('SN', 'Sénégal', 1, 'XOF', 'F CFA', 500, 100, 100, 2000, 5000, 500, 'orange_sn,wave_sn,freemoney_sn'),
('BJ', 'Bénin', 1, 'XOF', 'F CFA', 500, 100, 100, 2000, 5000, 500, 'mtn_bj,moov_bj'),
('GH', 'Ghana', 1, 'GHS', 'GH₵', 10, 5, 2, 30, 80, 10, 'mtn_gh,tigo_gh,vodafone_gh'),
('NG', 'Nigeria', 1, 'NGN', '₦', 500, 200, 100, 3000, 8000, 1000, 'airtel_ng'),
('ML', 'Mali', 1, 'XOF', 'F CFA', 500, 100, 100, 2000, 5000, 500, 'orange_ml'),
('BF', 'Burkina Faso', 1, 'XOF', 'F CFA', 500, 100, 100, 2000, 5000, 500, 'orange_bf,moov_bf'),
('NE', 'Niger', 1, 'XOF', 'F CFA', 500, 100, 100, 2000, 5000, 500, 'airtel_ne'),
('GN', 'Guinée', 1, 'GNF', 'GNF', 5000, 1000, 500, 20000, 50000, 5000, 'mtn_gn'),
('CM', 'Cameroun', 1, 'XAF', 'F CFA', 500, 100, 100, 2000, 5000, 500, ''),
('GA', 'Gabon', 1, 'XAF', 'F CFA', 1000, 200, 200, 4000, 10000, 1000, ''),
('CD', 'RD Congo', 1, 'CDF', 'FC', 500, 100, 100, 2000, 5000, 500, ''),
('KE', 'Kenya', 1, 'KES', 'KSh', 100, 50, 20, 500, 1500, 100, ''),
('UG', 'Ouganda', 1, 'UGX', 'USh', 500, 100, 100, 2000, 5000, 500, ''),
('TZ', 'Tanzanie', 1, 'TZS', 'TSh', 500, 100, 100, 2000, 5000, 500, ''),
('FR', 'France', 1, 'EUR', '€', 1, 0.15, 0, 3, 8, 5, 'card_eur,crypto_eur'),
('BE', 'Belgique', 1, 'EUR', '€', 1, 0.15, 0, 3, 8, 5, 'card_eur,crypto_eur'),
('CA', 'Canada', 1, 'CAD', 'CA$', 2, 0.3, 0, 5, 12, 10, 'card_cad'),
('US', 'États-Unis', 1, 'USD', '$', 2, 0.3, 0, 5, 12, 10, 'card_usd,crypto_usd')
ON DUPLICATE KEY UPDATE
  nom=VALUES(nom), actif=VALUES(actif), devise=VALUES(devise), symbole=VALUES(symbole),
  inscription_montant=VALUES(inscription_montant), gain_parrainage=VALUES(gain_parrainage),
  commission_fixe_commande=VALUES(commission_fixe_commande), pub_standard_montant=VALUES(pub_standard_montant),
  pub_premium_montant=VALUES(pub_premium_montant), retrait_minimum=VALUES(retrait_minimum),
  moneroo_methods=VALUES(moneroo_methods);
