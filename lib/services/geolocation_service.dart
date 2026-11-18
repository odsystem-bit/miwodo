// services/geolocation_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../models/commande.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE DE GÉOLOCALISATION
// ═══════════════════════════════════════════════════════════════════════════

class GeolocationService {
  static final GeolocationService instance = GeolocationService._();
  GeolocationService._();

  // Cache des zones avec leurs coordonnées
  Map<String, ZoneGeo>? _zonesCache;

  // ─────────────────────────────────────────────────────────────────────────
  // PERMISSIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POSITION ACTUELLE
  // ─────────────────────────────────────────────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Erreur géolocalisation: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REVERSE GEOCODING
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> getAddressFromCoords(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'
            .replaceAll(RegExp(r'^, |, $'), '');
      }
    } catch (e) {
      debugPrint('Erreur reverse geocoding: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DÉTECTION DE ZONE MIWODO
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadZones() async {
    if (_zonesCache != null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('zones')
          .get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final zonesData = data['zones'] as Map<String, dynamic>? ?? {};
        
        _zonesCache = {};
        zonesData.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _zonesCache![key] = ZoneGeo.fromJson(key, value);
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement zones: $e');
      _zonesCache = _getDefaultZones();
    }
  }

  Map<String, ZoneGeo> _getDefaultZones() {
    return {
      // Lomé
      'tokoin': ZoneGeo(id: 'tokoin', nom: 'Tokoin', centerLat: 6.1725, centerLng: 1.2314, radiusKm: 3.0),
      'adidogome': ZoneGeo(id: 'adidogome', nom: 'Adidogomé', centerLat: 6.1850, centerLng: 1.1850, radiusKm: 4.0),
      'be': ZoneGeo(id: 'be', nom: 'Bè', centerLat: 6.1400, centerLng: 1.2100, radiusKm: 3.0),
      'agoe': ZoneGeo(id: 'agoe', nom: 'Agoè', centerLat: 6.2100, centerLng: 1.2000, radiusKm: 4.0),
      'lome_centre': ZoneGeo(id: 'lome_centre', nom: 'Lomé Centre', centerLat: 6.1319, centerLng: 1.2228, radiusKm: 2.5),
      // Cotonou
      'ganhi': ZoneGeo(id: 'ganhi', nom: 'Ganhi', centerLat: 6.3654, centerLng: 2.3986, radiusKm: 3.0),
      'akpakpa': ZoneGeo(id: 'akpakpa', nom: 'Akpakpa', centerLat: 6.3700, centerLng: 2.4200, radiusKm: 4.0),
      // Abidjan
      'cocody': ZoneGeo(id: 'cocody', nom: 'Cocody', centerLat: 5.3600, centerLng: -4.0083, radiusKm: 5.0),
      'plateau_abj': ZoneGeo(id: 'plateau_abj', nom: 'Plateau', centerLat: 5.3167, centerLng: -4.0167, radiusKm: 3.0),
      // Dakar
      'plateau_dkr': ZoneGeo(id: 'plateau_dkr', nom: 'Plateau', centerLat: 14.6700, centerLng: -17.4400, radiusKm: 3.0),
      'ouakam': ZoneGeo(id: 'ouakam', nom: 'Ouakam', centerLat: 14.7186, centerLng: -17.4944, radiusKm: 4.0),
    };
  }

  Future<String?> detectZoneFromPosition(Position position) async {
    await _loadZones();
    if (_zonesCache == null || _zonesCache!.isEmpty) return null;

    String? closestZone;
    double minDistance = double.infinity;

    for (final zone in _zonesCache!.values) {
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        zone.centerLat,
        zone.centerLng,
      );

      // Si dans le rayon de la zone
      if (distance <= zone.radiusKm) {
        if (distance < minDistance) {
          minDistance = distance;
          closestZone = zone.id;
        }
      }
    }

    // Si aucune zone exacte, retourner la plus proche
    if (closestZone == null) {
      for (final zone in _zonesCache!.values) {
        final distance = _calculateDistance(
          position.latitude,
          position.longitude,
          zone.centerLat,
          zone.centerLng,
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestZone = zone.id;
        }
      }
    }

    return closestZone;
  }

  Future<DetectionZoneResult> detectZoneWithDetails(Position position) async {
    await _loadZones();
    if (_zonesCache == null || _zonesCache!.isEmpty) {
      return DetectionZoneResult(
        zone: null,
        estExacte: false,
        distanceKm: null,
        zonesProches: [],
      );
    }

    String? zoneExacte;
    double? distanceZoneExacte;
    List<ZoneProche> zonesProches = [];

    for (final zone in _zonesCache!.values) {
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        zone.centerLat,
        zone.centerLng,
      );

      if (distance <= zone.radiusKm) {
        // Zone exacte
        if (zoneExacte == null || distance < distanceZoneExacte!) {
          zoneExacte = zone.id;
          distanceZoneExacte = distance;
        }
      } else if (distance <= zone.radiusKm * 2) {
        // Zone proche (dans le double du rayon)
        zonesProches.add(ZoneProche(
          zoneId: zone.id,
          zoneNom: zone.nom,
          distanceKm: distance,
        ));
      }
    }

    // Trier les zones proches par distance
    zonesProches.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return DetectionZoneResult(
      zone: zoneExacte,
      estExacte: zoneExacte != null,
      distanceKm: distanceZoneExacte,
      zonesProches: zonesProches.take(3).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVREURS DISPONIBLES PAR ZONE
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<LivreurDisponible>> getLivreursDisponibles({
    required String zone,
    GeoPoint? clientCoords,
  }) async {
    try {
      // 1. Livreurs de la zone exacte
      final exactQuery = await FirebaseFirestore.instance
          .collection('prestataires')
          .where('categorie', isEqualTo: 'livreur')
          .where('estDisponible', isEqualTo: true)
          .where('actif', isEqualTo: true)
          .get();

      List<LivreurDisponible> livreursExacts = [];
      List<LivreurDisponible> livreursProches = [];

      for (final doc in exactQuery.docs) {
        final data = doc.data();
        final tarifsZones = data['tarifs_zones'] as Map<String, dynamic>? ?? {};
        final zonePrincipale = data['zone'] as String? ?? '';

        // Vérifie si le livreur couvre cette zone
        final tarifPourZone = tarifsZones[zone] as num?;
        
        if (tarifPourZone != null) {
          // Calcul distance si coords disponibles
          double? distance;
          if (clientCoords != null) {
            final livreurZone = _zonesCache?[zonePrincipale];
            if (livreurZone != null) {
              distance = _calculateDistance(
                clientCoords.latitude,
                clientCoords.longitude,
                livreurZone.centerLat,
                livreurZone.centerLng,
              );
            }
          }

          final livreur = LivreurDisponible(
            id: doc.id,
            nom: data['nom'] as String? ?? '',
            prenom: data['prenom'] as String? ?? '',
            photoUrl: data['photoUrl'] as String?,
            typeEngin: data['type_engin'] as String? ?? 'moto',
            noteMoyenne: (data['noteMoyenne'] as num?)?.toDouble() ?? 0,
            nbAvis: (data['nbAvis'] as num?)?.toInt() ?? 0,
            tarifPourZone: tarifPourZone.toInt(),
            zonePrincipale: zonePrincipale,
            estZoneExacte: zonePrincipale == zone,
            distanceEstimee: distance,
          );

          if (zonePrincipale == zone) {
            livreursExacts.add(livreur);
          } else {
            livreursProches.add(livreur);
          }
        }
      }

      // Trier par note puis par distance
      livreursExacts.sort((a, b) {
        final noteCompare = b.noteMoyenne.compareTo(a.noteMoyenne);
        if (noteCompare != 0) return noteCompare;
        return (a.distanceEstimee ?? 999).compareTo(b.distanceEstimee ?? 999);
      });

      livreursProches.sort((a, b) {
        return (a.distanceEstimee ?? 999).compareTo(b.distanceEstimee ?? 999);
      });

      return [...livreursExacts, ...livreursProches];
    } catch (e) {
      debugPrint('Erreur chargement livreurs: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CALCUL DE DISTANCE (Haversine)
  // ─────────────────────────────────────────────────────────────────────────

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<String>> getZonesActives() async {
    await _loadZones();
    return _zonesCache?.keys.toList() ?? [];
  }

  Future<String?> getZoneNom(String zoneId) async {
    await _loadZones();
    return _zonesCache?[zoneId]?.nom;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES AUXILIAIRES
// ═══════════════════════════════════════════════════════════════════════════

class ZoneGeo {
  final String id;
  final String nom;
  final double centerLat;
  final double centerLng;
  final double radiusKm;

  ZoneGeo({
    required this.id,
    required this.nom,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
  });

  factory ZoneGeo.fromJson(String id, Map<String, dynamic> json) {
    return ZoneGeo(
      id: id,
      nom: json['nom'] as String? ?? id,
      centerLat: (json['center_lat'] as num?)?.toDouble() ?? 0,
      centerLng: (json['center_lng'] as num?)?.toDouble() ?? 0,
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 3.0,
    );
  }
}

class DetectionZoneResult {
  final String? zone;
  final bool estExacte;
  final double? distanceKm;
  final List<ZoneProche> zonesProches;

  DetectionZoneResult({
    this.zone,
    required this.estExacte,
    this.distanceKm,
    required this.zonesProches,
  });
}

class ZoneProche {
  final String zoneId;
  final String zoneNom;
  final double distanceKm;

  ZoneProche({
    required this.zoneId,
    required this.zoneNom,
    required this.distanceKm,
  });
}
