// screens/inscription/inscription_notifier.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/categories.dart';

class InscriptionState {
  final int etape;
  final Categorie? categorie;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final String metier;
  final String zone;
  final String? typeEngin;
  final String? tarifZone;
  final List<File> photos;
  final String description;
  final String? codeParrain;
  final String? paysId;
  final String? indicatif;
  final String password;

  const InscriptionState({
    this.etape = 1,
    this.categorie,
    this.nom = '',
    this.prenom = '',
    this.email = '',
    this.telephone = '',
    this.metier = '',
    this.zone = '',
    this.typeEngin,
    this.tarifZone,
    this.photos = const [],
    this.description = '',
    this.codeParrain,
    this.paysId,
    this.indicatif,
    this.password = '',
  });

  InscriptionState copyWith({
    int? etape,
    Categorie? categorie,
    String? nom,
    String? prenom,
    String? email,
    String? telephone,
    String? metier,
    String? zone,
    String? typeEngin,
    String? tarifZone,
    List<File>? photos,
    String? description,
    String? codeParrain,
    String? paysId,
    String? indicatif,
    String? password,
  }) {
    return InscriptionState(
      etape: etape ?? this.etape,
      categorie: categorie ?? this.categorie,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      metier: metier ?? this.metier,
      zone: zone ?? this.zone,
      typeEngin: typeEngin ?? this.typeEngin,
      tarifZone: tarifZone ?? this.tarifZone,
      photos: photos ?? this.photos,
      description: description ?? this.description,
      codeParrain: codeParrain ?? this.codeParrain,
      paysId: paysId ?? this.paysId,
      indicatif: indicatif ?? this.indicatif,
      password: password ?? this.password,
    );
  }
}

class InscriptionNotifier extends StateNotifier<InscriptionState> {
  InscriptionNotifier() : super(const InscriptionState());

  void setCategorie(Categorie c) => state = state.copyWith(categorie: c);

  void updateNom(String v) => state = state.copyWith(nom: v);
  void updatePrenom(String v) => state = state.copyWith(prenom: v);
  void updateEmail(String v) => state = state.copyWith(email: v);
  void updateTelephone(String v) => state = state.copyWith(telephone: v);
  void updateMetier(String v) => state = state.copyWith(metier: v);
  void updateZone(String v) => state = state.copyWith(zone: v);
  void updateTypeEngin(String? v) => state = state.copyWith(typeEngin: v);
  void updateTarifZone(String? v) => state = state.copyWith(tarifZone: v);
  void updateDescription(String v) => state = state.copyWith(description: v);
  void updateCodeParrain(String? v) => state = state.copyWith(codeParrain: v);
  void updatePaysId(String? v) => state = state.copyWith(paysId: v);
  void updateIndicatif(String? v) => state = state.copyWith(indicatif: v);
  void updatePassword(String v) => state = state.copyWith(password: v);

  void addPhoto(File f) => state = state.copyWith(photos: [...state.photos, f]);

  void removePhotoAt(int index) {
    final list = [...state.photos];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      state = state.copyWith(photos: list);
    }
  }

  void nextStep() {
    final next = state.etape < 7 ? state.etape + 1 : 7;
    state = state.copyWith(etape: next);
  }

  void previousStep() {
    final prev = state.etape > 1 ? state.etape - 1 : 1;
    state = state.copyWith(etape: prev);
  }

  void goToStep(int step) {
    if (step >= 1 && step <= 7) state = state.copyWith(etape: step);
  }

  void reset() => state = const InscriptionState();

  bool validateStep1() => state.prenom.isNotEmpty && state.nom.isNotEmpty && state.email.isNotEmpty && state.telephone.isNotEmpty && state.password.isNotEmpty && state.paysId != null && state.indicatif != null;

  bool validateStep2() => state.categorie != null && state.metier.isNotEmpty;

  bool validateStep3() => state.zone.isNotEmpty;

  bool validateStep4() => true; // Photos optionnelles

  bool validateStep5() => true; // Récapitulatif - toujours valide

  bool validateStep6() => true; // Paiement - toujours valide
}

final inscriptionNotifierProvider = StateNotifierProvider<InscriptionNotifier, InscriptionState>((ref) => InscriptionNotifier());
