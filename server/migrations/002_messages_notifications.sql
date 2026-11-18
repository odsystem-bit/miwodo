-- ═══════════════════════════════════════════════════════════════════════════
-- MIWODO — Schéma MySQL pour les messages et notifications
-- À exécuter dans phpMyAdmin ou en ligne de commande MySQL
-- ═══════════════════════════════════════════════════════════════════════════

-- Table des conversations
CREATE TABLE IF NOT EXISTS conversations (
  id VARCHAR(255) PRIMARY KEY,
  participants JSON NOT NULL,
  guest_id VARCHAR(128) NULL,
  guest_name VARCHAR(128) NULL,
  guest_phone VARCHAR(64) NULL,
  prestataire_id VARCHAR(128) NULL,
  is_guest_conversation TINYINT(1) DEFAULT 0,
  dernier_message TEXT NULL,
  dernier_expediteur_id VARCHAR(128) NULL,
  dernier_message_date TIMESTAMP NULL,
  last_message_lu TINYINT(1) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_prestataire_id (prestataire_id),
  INDEX idx_guest_id (guest_id),
  INDEX idx_updated_at (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des messages
CREATE TABLE IF NOT EXISTS messages (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  conversation_id VARCHAR(255) NOT NULL,
  expediteur_id VARCHAR(128) NOT NULL,
  destinataire_id VARCHAR(128) NOT NULL,
  contenu TEXT NOT NULL,
  type VARCHAR(32) NOT NULL DEFAULT 'text',
  media_url TEXT NULL,
  media_size_bytes INT NULL,
  media_duration_seconds INT NULL,
  est_lu TINYINT(1) DEFAULT 0,
  is_guest TINYINT(1) DEFAULT 0,
  guest_name VARCHAR(128) NULL,
  guest_phone VARCHAR(64) NULL,
  cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  INDEX idx_conversation_id (conversation_id),
  INDEX idx_expediteur_id (expediteur_id),
  INDEX idx_destinataire_id (destinataire_id),
  INDEX idx_cree_le (cree_le)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des notifications
CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  type VARCHAR(32) NOT NULL DEFAULT 'general',
  target_id VARCHAR(255) NULL,
  data JSON NULL,
  est_lu TINYINT(1) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_est_lu (est_lu),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
