// core/utils/formatters.dart
// Fonctions utilitaires de formatage partagées dans toute l'app

import '../../models/pays.dart';

/// Formate un montant selon le symbole de la devise active.
/// Devises occidentales (€, CA$, US$, £) : 2 décimales, symbole avant.
/// Devises africaines (F CFA…) : entier, symbole après.
String formatPrix(num montant, String symbole) {
  const western = ['€', 'CA\$', 'US\$', '£', '\$'];
  if (western.contains(symbole)) {
    return '$symbole${montant.toStringAsFixed(2)}';
  }
  return '${montant.toInt()} $symbole';
}

/// Variante avec un objet Pays complet.
String formatPrixAvecPays(num montant, Pays pays) {
  return formatPrix(montant, pays.symbole);
}
