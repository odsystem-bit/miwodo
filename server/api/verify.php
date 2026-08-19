<?php
// ═══════════════════════════════════════════════════════════════════════════
// MIWODO — Endpoint /verify
// Vérifie le statut d'un paiement auprès de Moneroo
// POST /verify
// Body: { payment_id: string }
// ═══════════════════════════════════════════════════════════════════════════

require_once __DIR__ . '/config.php';

setCorsHeaders();
handlePreflight();
authenticate();

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    errorResponse('Méthode non autorisée', 405);
}

$body = getJsonBody();
$paymentId = $body['payment_id'] ?? $body['paymentId'] ?? '';

if (empty($paymentId) || strlen($paymentId) > 128) {
    errorResponse('payment_id invalide', 400);
}

// ─── Rate limiting ─────────────────────────────────────────────────────────
if (!checkRateLimit('verification', getClientIp())) {
    errorResponse('Trop de vérifications. Réessayez dans 1 minute.', 429);
}

// ─── Récupérer la demande de paiement en DB ────────────────────────────────
$paymentRequest = null;
try {
    $stmt = db()->prepare('SELECT * FROM payment_requests WHERE payment_id = ? OR moneroo_id = ? LIMIT 1');
    $stmt->execute([$paymentId, $paymentId]);
    $paymentRequest = $stmt->fetch();
} catch (Exception $e) {
    error_log('[MIWODO] DB query error: ' . $e->getMessage());
}

// ─── Appel Moneroo pour vérifier ───────────────────────────────────────────
$result = callMoneroo("/payments/" . urlencode($paymentId), [], 'GET');

$status = $result['status'] ?? 'unknown';
$amount = $result['amount'] ?? null;
$monerooId = $result['id'] ?? $paymentId;

// ─── Enregistrer la transaction ────────────────────────────────────────────
if ($paymentRequest) {
    try {
        // Insérer dans transactions
        $stmt = db()->prepare('
            INSERT INTO transactions (payment_request_id, moneroo_id, status, amount, provider_response, verified_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ');
        $stmt->execute([
            $paymentRequest['id'],
            $monerooId,
            $status,
            $amount,
            json_encode($result, JSON_UNESCAPED_UNICODE),
        ]);

        // Mettre à jour le statut de la demande
        if (in_array($status, ['success', 'successful', 'failed', 'cancelled'])) {
            $stmt = db()->prepare('UPDATE payment_requests SET status = ? WHERE id = ?');
            $stmt->execute([$status, $paymentRequest['id']]);
        }
    } catch (Exception $e) {
        error_log('[MIWODO] DB update error: ' . $e->getMessage());
    }
}

// ─── Réponse ───────────────────────────────────────────────────────────────
jsonResponse([
    'id' => $monerooId,
    'payment_id' => $paymentRequest['payment_id'] ?? $paymentId,
    'status' => $status,
    'amount' => $amount,
]);
