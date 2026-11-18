<?php
// ═══════════════════════════════════════════════════════════════════════════
// MIWODO — Endpoint /delete
// Supprime un fichier du storage
// POST /delete
// Body: { path: string }
// ═══════════════════════════════════════════════════════════════════════════

require_once __DIR__ . '/config.php';

setCorsHeaders();
handlePreflight();
authenticate();

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    errorResponse('Méthode non autorisée', 405);
}

$body = getJsonBody();
$path = $body['path'] ?? '';

if (empty($path)) {
    errorResponse('Chemin requis', 400);
}

// Sécuriser le path
$path = str_replace('..', '', $path);
$path = ltrim($path, '/');

// Si c'est une URL complète, extraire le path
if (str_starts_with($path, 'http')) {
    $uri = parse_url($path, PHP_URL_PATH);
    if ($uri) {
        $path = str_replace('/uploads/', '', $uri);
    }
}

$fullPath = __DIR__ . '/../uploads/' . $path;

if (!file_exists($fullPath)) {
    // Pas une erreur — le fichier n'existe déjà plus
    jsonResponse(['deleted' => true, 'message' => 'Fichier introuvable (déjà supprimé)']);
}

if (unlink($fullPath)) {
    jsonResponse(['deleted' => true, 'path' => $path]);
} else {
    error_log('[MIWODO] unlink failed for: ' . $fullPath);
    errorResponse('Impossible de supprimer le fichier', 500);
}
