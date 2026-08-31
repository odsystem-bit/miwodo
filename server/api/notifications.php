<?php
// ═══════════════════════════════════════════════════════════════════════════
// MIWODO — Endpoint /notifications
// POST /notifications          — Créer une notification
// GET  /notifications?user=    — Récupérer les notifications d'un utilisateur
// PUT  /notifications/read     — Marquer une notification comme lue
// DELETE /notifications/:id    — Supprimer une notification
// ═══════════════════════════════════════════════════════════════════════════

require_once __DIR__ . '/config.php';

setCorsHeaders();
handlePreflight();
authenticate();

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// ─── POST: Créer une notification ──────────────────────────────────────────
if ($method === 'POST') {
    $body = getJsonBody();

    $userId = $body['userId'] ?? '';
    $title = $body['title'] ?? 'Miwodo';
    $bodyText = $body['body'] ?? '';
    $type = $body['type'] ?? 'general';
    $targetId = $body['targetId'] ?? null;
    $data = $body['data'] ?? null;

    if (empty($userId) || empty($bodyText)) {
        errorResponse('Paramètres manquants', 400);
    }

    try {
        $stmt = db()->prepare(
            'INSERT INTO notifications (user_id, title, body, type, target_id, data, est_lu, created_at)
             VALUES (?, ?, ?, ?, ?, ?, 0, NOW())'
        );
        $stmt->execute([
            $userId,
            $title,
            $bodyText,
            $type,
            $targetId,
            $data ? json_encode($data) : null,
        ]);

        $notifId = db()->lastInsertId();

        // Récupérer la notification créée
        $stmt = db()->prepare('SELECT * FROM notifications WHERE id = ?');
        $stmt->execute([$notifId]);
        $notif = $stmt->fetch();

        jsonResponse([
            'success' => true,
            'notification' => $notif,
        ]);
    } catch (Exception $e) {
        error_log('[MIWODO] notifications POST error: ' . $e->getMessage());
        errorResponse('Erreur lors de la création', 500);
    }
}

// ─── GET: Récupérer les notifications ──────────────────────────────────────
if ($method === 'GET') {
    $userId = $_GET['user'] ?? '';
    $unreadOnly = isset($_GET['unread']) && $_GET['unread'] === '1';
    $limit = min((int)($_GET['limit'] ?? 50), 200);
    $offset = (int)($_GET['offset'] ?? 0);

    if (empty($userId)) {
        errorResponse('Paramètre user requis', 400);
    }

    try {
        $sql = 'SELECT * FROM notifications WHERE user_id = ?';
        if ($unreadOnly) {
            $sql .= ' AND est_lu = 0';
        }
        $sql .= ' ORDER BY created_at DESC LIMIT ? OFFSET ?';

        $stmt = db()->prepare($sql);
        $stmt->execute([$userId, $limit, $offset]);
        $notifications = $stmt->fetchAll();

        // Compter les non lues
        $stmt = db()->prepare('SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND est_lu = 0');
        $stmt->execute([$userId]);
        $unreadCount = (int)$stmt->fetch()['count'];

        jsonResponse([
            'success' => true,
            'notifications' => $notifications,
            'unreadCount' => $unreadCount,
        ]);
    } catch (Exception $e) {
        error_log('[MIWODO] notifications GET error: ' . $e->getMessage());
        errorResponse('Erreur lors de la récupération', 500);
    }
}

// ─── PUT: Marquer comme lu ──────────────────────────────────────────────────
if ($method === 'PUT') {
    $body = getJsonBody();
    $notificationId = $body['id'] ?? null;
    $userId = $body['userId'] ?? '';

    try {
        if ($notificationId) {
            $stmt = db()->prepare(
                'UPDATE notifications SET est_lu = 1 WHERE id = ? AND user_id = ?'
            );
            $stmt->execute([$notificationId, $userId]);
        } else {
            // Marquer toutes les notifications comme lues
            $stmt = db()->prepare(
                'UPDATE notifications SET est_lu = 1 WHERE user_id = ?'
            );
            $stmt->execute([$userId]);
        }

        jsonResponse(['success' => true]);
    } catch (Exception $e) {
        error_log('[MIWODO] notifications PUT error: ' . $e->getMessage());
        errorResponse('Erreur', 500);
    }
}

// ─── DELETE: Supprimer une notification ────────────────────────────────────
if ($method === 'DELETE') {
    $body = getJsonBody();
    $notificationId = $body['id'] ?? null;
    $userId = $body['userId'] ?? '';

    if (empty($notificationId)) {
        errorResponse('ID requis', 400);
    }

    try {
        $stmt = db()->prepare(
            'DELETE FROM notifications WHERE id = ? AND user_id = ?'
        );
        $stmt->execute([$notificationId, $userId]);

        jsonResponse(['success' => true]);
    } catch (Exception $e) {
        error_log('[MIWODO] notifications DELETE error: ' . $e->getMessage());
        errorResponse('Erreur', 500);
    }
}

errorResponse('Méthode non autorisée', 405);
