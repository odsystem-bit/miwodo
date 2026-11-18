// screens/commercial/commercial_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/miwodo_button.dart';

class CommercialDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> commercialData;

  const CommercialDashboardScreen({
    super.key,
    required this.commercialData,
  });

  @override
  State<CommercialDashboardScreen> createState() => _CommercialDashboardScreenState();
}

class _CommercialDashboardScreenState extends State<CommercialDashboardScreen> {
  late Map<String, dynamic> _com;
  List<dynamic> _inscriptions = [];
  List<dynamic> _retraits = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _com = Map<String, dynamic>.from(widget.commercialData);
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('https://bot.odsysteme.tech/api/commercial_auth.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'get_dashboard',
          'code': _com['code'],
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() {
            _com = data['commercial'];
            _inscriptions = data['inscriptions'] ?? [];
            _retraits = data['retraits'] ?? [];
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _copyLink() {
    final link = _com['lien_parrainage'] ?? 'https://bot.odsysteme.tech/parrainage/${_com['code']}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lien de terrain copié dans le presse-papier !'),
        backgroundColor: Color(0xFF15803D),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showQrCodeModal() {
    final qrUrl = _com['qr_code_url'] ??
        'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(_com['lien_parrainage'] ?? '')}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Mon QR Code de Terrain',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.network(
                qrUrl,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Code : ${_com['code']}',
              style: GoogleFonts.spaceMono(
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFF7A00),
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Faites scanner ce QR code directement par l'artisan pour lier son inscription à votre compte.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Fermer',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showDemandeRetraitModal() {
    final solde = (_com['solde_gains'] as num?)?.toDouble() ?? 0.0;
    final minRetrait = (_com['retrait_minimum'] as num?)?.toDouble() ?? 500.0;

    if (solde < minRetrait) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solde insuffisant ($solde F CFA). Le seuil minimum est de $minRetrait F CFA.',
          ),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
      return;
    }

    final montantCtrl = TextEditingController(text: solde.toInt().toString());
    final telCtrl = TextEditingController(text: _com['telephone'] ?? '');
    final beneficiaireCtrl = TextEditingController(text: '${_com['prenom']} ${_com['nom']}');
    String moyen = 'TMoney';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Demander un Retrait Mobile Money',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Recevez vos gains directement sur votre numéro.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: moyen,
                decoration: InputDecoration(
                  labelText: 'Opérateur',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'TMoney', child: Text('TMoney (Togo)')),
                  DropdownMenuItem(value: 'Flooz', child: Text('Flooz / Moov (Togo)')),
                  DropdownMenuItem(value: 'Wave', child: Text('Wave')),
                  DropdownMenuItem(value: 'MTN MoMo', child: Text('MTN MoMo (Bénin / CI)')),
                  DropdownMenuItem(value: 'Moov Money', child: Text('Moov Money (Bénin / CI)')),
                ],
                onChanged: (v) => setModalState(() => moyen = v ?? 'TMoney'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro Mobile Money',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: beneficiaireCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom du Bénéficiaire',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montantCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Montant à retirer (F CFA)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final montant = double.tryParse(montantCtrl.text.trim()) ?? 0.0;
                    if (montant < minRetrait || montant > solde) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Montant invalide ou solde insuffisant')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _submitRetrait(montant, moyen, telCtrl.text.trim(), beneficiaireCtrl.text.trim());
                  },
                  child: Text(
                    'Confirmer le Retrait',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRetrait(double montant, String moyen, String tel, String beneficiaire) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('https://bot.odsysteme.tech/api/commercial_auth.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'demande_retrait',
          'code': _com['code'],
          'montant': montant,
          'moyen_paiement': moyen,
          'telephone_paiement': tel,
          'nom_beneficiaire': beneficiaire,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de retrait soumise avec succès !'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
        _refreshData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Erreur lors du retrait'),
            backgroundColor: const Color(0xFFBE123C),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau : $e')),
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final solde = (_com['solde_gains'] as num?)?.toDouble() ?? 0.0;
    final totalInscrits = (_com['total_inscriptions'] as num?)?.toInt() ?? 0;
    final commission = (_com['commission_par_inscription'] as num?)?.toDouble() ?? 300.0;
    final minRetrait = (_com['retrait_minimum'] as num?)?.toDouble() ?? 500.0;
    final prenom = _com['prenom'] ?? 'Agent';
    final code = _com['code'] ?? 'COM-STAN';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.business, color: Color(0xFFFF7A00)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MIWODO',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Espace Commercial',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF7A00),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _refreshData,
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFB7185)),
            onPressed: () => context.go('/login'),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFFFF7A00),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BANNIÈRE DE BIENVENUE
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A00), Color(0xFFE11D48)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7A00).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Code Agent : $code',
                        style: GoogleFonts.spaceMono(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bienvenue, $prenom !',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Commission : ${commission.toInt()} F CFA par adhésion validée',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.share, size: 16),
                            label: Text(
                              'Partager Lien',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: _copyLink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black26,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.qr_code, size: 16),
                            label: Text(
                              'QR Code',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: _showQrCodeModal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2 CARTES KPI (SOLDE & TOTAL INSCRITS)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SOLDE DISPONIBLE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${solde.toInt()} F CFA',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4ADE80),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFF7A00)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: _showDemandeRetraitModal,
                              child: Text(
                                'Retirer',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF7A00),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ARTISANS ENRÔLÉS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$totalInscrits',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Seuil retrait : ${minRetrait.toInt()} F',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // BOUTON DIRECT D'ENRÔLEMENT SUR LE TERRAIN
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFFFF7A00), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, color: Color(0xFFFF7A00)),
                  label: Text(
                    'Enrôler un artisan maintenant',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () {
                    // Navigue vers l'inscription avec le code commercial pré-rempli
                    context.push('/inscription?ref=$code');
                  },
                ),
              ),

              const SizedBox(height: 28),

              // HISTORIQUE DES ENRÔLEMENTS
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  Text(
                    'Artisans Enrôlés (${_inscriptions.length})',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7A00)),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              if (_inscriptions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      'Aucun artisan enrôlé pour le moment.\nPartagez votre lien ou votre QR code pour commencer !',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, height: 1.5),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _inscriptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = _inscriptions[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A00).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.handyman, color: Color(0xFFFF7A00), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['filleul_nom'] ?? 'Artisan Partenaire',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item['tel_filleul'] ?? item['zone'] ?? 'Enregistré'}',
                                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+${(item['gain'] as num?)?.toInt() ?? commission.toInt()} F',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4ADE80),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
