import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseCatalog {
  const PurchaseCatalog({
    required this.storeAvailable,
    required this.products,
    required this.notFoundIds,
  });

  final bool storeAvailable;
  final List<ProductDetails> products;
  final Set<String> notFoundIds;

  ProductDetails? get monthly => _byId(PurchaseService.premiumMonthlyProductId);
  ProductDetails? get yearly => _byId(PurchaseService.premiumYearlyProductId);

  ProductDetails? _byId(String productId) {
    for (final product in products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }
}

class PurchaseService {
  factory PurchaseService() => instance;

  PurchaseService._() {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) {
        _completePendingWithError(
          PurchaseException('Satın alma akışı dinlenemedi: $error'),
        );
      },
    );
  }

  static final PurchaseService instance = PurchaseService._();

  static const premiumMonthlyProductId = 'premium_monthly_6999';
  static const premiumYearlyProductId = 'premium_yearly_59999';
  static const _productIds = {premiumMonthlyProductId, premiumYearlyProductId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<void>? _pendingPurchase;

  void initialize() {}

  Future<PurchaseCatalog> loadCatalog() async {
    final available = await _iap.isAvailable();
    if (!available) {
      return const PurchaseCatalog(
        storeAvailable: false,
        products: [],
        notFoundIds: _productIds,
      );
    }

    final response = await _iap.queryProductDetails(_productIds);
    if (response.error != null) {
      throw PurchaseException(
        response.error!.message.isNotEmpty
            ? response.error!.message
            : 'Google Play ürünleri alınamadı.',
      );
    }

    final products = response.productDetails.toList()
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    return PurchaseCatalog(
      storeAvailable: true,
      products: products,
      notFoundIds: response.notFoundIDs.toSet(),
    );
  }

  Future<void> buyMonthlyPremium() {
    return _buyPremium(premiumMonthlyProductId);
  }

  Future<void> buyYearlyPremium() {
    return _buyPremium(premiumYearlyProductId);
  }

  Future<void> restorePurchases() async {
    _ensureNoPendingPurchase();
    _pendingPurchase = Completer<void>();
    await _iap.restorePurchases();
    return _pendingPurchase!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _pendingPurchase = null;
        throw const PurchaseException(
          'Geri yüklenecek aktif abonelik bulunamadı.',
        );
      },
    );
  }

  Future<void> _buyPremium(String productId) async {
    final catalog = await loadCatalog();
    if (!catalog.storeAvailable) {
      throw const PurchaseException(
        'Google Play satın alma servisi bu cihazda hazır değil.',
      );
    }

    final product = catalog._byId(productId);
    if (product == null) {
      throw PurchaseException(
        '$productId ürünü Google Play Console’da aktif görünmüyor.',
      );
    }

    _ensureNoPendingPurchase();
    _pendingPurchase = Completer<void>();
    final purchaseParam = PurchaseParam(productDetails: product);
    final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    if (!started) {
      _pendingPurchase = null;
      throw const PurchaseException('Satın alma başlatılamadı.');
    }
    final pending = _pendingPurchase!;
    return pending.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        if (identical(_pendingPurchase, pending)) {
          _pendingPurchase = null;
        }
        throw const PurchaseException(
          'Ödeme Google Play’de bekliyor olabilir. Durumu Play Store’dan kontrol edip Satın alımı geri yükle seçeneğini kullan.',
        );
      },
    );
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    var handledPurchase = false;
    for (final purchase in purchases) {
      if (!_productIds.contains(purchase.productID)) {
        continue;
      }

      handledPurchase = true;
      try {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            break;
          case PurchaseStatus.error:
            throw PurchaseException(
              purchase.error?.message ?? 'Satın alma tamamlanamadı.',
            );
          case PurchaseStatus.canceled:
            throw const PurchaseException('Satın alma iptal edildi.');
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await _verifyWithBackend(purchase);
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            _completePending();
            break;
        }
      } catch (error) {
        _completePendingWithError(
          error is PurchaseException
              ? error
              : PurchaseException(error.toString()),
        );
      }
    }

    if (!handledPurchase && _pendingPurchase != null) {
      debugPrint('Purchase update ignored because product id did not match.');
    }
  }

  Future<void> _verifyWithBackend(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw const PurchaseException(
        'Premium satın almak için Google hesabınla giriş yapmalısın.',
      );
    }

    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) {
      throw const PurchaseException('Satın alma doğrulama bilgisi boş geldi.');
    }

    final response = await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('verifyGooglePlayPurchase')
        .call<Map<String, dynamic>>({
          'productId': purchase.productID,
          'purchaseToken': token,
        });
    final data = Map<String, dynamic>.from(response.data);
    final verifiedPurchase = data['purchase'];
    if (verifiedPurchase is! Map ||
        verifiedPurchase['subscriptionActive'] != true) {
      throw const PurchaseException(
        'Google Play aboneliği aktif görünmüyor. Satın alma tamamlanmadı ve tekrar doğrulanacak.',
      );
    }
  }

  void _ensureNoPendingPurchase() {
    if (_pendingPurchase != null && !_pendingPurchase!.isCompleted) {
      throw const PurchaseException(
        'Devam eden bir satın alma işlemi var. Lütfen sonucu bekle.',
      );
    }
  }

  void _completePending() {
    final pending = _pendingPurchase;
    _pendingPurchase = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  void _completePendingWithError(PurchaseException error) {
    final pending = _pendingPurchase;
    _pendingPurchase = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(error);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

class PurchaseException implements Exception {
  const PurchaseException(this.message);

  final String message;

  @override
  String toString() => message;
}
