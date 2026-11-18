enum Categorie {
  artisan,
  liberal,
  vendeur,
  livreur;

  String get label {
    switch (this) {
      case Categorie.artisan:
        return 'Artisan';
      case Categorie.liberal:
        return 'Professionnel libéral';
      case Categorie.vendeur:
        return 'Vendeur';
      case Categorie.livreur:
        return 'Livreur';
    }
  }

  String get svgIcon {
    switch (this) {
      case Categorie.artisan:
        return 'assets/icons/ic_artisan.svg';
      case Categorie.liberal:
        return 'assets/icons/ic_liberal.svg';
      case Categorie.vendeur:
        return 'assets/icons/ic_vendeur.svg';
      case Categorie.livreur:
        return 'assets/icons/ic_livreur.svg';
    }
  }
}
