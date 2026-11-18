// widgets/moneroo_webview.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme/app_colors.dart';
import 'miwodo_svg_icon.dart';

typedef OnSuccessCallback = void Function(String paymentId);

class MonerooWebView extends StatefulWidget {
  final String checkoutUrl;
  final String paymentId;
  final OnSuccessCallback onSuccess;
  final VoidCallback onFailure;
  final VoidCallback onClose;

  const MonerooWebView({
    super.key,
    required this.checkoutUrl,
    required this.paymentId,
    required this.onSuccess,
    required this.onFailure,
    required this.onClose,
  });

  @override
  State<MonerooWebView> createState() => _MonerooWebViewState();
}

class _MonerooWebViewState extends State<MonerooWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _autoDetected = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (req) {
            final url = req.url;
            final lower = url.toLowerCase();

            // Detect success redirect from Moneroo
            if (lower.contains('paymentstatus=success') ||
                lower.contains('payment_status=success') ||
                lower.contains('paymentstatus=successful')) {
              _handleSuccessRedirect(url);
              return NavigationDecision.prevent;
            }
            // Detect failed/cancelled redirect
            if (lower.contains('paymentstatus=failed') ||
                lower.contains('payment_status=failed') ||
                lower.contains('paymentstatus=cancelled') ||
                lower.contains('payment_status=cancelled')) {
              widget.onFailure();
              if (mounted) Navigator.of(context).pop(null);
              return NavigationDecision.prevent;
            }
            // Detect pending — don't close, let user wait
            if (lower.contains('paymentstatus=pending') ||
                lower.contains('payment_status=pending')) {
              setState(() => _loading = false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _handleSuccessRedirect(String url) {
    if (_autoDetected) return;
    _autoDetected = true;

    final uri = Uri.tryParse(url);
    final pid =
        uri?.queryParameters['paymentId'] ??
        uri?.queryParameters['payment_id'] ??
        uri?.queryParameters['id'] ??
        widget.paymentId;

    if (pid.isNotEmpty) {
      widget.onSuccess(pid);
      if (mounted) Navigator.of(context).pop(pid);
    } else {
      widget.onFailure();
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  Future<void> _confirmCancel() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Annuler le paiement ?'),
          content: const Text(
            'Si vous avez déjà payé, cliquez sur "J\'ai payé" pour confirmer votre paiement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Oui, annuler'),
            ),
          ],
        );
      },
    );
    if (res == true) {
      widget.onClose();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _manualConfirm() {
    if (_autoDetected) return;
    _autoDetected = true;
    widget.onSuccess(widget.paymentId);
    if (mounted) Navigator.of(context).pop(widget.paymentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Row(
          children: [
            MiwodoSvgIcon(
              'assets/icons/ic_lock.svg',
              size: 18,
              color: AppColors.primaryOrange,
            ),
            const SizedBox(width: 8),
            const Text(
              'Paiement sécurisé',
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: _confirmCancel,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _loading
              ? LinearProgressIndicator(
                  color: AppColors.primaryOrange,
                  backgroundColor: AppColors.primaryOrange.withAlpha(51),
                )
              : const SizedBox(height: 4),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _manualConfirm,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text(
                'J\'ai payé — Confirmer',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
