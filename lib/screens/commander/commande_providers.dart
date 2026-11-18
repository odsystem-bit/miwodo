// screens/commander/commande_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/categories.dart';
import '../../models/prestataire.dart';
import '../../models/produit.dart';
import '../../services/firestore_service.dart';

final productsProvider = StreamProvider.autoDispose<List<Produit>>((ref) {
  return FirestoreService.instance.getProduits().map(
    (produits) => produits.where((produit) => produit.estDisponible).take(50).toList(),
  );
});

final vendeursProvider = StreamProvider.autoDispose<List<Prestataire>>((ref) {
  return FirestoreService.instance.getPrestataires().map(
    (list) => list.where((p) => p.categorie == 'Vendeur').take(30).toList(),
  );
});

final livreursProvider = StreamProvider.autoDispose<List<Prestataire>>((ref) {
  return FirestoreService.instance
      .getPrestataires(categorie: Categorie.livreur)
      .map(
        (livreurs) =>
            livreurs.where((livreur) => livreur.estDisponible).take(30).toList(),
      );
});

final selectedLivreurIdProvider = StateProvider<String?>((ref) => null);
final checkoutLoadingProvider = StateProvider<bool>((ref) => false);

class CartItem {
  final Produit produit;
  final int quantity;

  CartItem({required this.produit, required this.quantity});

  CartItem copyWith({Produit? produit, int? quantity}) {
    return CartItem(
      produit: produit ?? this.produit,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartState {
  final Map<String, CartItem> items;

  CartState([Map<String, CartItem>? items])
    : items = Map.unmodifiable(items ?? {});

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get totalItems =>
      items.values.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount => items.values.fold(
    0.0,
    (sum, item) => sum + item.produit.prix * item.quantity,
  );
  List<CartItem> get itemsList => items.values.toList();

  int quantityFor(String produitId) => items[produitId]?.quantity ?? 0;
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void add(Produit produit) {
    final existing = state.items[produit.id];
    final next = Map<String, CartItem>.from(state.items);
    if (existing == null) {
      next[produit.id] = CartItem(produit: produit, quantity: 1);
    } else {
      next[produit.id] = existing.copyWith(quantity: existing.quantity + 1);
    }
    state = CartState(next);
  }

  void decrement(Produit produit) {
    final existing = state.items[produit.id];
    if (existing == null) return;

    final next = Map<String, CartItem>.from(state.items);
    if (existing.quantity <= 1) {
      next.remove(produit.id);
    } else {
      next[produit.id] = existing.copyWith(quantity: existing.quantity - 1);
    }
    state = CartState(next);
  }

  void remove(Produit produit) {
    final next = Map<String, CartItem>.from(state.items);
    next.remove(produit.id);
    state = CartState(next);
  }

  void setQuantity(Produit produit, int quantity) {
    final next = Map<String, CartItem>.from(state.items);
    if (quantity <= 0) {
      next.remove(produit.id);
    } else {
      next[produit.id] = CartItem(produit: produit, quantity: quantity);
    }
    state = CartState(next);
  }

  void addMultiple(Produit produit, int count) {
    if (count <= 0) return;
    final existing = state.items[produit.id];
    final next = Map<String, CartItem>.from(state.items);
    final currentQty = existing?.quantity ?? 0;
    next[produit.id] = CartItem(produit: produit, quantity: currentQty + count);
    state = CartState(next);
  }

  void clear() {
    state = CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalItems;
});

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).totalAmount;
});
