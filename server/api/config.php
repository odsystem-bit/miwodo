<?php
// ═══════════════════════════════════════════════════════════════════════════
// MIWODO — Configuration centrale de l'API de paiement
// ═══════════════════════════════════════════════════════════════════════════

// ─── Chargement des variables d'environnement (.env) ───────────────────────
function loadEnv($path) {
    if (!file_exists($path)) return;
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (str_starts_with(trim($line), '#')) continue;
        if (!str_contains($line, '=')) continue;
        [$key, $value] = explode('=', $line, 2);
        $key = trim($key);
        $value = trim($value, " \t\n\r\"'");
        if (!getenv($key)) {
            putenv("$key=$value");
        }
    }
}

loadEnv(__DIR__ . '/.env');

// ─── Constantes ────────────────────────────────────────────────────────────
define('MONEROO_API_BASE', 'https://api.moneroo.io/v1');
define('MONEROO_SECRET_KEY', getenv('MONEROO_SECRET_KEY') ?: '');
define('PAYMENT_API_KEY', getenv('PAYMENT_API_KEY') ?: '');

// DB
define('DB_HOST', getenv('DB_HOST') ?: 'localhost');
define('DB_NAME', getenv('DB_NAME') ?: '');
define('DB_USER', getenv('DB_USER') ?: '');
define('DB_PASS', getenv('DB_PASS') ?: '');
define('DB_CHARSET', 'utf8mb4');

// ─── Connexion MySQL (PDO) ─────────────────────────────────────────────────
function db(): PDO {
    static $pdo = null;
    if ($pdo !== null) return $pdo;

    $dsn = 'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=' . DB_CHARSET;
    $options = [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ];

    try {
        $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
    } catch (PDOException $e) {
        error_log('[MIWODO] DB connection failed: ' . $e->getMessage());
        http_response_code(500);
        echo json_encode(['error' => 'Erreur de connexion à la base de données']);
        exit;
    }

    return $pdo;
}

// ─── Helpers HTTP ──────────────────────────────────────────────────────────
function jsonResponse($data, int $status = 200): void {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function errorResponse(string $message, int $status = 400, $extra = []): void {
    jsonResponse(array_merge(['error' => $message], $extra), $status);
}

// ─── CORS ──────────────────────────────────────────────────────────────────
function setCorsHeaders(): void {
    $allowedOrigins = [
        'https://miwodo.app',
        'https://miwodo.tg',
        'http://localhost:8080',
        'http://localhost:3000',
        'capacitor://localhost',
        'http://localhost',
    ];

    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    if (in_array($origin, $allowedOrigins)) {
        header("Access-Control-Allow-Origin: $origin");
    } else {
        header('Access-Control-Allow-Origin: https://miwodo.app');
    }
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Api-Key');
    header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
    header('Vary: Origin');
}

function handlePreflight(): void {
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        setCorsHeaders();
        http_response_code(204);
        exit;
    }
}

// ─── Authentification API ──────────────────────────────────────────────────
function authenticate(): void {
    // Le webhook Moneroo utilise sa propre signature, pas la clé API
    $script = basename($_SERVER['SCRIPT_NAME'] ?? '');
    if ($script === 'webhook.php') return;

    $apiKey = $_SERVER['HTTP_X_API_KEY'] ?? '';
    if (empty(PAYMENT_API_KEY) || !hash_equals(PAYMENT_API_KEY, $apiKey)) {
        errorResponse('Non autorisé — clé API invalide', 401);
    }
}

// ─── Lecture du body JSON ──────────────────────────────────────────────────
function getJsonBody(): array {
    $raw = file_get_contents('php://input');
    if (empty($raw)) return [];
    $data = json_decode($raw, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        errorResponse('JSON invalide dans le corps de la requête', 400);
    }
    return $data ?: [];
}

// ─── Rate limiting ─────────────────────────────────────────────────────────
function checkRateLimit(string $type, string $identifier): bool {
    $limits = [
        'inscription'  => ['max' => 20, 'window' => 3600],
        'commande'     => ['max' => 30, 'window' => 3600],
        'publicite'    => ['max' => 15, 'window' => 3600],
        'verification' => ['max' => 60, 'window' => 60],
    ];

    if (!isset($limits[$type])) return true;
    $config = $limits[$type];
    $key = "{$type}_{$identifier}";
    $now = time();
    $windowStart = $now - $config['window'];

    try {
        $pdo = db();
        $stmt = $pdo->prepare('SELECT requests FROM rate_limits WHERE rate_key = ?');
        $stmt->execute([$key]);
        $row = $stmt->fetch();

        $requests = $row ? json_decode($row['requests'], true) : [];
        if (!is_array($requests)) $requests = [];

        $validRequests = array_values(array_filter($requests, fn($ts) => $ts > $windowStart));

        if (count($validRequests) >= $config['max']) {
            return false;
        }

        $validRequests[] = $now;
        $stmt = $pdo->prepare(
            'INSERT INTO rate_limits (rate_key, requests, updated_at) VALUES (?, ?, NOW())
             ON DUPLICATE KEY UPDATE requests = VALUES(requests), updated_at = NOW()'
        );
        $stmt->execute([$key, json_encode($validRequests)]);

        return true;
    } catch (Exception $e) {
        error_log('[MIWODO] Rate limit error: ' . $e->getMessage());
        return true; // fail-open
    }
}

// ─── Configuration des pays ────────────────────────────────────────────────
function getPaysConfig(string $paysId): ?array {
    try {
        $stmt = db()->prepare('SELECT * FROM pays_config WHERE id = ? AND actif = 1');
        $stmt->execute([$paysId]);
        $row = $stmt->fetch();
        if (!$row) return null;

        $row['moneroo_methods'] = $row['moneroo_methods']
            ? array_filter(array_map('trim', explode(',', $row['moneroo_methods'])))
            : [];
        return $row;
    } catch (Exception $e) {
        error_log('[MIWODO] getPaysConfig error: ' . $e->getMessage());
        return null;
    }
}

// ─── Appel à l'API Moneroo ─────────────────────────────────────────────────
function callMoneroo(string $endpoint, array $body = [], string $method = 'POST'): array {
    if (empty(MONEROO_SECRET_KEY)) {
        errorResponse('MONEROO_SECRET_KEY non configuré', 500);
    }

    $url = MONEROO_API_BASE . $endpoint;
    $ch = curl_init($url);

    $headers = [
        'Content-Type: application/json',
        'Authorization: Bearer ' . MONEROO_SECRET_KEY,
        'Accept: application/json',
    ];

    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => true,
    ]);

    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
    } elseif ($method === 'GET') {
        curl_setopt($ch, CURLOPT_HTTPGET, true);
    }

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);

    if ($error) {
        error_log('[MIWODO] Moneroo cURL error: ' . $error);
        errorResponse('Erreur de connexion à Moneroo', 503);
    }

    $data = json_decode($response, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        error_log('[MIWODO] Moneroo non-JSON response: ' . substr($response, 0, 500));
        errorResponse('Réponse invalide de Moneroo', 502);
    }

    if ($httpCode < 200 || $httpCode >= 300) {
        $msg = $data['message'] ?? $data['error'] ?? 'Erreur Moneroo';
        errorResponse($msg, $httpCode, ['moneroo_status' => $httpCode]);
    }

    // Moneroo retourne { message, data: { id, checkout_url, ... } }
    return $data['data'] ?? $data;
}

// ─── Génération d'un ID de paiement unique ─────────────────────────────────
function generatePaymentId(string $type): string {
    $prefix = strtoupper(substr($type, 0, 3));
    return $prefix . '_' . date('YmdHis') . '_' . bin2hex(random_bytes(4));
}

// ─── IP client ─────────────────────────────────────────────────────────────
function getClientIp(): string {
    $xff = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? '';
    if ($xff) return trim(explode(',', $xff)[0]);
    return $_SERVER['REMOTE_ADDR'] ?? 'unknown';
}
