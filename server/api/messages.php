<?php
// ═══════════════════════════════════════════════════════════════════════════
// MIWODO — Endpoint /messages
// POST /messages        — Envoyer un message (invité ou connecté)
// GET  /messages?conv=  — Récupérer les messages d'une conversation
// GET  /messages?user=  — Récupérer les conversations d'un utilisateur
// PUT  /messages/read   — Marquer les messages comme lus
// ═══════════════════════════════════════════════════════════════════════════

require_once __DIR__ . '/config.php';

setCorsHeaders();
handlePreflight();
authenticate();

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// ─── POST: Envoyer un message ──────────────────────────────────────────────
if ($method === 'POST') {
    $body = getJsonBody();

    $conversationId = $body['conversationId'] ?? '';
    $expediteurId = $body['expediteurId'] ?? '';
    $destinataireId = $body['destinataireId'] ?? '';
    $contenu = trim($body['contenu'] ?? '');
    $type = $body['type'] ?? 'text';
    $mediaUrl = $body['mediaUrl'] ?? null;
    $mediaSizeBytes = $body['mediaSizeBytes'] ?? null;
    $mediaDurationSeconds = $body['mediaDurationSeconds'] ?? null;
    $isGuest = $body['isGuest'] ?? false;
    $guestName = $body['guestName'] ?? null;
    $guestPhone = $body['guestPhone'] ?? null;

    if (empty($conversationId) || empty($expediteurId) || empty($destinataireId) || empty($contenu)) {
        errorResponse('Paramètres manquants', 400);
    }

    $pdo = db();

    try {
        $pdo->beginTransaction();

        // Créer ou mettre à jour la conversation
        $stmt = $pdo->prepare(
            'INSERT INTO conversations (id, participants, guest_id, guest_name, guest_phone, prestataire_id, is_guest_conversation, dernier_message, dernier_expediteur_id, dernier_message_date, last_message_lu)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 0)
             ON DUPLICATE KEY UPDATE
               dernier_message = VALUES(dernier_message),
               dernier_expediteur_id = VALUES(dernier_expediteur_id),
               dernier_message_date = NOW(),
               last_message_lu = 0,
               updated_at = NOW()'
        );

        $participants = json_encode([$expediteurId, $destinataireId]);
        $stmt->execute([
            $conversationId,
            $participants,
            $isGuest ? $expediteurId : null,
            $guestName,
            $guestPhone,
            $isGuest ? $destinataireId : null,
            $isGuest ? 1 : 0,
            $contenu,
            $expediteurId,
        ]);

        // Insérer le message
        $stmt = $pdo->prepare(
            'INSERT INTO messages (conversation_id, expediteur_id, destinataire_id, contenu, type, media_url, media_size_bytes, media_duration_seconds, is_guest, guest_name, guest_phone, cree_le)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())'
        );
        $stmt->execute([
            $conversationId,
            $expediteurId,
            $destinataireId,
            $contenu,
            $type,
            $mediaUrl,
            $mediaSizeBytes,
            $mediaDurationSeconds,
            $isGuest ? 1 : 0,
            $guestName,
            $guestPhone,
        ]);

        $messageId = $pdo->lastInsertId();
        $pdo->commit();

        // Récupérer le message créé
        $stmt = $pdo->prepare('SELECT * FROM messages WHERE id = ?');
        $stmt->execute([$messageId]);
        $message = $stmt->fetch();

        jsonResponse([
            'success' => true,
            'message' => $message,
        ]);
    } catch (Exception $e) {
        $pdo->rollBack();
        error_log('[MIWODO] messages POST error: ' . $e->getMessage());
        errorResponse('Erreur lors de l\'envoi du message', 500);
    }
}

// ─── GET: Récupérer messages ou conversations ──────────────────────────────
if ($method === 'GET') {
    $conversationId = $_GET['conv'] ?? '';
    $userId = $_GET['user'] ?? '';
    $guestId = $_GET['guest'] ?? '';
    $lastId = $_GET['lastId'] ?? '0';

    $pdo = db();

    try {
        // Récupérer les messages d'une conversation + infos de la conversation
        if (!empty($conversationId)) {
            $stmt = $pdo->prepare(
                'SELECT * FROM messages WHERE conversation_id = ? AND id > ? ORDER BY cree_le ASC LIMIT 200'
            );
            $stmt->execute([$conversationId, (int)$lastId]);
            $messages = $stmt->fetchAll();

            // Récupérer aussi les infos de la conversation
            $stmt = $pdo->prepare('SELECT * FROM conversations WHERE id = ?');
            $stmt->execute([$conversationId]);
            $conversation = $stmt->fetch();

            if ($conversation) {
                $conversation['participants'] = json_decode($conversation['participants'], true);
                $conversation['is_guest_conversation'] = (bool)$conversation['is_guest_conversation'];
                $conversation['last_message_lu'] = (bool)$conversation['last_message_lu'];
            }

            jsonResponse([
                'success' => true,
                'messages' => $messages,
                'conversation' => $conversation,
            ]);
        }

        // Récupérer les conversations d'un utilisateur (prestataire ou invité)
        if (!empty($userId) || !empty($guestId)) {
            $searchId = !empty($userId) ? $userId : $guestId;

            $stmt = $pdo->prepare(
                'SELECT * FROM conversations
                 WHERE JSON_CONTAINS(participants, JSON_QUOTE(?))
                 ORDER BY dernier_message_date DESC
                 LIMIT 100'
            );
            $stmt->execute([$searchId]);
            $conversations = $stmt->fetchAll();

            // Décoder participants
            foreach ($conversations as &$conv) {
                $conv['participants'] = json_decode($conv['participants'], true);
                $conv['is_guest_conversation'] = (bool)$conv['is_guest_conversation'];
                $conv['last_message_lu'] = (bool)$conv['last_message_lu'];
            }

            jsonResponse([
                'success' => true,
                'conversations' => $conversations,
            ]);
        }

        errorResponse('Paramètre conv ou user requis', 400);
    } catch (Exception $e) {
        error_log('[MIWODO] messages GET error: ' . $e->getMessage());
        errorResponse('Erreur lors de la récupération', 500);
    }
}

// ─── PUT: Marquer comme lu ──────────────────────────────────────────────────
if ($method === 'PUT') {
    $body = getJsonBody();
    $conversationId = $body['conversationId'] ?? '';
    $userId = $body['userId'] ?? '';

    if (empty($conversationId) || empty($userId)) {
        errorResponse('Paramètres manquants', 400);
    }

    $pdo = db();

    try {
        // Marquer les messages comme lus
        $stmt = $pdo->prepare(
            'UPDATE messages SET est_lu = 1 WHERE conversation_id = ? AND destinataire_id = ? AND est_lu = 0'
        );
        $stmt->execute([$conversationId, $userId]);

        // Marquer la conversation comme lue
        $stmt = $pdo->prepare(
            'UPDATE conversations SET last_message_lu = 1 WHERE id = ?'
        );
        $stmt->execute([$conversationId]);

        jsonResponse(['success' => true]);
    } catch (Exception $e) {
        error_log('[MIWODO] messages PUT error: ' . $e->getMessage());
        errorResponse('Erreur', 500);
    }
}

errorResponse('Méthode non autorisée', 405);
