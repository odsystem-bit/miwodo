<?php
// ═══════════════════════════════════════════════════════════════════════════
// MIWODO — Endpoint /initiate
// Initie un paiement Moneroo et l'enregistre en MySQL
// POST /initiate
// Body: { type, amount, currency, customer: {email, first_name, last_name, phone},
//         methods, pays_id, metadata, return_url }
// ═══════════════════════════════════════════════════════════════════════════

require_once __DIR__ . '/config.php';

setCorsHeaders();
handlePreflight();
authenticate();

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    errorResponse('Méthode non autorisée', 405);
}

$body = getJsonBody();

// ─── Validation ────────────────────────────────────────────────────────────
$type = $body['type'] ?? 'commande';
$amount = $body['amount'] ?? null;
$currency = $body['currency'] ?? 'XOF';
$customer = $body['customer'] ?? [];
$methods = $body['methods'] ?? [];
$paysId = $body['pays_id'] ?? $body['metadata']['pays_id'] ?? 'TG';
$metadata = $body['metadata'] ?? [];
$description = $body['description'] ?? '';
$returnUrl = $body['return_url'] ?? 'https://miwodo.app/payment/callback';

if (empty($amount) || !is_numeric($amount) || $amount <= 0 || $amount > 10000000) {
    errorResponse('Montant invalide', 400);
}

if (empty($customer['email']) || empty($customer['first_name']) || empty($customer['last_name'])) {
    errorResponse('Customer incomplet (email, first_name, last_name requis)', 400);
}

if (empty($description)) {
    errorResponse('Description requise', 400);
}

// ─── Rate limiting ─────────────────────────────────────────────────────────
$rateLimitType = in_array($type, ['inscription', 'publicite']) ? $type : 'commande';
if (!checkRateLimit($rateLimitType, getClientIp())) {
    errorResponse('Trop de requêtes. Réessayez plus tard.', 429);
}

// ─── Validation côté serveur selon le pays ─────────────────────────────────
$paysConfig = getPaysConfig($paysId);
if (!$paysConfig) {
    errorResponse("Pays non supporté ou inactif: $paysId", 400);
}

// Vérifier la devise
if ($currency !== $paysConfig['devise']) {
    errorResponse("Devise invalide. Attendu: {$paysConfig['devise']}", 400);
}

// Pour les inscriptions, vérifier le montant
if ($type === 'inscription') {
    $expected = (float)$paysConfig['inscription_montant'];
    $tolerance = $expected * 0.01;
    if (abs((float)$amount - $expected) > $tolerance) {
        errorResponse("Montant invalide pour {$paysConfig['id']}. Attendu: $expected {$paysConfig['devise']}", 400);
    }
}

// Pour les publicités, vérifier le montant
if ($type === 'publicite') {
    $plan = $metadata['plan'] ?? 'standard';
    $expected = $plan === 'premium'
        ? (float)$paysConfig['pub_premium_montant']
        : (float)$paysConfig['pub_standard_montant'];
    $tolerance = $expected * 0.01;
    if (abs((float)$amount - $expected) > $tolerance) {
        errorResponse("Montant invalide pour la publicité $plan. Attendu: $expected {$paysConfig['devise']}", 400);
    }
}

// Vérifier les méthodes de paiement
if (!empty($methods) && is_array($methods)) {
    $allowedMethods = $paysConfig['moneroo_methods'];
    if (!empty($allowedMethods)) {
        $invalid = array_diff($methods, $allowedMethods);
        if (!empty($invalid)) {
            errorResponse("Méthodes non autorisées pour {$paysConfig['id']}: " . implode(', ', $invalid), 400);
        }
    }
}

// ─── Appel Moneroo ─────────────────────────────────────────────────────────
$monerooBody = [
    'amount' => (int)floor((float)$amount),
    'currency' => $currency,
    'description' => $description,
    'customer' => [
        'email' => $customer['email'],
        'first_name' => $customer['first_name'],
        'last_name' => $customer['last_name'],
    ],
    'methods' => $methods,
    'return_url' => $returnUrl,
    'metadata' => $metadata,
];

if (!empty($customer['phone'])) {
    $monerooBody['customer']['phone'] = $customer['phone'];
}

$result = callMoneroo('/payments/initialize', $monerooBody, 'POST');

$monerooId = $result['id'] ?? '';
$checkoutUrl = $result['checkout_url'] ?? '';

if (empty($monerooId) || empty($checkoutUrl)) {
    errorResponse('Réponse Moneroo incomplète', 502, ['moneroo_response' => $result]);
}

// ─── Enregistrement en MySQL ───────────────────────────────────────────────
$paymentId = generatePaymentId($type);
$userId = $metadata['user_id'] ?? $metadata['telephone'] ?? null;

try {
    $stmt = db()->prepare('
        INSERT INTO payment_requests
            (payment_id, user_id, type, amount, currency, status, moneroo_id,
             checkout_url, customer_email, customer_first_name, customer_last_name,
             customer_phone, methods, pays_id, metadata)
        VALUES
            (?, ?, ?, ?, ?, "pending", ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ');

    $stmt->execute([
        $paymentId,
        $userId,
        $type,
        $amount,
        $currency,
        $monerooId,
        $checkoutUrl,
        $customer['email'] ?? null,
        $customer['first_name'] ?? null,
        $customer['last_name'] ?? null,
        $customer['phone'] ?? null,
        implode(',', $methods),
        $paysId,
        json_encode($metadata, JSON_UNESCAPED_UNICODE),
    ]);

    $requestId = (int)db()->lastInsertId();
} catch (Exception $e) {
    error_log('[MIWODO] DB insert error: ' . $e->getMessage());
    // On continue quand même — le paiement est initié côté Moneroo
    $requestId = 0;
}

// ─── Réponse ───────────────────────────────────────────────────────────────
jsonResponse([
    'id' => $monerooId,
    'payment_id' => $paymentId,
    'checkout_url' => $checkoutUrl,
    'status' => 'pending',
    'amount' => (int)$amount,
    'currency' => $currency,
]);
