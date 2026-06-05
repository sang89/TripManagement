import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_keys.dart';

const _kEntitlement = 'pro';
const _kApp = 'trip_management';

class SubscriptionProvider extends ChangeNotifier {
  bool _isPro = false;
  bool _isLoading = false;
  bool _rcConfigured = false;
  DateTime? _currentPeriodEnd;
  DateTime? _trialEndsAt;

  bool get isPro => _isPro;
  bool get isLoading => _isLoading;
  DateTime? get currentPeriodEnd => _currentPeriodEnd;
  DateTime? get trialEndsAt => _trialEndsAt;

  bool get isInTrial =>
      _trialEndsAt != null && _trialEndsAt!.isAfter(DateTime.now());

  Future<void> load(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (kIsWeb) {
        await _loadFromSupabase(userId);
      } else {
        await _ensureRcConfigured();
        if (_rcConfigured) {
          await _loadFromRevenueCat(userId);
        } else {
          // RC keys not set (dev build) — fall back to Supabase
          await _loadFromSupabase(userId);
        }
      }
    } catch (e) {
      debugPrint('[SubscriptionProvider] load error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadFromSupabase(String userId) async {
    final row = await Supabase.instance.client
        .from('user_subscriptions')
        .select()
        .eq('user_id', userId)
        .eq('app', _kApp)
        .maybeSingle();

    if (row != null) {
      final tier = row['tier'] as String?;
      _isPro = tier == 'pro' || tier == 'admin';

      final trialStr = row['trial_ends_at'] as String?;
      _trialEndsAt =
          trialStr != null ? DateTime.tryParse(trialStr) : null;

      // Trial counts as Pro until it expires
      if (!_isPro && isInTrial) _isPro = true;

      final endStr = row['current_period_end'] as String?;
      _currentPeriodEnd =
          endStr != null ? DateTime.tryParse(endStr) : null;
    } else {
      _isPro = false;
      _trialEndsAt = null;
      _currentPeriodEnd = null;
    }
  }

  Future<void> _loadFromRevenueCat(String userId) async {
    await _ensureRcConfigured();
    if (!_rcConfigured) return;
    await Purchases.logIn(userId);
    final info = await Purchases.getCustomerInfo();
    final ent = info.entitlements.active[_kEntitlement];
    _isPro = ent != null && ent.isActive;
    _currentPeriodEnd =
        ent != null ? DateTime.tryParse(ent.expirationDate ?? '') : null;
    // On mobile, treat intro/trial period type as isInTrial
    if (ent != null && ent.periodType == PeriodType.trial) {
      _trialEndsAt = _currentPeriodEnd;
    }
  }

  Future<void> _ensureRcConfigured() async {
    if (_rcConfigured) return;
    final apiKey = defaultTargetPlatform == TargetPlatform.iOS
        ? kRevenueCatAppleApiKey
        : kRevenueCatGoogleApiKey;
    if (apiKey.contains('REPLACE_ME')) return;
    await Purchases.configure(PurchasesConfiguration(apiKey));
    if (!kReleaseMode) await Purchases.setLogLevel(LogLevel.debug);
    _rcConfigured = true;
  }

  /// Starts a 14-day free trial. No-op if a subscription row already exists.
  Future<void> startTrial() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final trialEnd = DateTime.now().add(const Duration(days: 14));

    await Supabase.instance.client.from('user_subscriptions').upsert(
      {
        'user_id': userId,
        'app': _kApp,
        'tier': 'free',
        'trial_ends_at': trialEnd.toIso8601String(),
        'current_period_end': trialEnd.toIso8601String(),
      },
      onConflict: 'user_id,app',
      ignoreDuplicates: true,
    );

    await _loadFromSupabase(userId);
    notifyListeners();
  }

  Future<String?> purchaseMobile(String packageIdentifier) async {
    assert(!kIsWeb);
    try {
      await _ensureRcConfigured();
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return 'No offerings available.';

      final pkg = current.availablePackages
          .cast<Package?>()
          .firstWhere(
            (p) => p?.identifier == packageIdentifier,
            orElse: () => null,
          );
      if (pkg == null) return 'Package not found.';

      await Purchases.purchase(PurchaseParams.package(pkg));
      await _loadFromRevenueCat(
        Supabase.instance.client.auth.currentUser?.id ?? '',
      );
      return null;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return null;
      return e.message ?? e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> restore() async {
    assert(!kIsWeb);
    try {
      await _ensureRcConfigured();
      if (!_rcConfigured) return 'Purchases not available.';
      final info = await Purchases.restorePurchases();
      final ent = info.entitlements.active[_kEntitlement];
      _isPro = ent != null && ent.isActive;
      _currentPeriodEnd =
          ent != null ? DateTime.tryParse(ent.expirationDate ?? '') : null;
      notifyListeners();
      return _isPro ? null : 'No active subscription found.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Cancels an active trial immediately by setting trial_ends_at to now.
  Future<void> cancelTrial() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final response = await Supabase.instance.client.functions.invoke(
      'cancel-trial',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (response.status != 200) {
      throw Exception(response.data?['error'] ?? 'Failed to cancel trial');
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) await _loadFromSupabase(userId);
    notifyListeners();
  }

  void clear() {
    _isPro = false;
    _trialEndsAt = null;
    _currentPeriodEnd = null;
    _isLoading = false;
    notifyListeners();
  }
}
