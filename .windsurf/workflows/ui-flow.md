---
description: Documentation complete du flow UI de l'application MIWODO
---

# Flow UI MIWODO — Documentation complete

## 1. Splash Screen (`/splash`)
- Fond orange `#F97316`
- Logo "M" + texte "MIWODO"
- Tagline : "Artisans · Pros · Vendeurs · Livreurs"
- Animation : scale + fade
- Redirection auto apres 1.8s :
  - User connecte + admin → `/admin`
  - User connecte non-admin → `/accueil`
  - Premier lancement (pas `onboarding_done`) → `/onboarding`
  - Sinon → `/accueil`

## 2. Onboarding (`/onboarding`) — NOUVEAU
- 3 pages avec PageView :
  1. **Artisans & Professionnels** (icône `ic_artisan.svg`)
     - "Trouvez macons, menuisiers, electriciens, avocats, medecins..."
  2. **Boutiques & Restaurants** (icône `ic_vendeur.svg`)
     - "Commandez vos produits en ligne, payez directement..."
  3. **Livraison Express** (icône `ic_livreur.svg`)
     - "Livreurs disponibles par moto, voiture ou velo..."
- Features chips sur chaque page : "500 F inscription", "100 F/parrainage", "Paiements directs", "Multi-pays"
- Dots indicator + bouton "Suivant" / "C'est parti !"
- Bouton "Passer" en haut a droite
- Sauvegarde `onboarding_done = true` dans SharedPreferences
- Redirection → `/selection-pays`

## 3. Selection Pays (`/selection-pays`)
- Liste des pays groupes par region
- Drapeau emoji + nom du pays
- GPS detection automatique du pays
- Redirection → `/login` ou `/accueil`

## 4. Login (`/login`)
- Fond degrade orange clair + cercles decoratifs
- Logo texte "miwodo" en orange + tagline
- Titre : "Connexion" / "Connectez-vous pour acceder a votre espace"
- Champ **Telephone** (placeholder "+228 90 00 00 00", icône `ic_phone.svg`)
- Champ **Mot de passe** (icône lock, toggle visibilite)
- Checkbox "Se souvenir de moi"
- Lien "Mot de passe oublie ?"
- Bouton "Se connecter" (orange, animation)
- Lien "Pas encore de compte ? S'inscrire" → `/inscription`
- Conversion telephone → email `@miwodo.app` pour Firebase Auth

## 5. Inscription (`/inscription`) — 4 etapes
- Etape 1 : Type de profil (Client gratuit, Artisan/Pro/Vendeur/Livreur 500 F)
- Etape 2 : Informations personnelles (nom, telephone, email, specialite, ville, zone)
- Etape 3 : Photos/media
- Etape 4 : Paiement Moneroo (montant dynamique selon pays)
- Redirection → `/accueil`

## 6. Bottom Navigation (5 onglets)
| Onglet | Icône SVG | Route | Visible si |
|--------|-----------|-------|------------|
| Accueil | `ic_home.svg` | `/accueil` | Toujours |
| Boutique | `ic_cart.svg` | `/commander` | Toujours |
| Commandes | `ic_orders.svg` | `/mes-commandes` | Connecte |
| Messages | `ic_chat.svg` | `/messages` | Connecte |
| Profil | `ic_user.svg` | `/compte` | Toujours |

- Non-connecte : 3 onglets (Accueil, Boutique, Profil)
- Connecte : 5 onglets
- Badge rouge sur Boutique (nombre d'articles dans le panier)
- Couleur active : `#F97316` (orange)
- Couleur inactive : `#9CA3AF` (gris)

## 7. Accueil / Marketplace (`/accueil`)
- **AppBar** : "miwodo" (orange, Inter font) + bouton connexion/deconnexion (SVG)
- **Hero Banner** : degrade orange, "miwodo" + tagline + localisation (icône `ic_location.svg`)
- **Barre de recherche** : carte flottante, placeholder "Rechercher macon, avocat..."
- **Categories** : grille 3 colonnes (Tous, Artisans, Liberaux, Vendeurs, Livreurs)
- **Sections** (avec icônes SVG) :
  - Services sponsorises (`ic_star.svg`)
  - Prestataires en vedette ("Voir tout")
  - Services populaires (`ic_chart.svg`)
  - Produits populaires (`ic_cart.svg`)
  - Boutiques recommandees (`ic_vendeur.svg`)
  - Livreurs disponibles (`ic_two_wheeler.svg`)
  - Nouveaux prestataires ("Voir tout")
- **CTA "Vous proposez un service ?"** : carte degrade orange avec icône `ic_briefcase.svg`
- **Banniere parrainage** : "Gagnez 100 F CFA par filleul inscrit" (icône `ic_gift.svg`)

## 8. Boutique (`/commander`)
- Liste des produits disponibles
- Ajout au panier
- Badge sur bottom nav

## 9. Mes Commandes (`/mes-commandes`) — NOUVEAU
- AppBar : "Mes commandes" + bouton retour
- Liste des commandes du client (Firestore `clientUid`)
- Carte par commande :
  - Numero commande + statut colore (bleu=paye, jaune=en cours, vert=livre, rouge=litige)
  - Nom vendeur/boutique (icône `ic_user.svg`)
  - Zone livraison (icône `ic_location.svg`)
  - Nombre articles + total en F (orange)
- Etat vide : icône `ic_orders.svg` + "Aucune commande"
- Tap → `/suivi-commande/:id`

## 10. Messages (`/messages`)
- Liste des conversations
- Redirection `/login` si non-connecte
- Tap → `/messages/:id` (ConversationScreen)

## 11. Profil / Dashboard (`/compte`)
### Si non-connecte :
- Prompt de connexion (icône `ic_user.svg`)
- Boutons "Se connecter" / "Creer un compte"

### Si connecte sans profil prestataire :
- Prompt creation de profil
- Ou redirect admin si adminRole actif

### Si connecte avec profil prestataire :
- **Header** : degrade orange
  - Nom du prestataire
  - Boutons "Mes services" (`ic_briefcase.svg`) + "Mon profil" (`ic_user.svg`)
  - 3 metric cards avec icônes SVG :
    - Revenus "Ce mois" (`ic_money.svg`)
    - Commandes (`ic_orders.svg`)
    - Note moy. (`ic_star.svg`)
- **TabBar** 6 onglets :
  1. Vue d'ensemble
  2. Mes services
  3. Commandes (avec filtres : Toutes, En cours, Livrees)
  4. Messages
  5. Parrainage
  6. Publicite

## 12. Ecrans detail (hors bottom nav)
- `/prestataire/:id` — Detail prestataire
- `/service/:id` — Detail service
- `/prestataires` — Liste complete prestataires
- `/profil/:id` — Profil public prestataire
- `/mes-services/:id` — Gestion services
- `/mes-produits/:id` — Gestion produits
- `/panier` — Panier
- `/suivi-commande/:id` — Suivi commande
- `/messages/:id` — Conversation chat
- `/contact/:id` — Contact guest (non-connecte)
- `/parrainage/:code` — Inscription avec code parrain

## 13. Admin (`/admin/*`)
- Espace separe, hors bottom nav
- Redirect automatique si non-admin
- 14+ ecrans : users, stats, prestataires, avis, commandes, revenus, equipe, signalements, sponsoring, notifications, configuration, retraits

## Palette de couleurs
| Couleur | Hex | Usage |
|---------|-----|-------|
| primaryOrange | `#F97316` | Boutons, accents, actif |
| primaryOrangeDark | `#EA6C0A` | Presses, degrades |
| primaryOrangeLight | `#FFF4ED` | Fonds clairs |
| white | `#FFFFFF` | Cartes, bottom nav |
| surfaceGray | `#F9F9F9` | Fond de l'app |
| borderGray | `#EEEEEE` | Bordures |
| textPrimary | `#1A1A1A` | Texte principal |
| textSecondary | `#6B7280` | Texte secondaire |
| successGreen | `#16A34A` | Succes, livre |
| errorRed | `#DC2626` | Erreur, litige |
| infoBlue | `#3B82F6` | Info, paye |
| warningYellow | `#F59E0B` | Avertissement, en cours |

## Icônes SVG utilisees
Toutes les icônes sont dans `assets/icons/` :
`ic_home`, `ic_cart`, `ic_orders`, `ic_chat`, `ic_user`, `ic_phone`, `ic_location`, `ic_search`, `ic_star`, `ic_money`, `ic_briefcase`, `ic_artisan`, `ic_vendeur`, `ic_livreur`, `ic_two_wheeler`, `ic_gift`, `ic_arrow_back`, `ic_arrow_down`, `ic_close`, `ic_check`, `ic_settings`, `ic_edit`, `ic_camera`, `ic_image`, `ic_plus`, `ic_remove`, `ic_share`, `ic_shield`, `ic_verified`, `ic_chart`, `ic_flag`, `ic_clock`, `ic_info`, `ic_error`, `ic_success`, `ic_email`, `ic_person`, `ic_users`, `ic_team`, `ic_work`, `ic_calendar`, `ic_copy`, `ic_more`, `ic_photo`, `ic_radio_checked`, `ic_radio_unchecked`, `ic_dashboard`, `ic_liberal`, `ic_message`

## Fonts
- **Inter** (Google Fonts) : texte principal, titres
- **Poppins** : ancien usage residuel dans home (a unifier)

## Regles de design
- Toutes les icônes en SVG (PAS d'emojis)
- Couleurs : uniquement la palette `AppColors` existante
- Cartes : blanc avec bordures `borderGray`, radius 12-16
- Boutons : orange `#F97316`, radius 14, hauteur 52
- Bottom nav : blanc avec bordure top `borderGray`
- Fond app : `surfaceGray` (#F9F9F9)
- Header : degrade orange avec radius bottom 20-24
