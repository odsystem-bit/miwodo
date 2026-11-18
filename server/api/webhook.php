<?php
// ═══════════════════════════════════════════════════════════════════════════
// MIWODO — Endpoint /webhook
// Reçoit les webhooks de Moneroo et met à jour le statut des paiements
// POST /webhook
// Pas d'authentification par clé API — vérification par signature Moneroo
// ═══════════════════════════════════════════════════════════════════════════

require_once __DIR__ . '/config.php';

setCorsHeaders();

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    errorResponse('Méthode non autorisée', 405);
}

$rawBody = file_get_contents('php://input');
$payload = json_decode($rawBody, true);

if (!$payload) {
    errorResponse('Payload JSON invalide', 400);
}

// ─── Vérification de la signature Moneroo ──────────────────────────────────
// Moneroo envoie un header X-Moneroo-Signature contenant un hash HMAC
$signature = $_SERVER['HTTP_X_MONEROO_SIGNATURE']
    ?? $_SERVER['HTTP_MONEROO_SIGNATURE']
    ?? '';

if (empty(MONEROO_SECRET_KEY)) {
    error_log('[MIWODO] Webhook received but MONEROO_SECRET_KEY not configured');
    errorResponse('Configuration serveur incomplète', 500);
}

// Calculer la signature attendue (HMAC SHA256 du body raw)
$expectedSignature = hash_hmac('sha256', $rawBody, MONEROO_SECRET_KEY);

if (!empty($signature) && !hash_equals($expectedSignature, $signature)) {
    error_log('[MIWODO] Webhook signature mismatch');
    errorResponse('Signature invalide', 401);
}

// Si pas de signature, on accepte quand même mais on log (pour le debug initial)
if (empty($signature)) {
    error_log('[MIWODO] Webhook received without signature — accepting for debug');
}

// ─── Extraction des données ────────────────────────────────────────────────
$event = $payload['event'] ?? '';
$data = $payload['data'] ?? $payload;

$monerooId = $data['id'] ?? '';
$status = $data['status'] ?? '';
$amount = $data['amount'] ?? null;

if (empty($monerooId)) {
    errorResponse('ID de paiement manquant dans le webhook', 400);
}

// ─── Mise à jour en base ───────────────────────────────────────────────────
try {
    // Trouver la demande de paiement
    $stmt = db()->prepare('SELECT * FROM payment_requests WHERE moneroo_id = ? LIMIT 1');
    $stmt->execute([$monerooId]);
    $paymentRequest = $stmt->fetch();

    if (!$paymentRequest) {
        error_log("[MIWODO] Webhook: payment request not found for moneroo_id=$monerooId");
        // Répondre 200 pour que Moneroo ne retry pas
        jsonResponse(['received' => true, 'message' => 'Payment not found but acknowledged']);
    }

    // Insérer la transaction
    $stmt = db()->prepare('
        INSERT INTO transactions (payment_request_id, moneroo_id, status, amount, provider_response, verified_at)
        VALUES (?, ?, ?, ?, ?, NOW())
    ');
    $stmt->execute([
        $paymentRequest['id'],
        $monerooId,
        $status,
        $amount,
        json_encode($data, JSON_UNESCAPED_UNICODE),
    ]);

    // Mettre à jour le statut
    $stmt = db()->prepare('UPDATE payment_requests SET status = ? WHERE id = ?');
    $stmt->execute([$status, $paymentRequest['id']]);

    // ─── Notification push via Firebase (optionnel) ─────────────────────────
    // Si le paiement est réussi, on peut envoyer une notification
    if (in_array($status, ['success', 'successful'])) {
        // TODO: Envoyer une notification push via Firebase Cloud Messaging
        // Pour l'instant, le client Flutter vérifie le statut via /verify
        error_log("[MIWODO] Webhook: payment $monerooId succeeded — type={$paymentRequest['type']}");
    }

} catch (Exception $e) {
    error_log('[MIWODO] Webhook DB error: ' . $e->getMessage());
    errorResponse('Erreur lors du traitement du webhook', 500);
}

jsonResponse(['received' => true, 'status' => $status]);
