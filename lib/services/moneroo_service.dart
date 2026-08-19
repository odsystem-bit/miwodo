// services/moneroo_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURATION PAIEMENT (via API PHP/MySQL sur hébergement mutualisé)
// ═══════════════════════════════════════════════════════════════════════════

const String _PAYMENT_API_URL =
    String.fromEnvironment('PAYMENT_API_URL',
        defaultValue: 'https://bot.odsysteme.tech/api');
const String _PAYMENT_API_KEY =
    String.fromEnvironment('PAYMENT_API_KEY',
        defaultValue: 'aadc42b40f152ad0133c93e5e154a843fc61952072b35e80');

// ═══════════════════════════════════════════════════════════════════════════
// TYPES D'ERREURS SPÉCIFIQUES
// ═══════════════════════════════════════════════════════════════════════════

/// Erreur de base pour les paiements Moneroo
sealed class MonerooException implements Exception {
  final String message;
  final String? code;
  const MonerooException(this.message, [this.code]);

  @override
  String toString() => message;

  /// Message utilisateur friendly
  String get userMessage;
}

/// Erreur réseau (pas de connexion, timeout, DNS)
class MonerooNetworkException extends MonerooException {
  const MonerooNetworkException(super.message, [super.code]);

  @override
  String get userMessage => 'Vérifiez votre connexion internet et réessayez.';
}

/// Erreur de validation (données invalides)
class MonerooValidationException extends MonerooException {
  const MonerooValidationException(super.message, [super.code]);

  @override
  String get userMessage => message;
}

/// Erreur de rate limiting (trop de requêtes)
class MonerooRateLimitException extends MonerooException {
  const MonerooRateLimitException(super.message, [super.code]);

  @override
  String get userMessage =>
      'Trop de tentatives. Veuillez patienter quelques minutes.';
}

/// Erreur serveur (Moneroo indisponible)
class MonerooServerException extends MonerooException {
  const MonerooServerException(super.message, [super.code]);

  @override
  String get userMessage =>
      'Service temporairement indisponible. Réessayez dans quelques instants.';
}

/// Erreur de paiement (refusé, annulé)
class MonerooPaymentException extends MonerooException {
  const MonerooPaymentException(super.message, [super.code]);

  @override
  String get userMessage => message;
}

// ═══════════════════════════════════════════════════════════════════════════
// RÉSULTATS
// ═══════════════════════════════════════════════════════════════════════════

class MonerooPaymentResult {
  final String id;
  final String checkoutUrl;
  MonerooPaymentResult({required this.id, required this.checkoutUrl});
}

class MonerooVerifyResult {
  final String id;
  final String status;
  final int? amount;
  MonerooVerifyResult({required this.id, required this.status, this.amount});
}

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE
// ═══════════════════════════════════════════════════════════════════════════

class MonerooService {
  static const _timeout = Duration(seconds: 30);

  MonerooService._();

  static final MonerooService instance = MonerooService._();

  /// When true, simulate payments locally without calling the proxy.
  /// Useful for local testing when network or secrets are not available.
  /// Set to `false` in production. Restored to use real Moneroo proxy.
  bool enableMock = false;

  Future<Map<String, dynamic>> _callPaymentApi(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_PAYMENT_API_URL/$endpoint');

    try {
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Api-Key': _PAYMENT_API_KEY,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      // Parser la réponse
      Map<String, dynamic>? responseBody;
      if (resp.body.isNotEmpty) {
        try {
          responseBody = jsonDecode(resp.body) as Map<String, dynamic>?;
        } catch (_) {
          // Corps non-JSON
        }
      }

      // Succès
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (responseBody != null) {
          return responseBody;
        }
        throw const MonerooServerException(
          'Réponse vide du serveur',
          'empty_response',
        );
      }

      // Extraire le message d'erreur
      final errorMsg = _extractErrorMessage(responseBody, resp.statusCode);

      // Mapper les codes HTTP aux exceptions appropriées
      switch (resp.statusCode) {
        case 400:
          throw MonerooValidationException(errorMsg, 'invalid_request');
        case 401:
        case 403:
          throw MonerooServerException(
            'Erreur d\'authentification',
            'auth_error',
          );
        case 404:
          throw MonerooServerException('Service introuvable', 'not_found');
        case 429:
          throw MonerooRateLimitException(errorMsg, 'rate_limited');
        case >= 500:
          throw MonerooServerException(errorMsg, 'server_error');
        default:
          throw MonerooServerException(errorMsg, 'http_$resp.statusCode');
      }
    } on TimeoutException {
      throw const MonerooNetworkException(
        'La requête a pris trop de temps',
        'timeout',
      );
    } on SocketException catch (e) {
      if (e.message.contains('Failed host lookup') ||
          e.message.contains('No address')) {
        throw const MonerooNetworkException(
          'Impossible de se connecter au serveur',
          'dns_error',
        );
      }
      throw MonerooNetworkException(
        'Erreur réseau: ${e.message}',
        'socket_error',
      );
    } on HttpException catch (e) {
      throw MonerooNetworkException('Erreur HTTP: ${e.message}', 'http_error');
    } on FormatException {
      throw const MonerooServerException(
        'Réponse invalide du serveur',
        'parse_error',
      );
    } on MonerooException {
      rethrow;
    } catch (e) {
      throw MonerooServerException('Erreur inattendue: $e', 'unknown');
    }
  }

  String _extractErrorMessage(Map<String, dynamic>? body, int statusCode) {
    if (body == null) return 'Erreur serveur ($statusCode)';

    return body['message'] as String? ??
        body['error'] as String? ??
        'Erreur serveur ($statusCode)';
  }

  /// Initier un paiement d'inscription prestataire
  Future<MonerooPaymentResult> initierInscription({
    required String prenom,
    required String nom,
    required String email,
    required String telephone,
    String paysId = 'TG',
    String devise = 'XOF',
    num montant = 500,
    List<String> methods = const ['moov_tg', 'togocel'],
  }) async {
    final body = {
      'amount': montant.toInt(),
      'currency': devise,
      'description': 'Inscription prestataire Miwodo',
      'customer': {
        'email': email,
        'first_name': prenom,
        'last_name': nom,
        'phone': telephone,
      },
      'methods': methods,
      'return_url': 'https://miwodo.app/payment/callback',
      'metadata': {
        'type': 'inscription',
        'telephone': telephone,
        'pays_id': paysId,
      },
    };

    if (enableMock) {
      // Return a mock checkout URL that the WebView will immediately detect
      // as successful (contains paymentstatus=success and payment_id).
      final mockId = 'MOCK_INS_${DateTime.now().millisecondsSinceEpoch}';
      return MonerooPaymentResult(
        id: mockId,
        checkoutUrl:
            'https://miwodo.local/mock-payment?paymentstatus=success&payment_id=$mockId',
      );
    }

    final data = await _callPaymentApi('initiate', body);
    return MonerooPaymentResult(
      id: data['id'] as String? ?? '',
      checkoutUrl: data['checkout_url'] as String? ?? '',
    );
  }

  /// Initier un paiement de commande
  Future<MonerooPaymentResult> initierCommande({
    required int montant,
    required String clientEmail,
    required String clientPrenom,
    required String clientNom,
    required String commandeId,
    String paysId = 'TG',
    String devise = 'XOF',
    List<String> methods = const ['moov_tg', 'togocel'],
  }) async {
    final body = {
      'amount': montant,
      'currency': devise,
      'description': 'Commande Miwodo #$commandeId',
      'customer': {
        'email': clientEmail,
        'first_name': clientPrenom,
        'last_name': clientNom,
      },
      'methods': methods,
      'return_url': 'https://miwodo.app/payment/callback',
      'metadata': {
        'type': 'commande',
        'commande_id': commandeId,
        'pays_id': paysId,
      },
    };

    if (enableMock) {
      final mockId = 'MOCK_CMD_${DateTime.now().millisecondsSinceEpoch}';
      return MonerooPaymentResult(
        id: mockId,
        checkoutUrl:
            'https://miwodo.local/mock-payment?paymentstatus=success&payment_id=$mockId',
      );
    }

    final data = await _callPaymentApi('initiate', body);
    return MonerooPaymentResult(
      id: data['id'] as String? ?? '',
      checkoutUrl: data['checkout_url'] as String? ?? '',
    );
  }

  /// Initier un paiement de publicité
  Future<MonerooPaymentResult> initierPublicite({
    required String plan,
    required String prestataireEmail,
    required String prestataireNom,
    String paysId = 'TG',
    String devise = 'XOF',
    num montant = 2000,
    List<String> methods = const ['moov_tg', 'togocel'],
  }) async {
    final body = {
      'amount': montant.toInt(),
      'currency': devise,
      'description': 'Publicité $plan - Miwodo',
      'customer': {
        'email': prestataireEmail,
        'first_name': prestataireNom,
        'last_name': prestataireNom,
      },
      'methods': methods,
      'return_url': 'https://miwodo.app/payment/callback',
      'metadata': {'type': 'publicite', 'plan': plan, 'pays_id': paysId},
    };

    if (enableMock) {
      final mockId = 'MOCK_PUB_${DateTime.now().millisecondsSinceEpoch}';
      return MonerooPaymentResult(
        id: mockId,
        checkoutUrl:
            'https://miwodo.local/mock-payment?paymentstatus=success&payment_id=$mockId',
      );
    }

    final data = await _callPaymentApi('initiate', body);
    return MonerooPaymentResult(
      id: data['id'] as String? ?? '',
      checkoutUrl: data['checkout_url'] as String? ?? '',
    );
  }

  /// Vérifier le statut d'un paiement
  Future<MonerooVerifyResult> verifierPaiement(String paymentId) async {
    if (enableMock) {
      // Immediately return success for mock payments
      return MonerooVerifyResult(
        id: paymentId,
        status: 'success',
        amount: null,
      );
    }

    final data = await _callPaymentApi('verify', {
      'payment_id': paymentId,
    });

    return MonerooVerifyResult(
      id: data['id'] as String? ?? '',
      status: data['status'] as String? ?? 'unknown',
      amount: data['amount'] as int?,
    );
  }
}
