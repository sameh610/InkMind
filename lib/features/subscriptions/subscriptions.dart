import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

abstract class SubscriptionService {
  bool get pro;
  bool get isDemo;
  bool get isTestStore => false;
  String? get annualPrice => null;
  String? get monthlyPrice => null;
  Future<void> initialize();
  Future<void> purchase({required bool annual});
  Future<void> restore();
}

class DemoSubscriptionService implements SubscriptionService {
  @override
  bool get isTestStore => false;
  @override
  String? get annualPrice => '\$49.99/year';
  @override
  String? get monthlyPrice => '\$7.99/month';
  bool _pro = false;
  @override
  bool get pro => _pro;
  @override
  bool get isDemo => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> purchase({required bool annual}) async {
    _pro = true;
  }

  @override
  Future<void> restore() async {}
}

class RevenueCatSubscriptionService implements SubscriptionService {
  static const entitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT',
    defaultValue: 'inkmind_pro',
  );
  Offerings? _offerings;
  @override
  bool get isTestStore =>
      const String.fromEnvironment('REVENUECAT_PUBLIC_KEY').startsWith('test_');
  @override
  String? get annualPrice =>
      _offerings?.current?.annual?.storeProduct.priceString;
  @override
  String? get monthlyPrice =>
      _offerings?.current?.monthly?.storeProduct.priceString;
  bool _pro = false;
  @override
  bool get pro => _pro;
  @override
  bool get isDemo => false;
  void _update(CustomerInfo info) {
    _pro = info.entitlements.active.containsKey(entitlementId);
  }

  @override
  Future<void> initialize() async {
    const key = String.fromEnvironment('REVENUECAT_PUBLIC_KEY');
    if (key.isEmpty) {
      throw StateError(
        'Configure REVENUECAT_PUBLIC_KEY with a RevenueCat public SDK key.',
      );
    }
    if (kDebugMode && !key.startsWith('test_')) {
      throw StateError('Debug builds must use a RevenueCat Test Store key.');
    }
    await Purchases.configure(PurchasesConfiguration(key));
    Purchases.addCustomerInfoUpdateListener(_update);
    _update(await Purchases.getCustomerInfo());
    _offerings = await Purchases.getOfferings();
  }

  @override
  Future<void> purchase({required bool annual}) async {
    final offering = (await Purchases.getOfferings()).current;
    final package = annual ? offering?.annual : offering?.monthly;
    if (package == null) {
      throw StateError(
        'Configure monthly and annual packages in the current RevenueCat offering.',
      );
    }
    final result = await Purchases.purchase(PurchaseParams.package(package));
    _update(result.customerInfo);
    if (!_pro) {
      throw StateError(
        'Purchase completed, but the $entitlementId entitlement is not active. Check the product entitlement in RevenueCat.',
      );
    }
  }

  @override
  Future<void> restore() async {
    _update(await Purchases.restorePurchases());
  }
}
