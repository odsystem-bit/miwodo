<?php
// ═══════════════════════════════════════════════════════════════════════════
// MIWODO — Endpoint /upload
// Upload une photo via multipart/form-data et retourne l'URL publique
// POST /upload
// Form-data: file (binary), path (string), content_type (optional)
// ═══════════════════════════════════════════════════════════════════════════

require_once __DIR__ . '/config.php';

setCorsHeaders();
handlePreflight();
authenticate();

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    errorResponse('Méthode non autorisée', 405);
}

// ─── Validation ────────────────────────────────────────────────────────────
if (empty($_FILES['file'])) {
    errorResponse('Aucun fichier reçu', 400);
}

$file = $_FILES['file'];
$path = $_POST['path'] ?? '';

if (empty($path)) {
    errorResponse('Chemin de destination requis', 400);
}

// Sécuriser le path — empêcher les traverses de répertoire
$path = str_replace('..', '', $path);
$path = ltrim($path, '/');

// Vérifier le type de fichier
$allowedMimes = [
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'video/mp4', 'video/quicktime', 'video/x-msvideo',
    'audio/mpeg', 'audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac'
];
$mimeType = mime_content_type($file['tmp_name']);
if (!in_array($mimeType, $allowedMimes)) {
    errorResponse("Type de fichier non autorisé: $mimeType", 400);
}

// Vérifier la taille (max 50 MB pour vidéos, 10 MB pour images/audio)
$isVideo = str_starts_with($mimeType, 'video/');
$maxSize = $isVideo ? 50 * 1024 * 1024 : 10 * 1024 * 1024;
if ($file['size'] > $maxSize) {
    $maxMB = $maxSize / (1024 * 1024);
    errorResponse("Fichier trop volumineux (max {$maxMB} MB)", 400);
}

// Vérifier les erreurs d'upload
if ($file['error'] !== UPLOAD_ERR_OK) {
    $errors = [
        UPLOAD_ERR_INI_SIZE => 'Fichier trop volumineux (php.ini)',
        UPLOAD_ERR_FORM_SIZE => 'Fichier trop volumineux (form)',
        UPLOAD_ERR_PARTIAL => 'Upload partiel',
        UPLOAD_ERR_NO_FILE => 'Aucun fichier',
        UPLOAD_ERR_NO_TMP_DIR => 'Dossier temporaire manquant',
        UPLOAD_ERR_CANT_WRITE => 'Impossible d\'écrire le fichier',
        UPLOAD_ERR_EXTENSION => 'Extension bloquée par PHP',
    ];
    $msg = $errors[$file['error']] ?? 'Erreur inconnue';
    errorResponse("Erreur upload: $msg", 400);
}

// ─── Sauvegarder le fichier ────────────────────────────────────────────────
$uploadDir = __DIR__ . '/../uploads/';
$fullPath = $uploadDir . $path;

// Créer les dossiers nécessaires
$dir = dirname($fullPath);
if (!is_dir($dir)) {
    if (!mkdir($dir, 0755, true)) {
        error_log('[MIWODO] Cannot create dir: ' . $dir);
        errorResponse('Erreur lors de la création du dossier', 500);
    }
}

if (!move_uploaded_file($file['tmp_name'], $fullPath)) {
    error_log('[MIWODO] move_uploaded_file failed for: ' . $fullPath);
    errorResponse('Erreur lors de la sauvegarde du fichier', 500);
}

// ─── Construire l'URL publique ─────────────────────────────────────────────
$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'] ?? 'bot.odsysteme.tech';
$baseUrl = "$protocol://$host/uploads/";

$publicUrl = $baseUrl . $path;

// ─── Réponse ───────────────────────────────────────────────────────────────
jsonResponse([
    'url' => $publicUrl,
    'path' => $path,
    'size' => $file['size'],
    'mime' => $mimeType,
]);
