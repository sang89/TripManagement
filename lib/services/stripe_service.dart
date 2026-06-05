import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_keys.dart';

// Web-only service. On iOS/Android, RevenueCat handles purchases.
// Call [launchCheckout] from the PaywallScreen when kIsWeb is true.
class StripeService {
  StripeService._();
  static final instance = StripeService._();

  static const _edgeFunctionUrl =
      '$kSupabaseUrl/functions/v1/stripe-create-checkout';

  // Launches Stripe Checkout in the current browser tab.
  // [priceId] is kStripePriceIdMonthly or kStripePriceIdAnnual.
  // [successPath] and [cancelPath] are app-relative paths (e.g. '/events').
  Future<void> launchCheckout({
    required String priceId,
    String successPath = '/events',
    String cancelPath = '/events',
  }) async {
    assert(kIsWeb, 'StripeService is web-only');

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw StateError('User is not authenticated');

    // Build absolute URLs from the current browser origin
    final origin = Uri.base.origin;
    final successUrl = '$origin$successPath?stripe_success=true';
    final cancelUrl = '$origin$cancelPath?stripe_canceled=true';

    final res = await http.post(
      Uri.parse(_edgeFunctionUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({
        'price_id': priceId,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
        'app': 'trip_management',
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Stripe checkout failed');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final url = Uri.parse(body['url'] as String);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
