import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../config/api_keys.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/subscription_provider.dart';
import '../../services/stripe_service.dart';

const _kMonthlyPackageId = r'$rc_monthly';
const _kAnnualPackageId = r'$rc_annual';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isAnnual = true;
  bool _loading = false;
  bool _restoring = false;

  Future<void> _subscribe({required bool isInTrial, required bool hadTrial}) async {
    final sub = context.read<SubscriptionProvider>();

    // Fresh account — start the 14-day free trial (no payment required)
    if (!hadTrial) {
      setState(() => _loading = true);
      await sub.startTrial();
      if (!mounted) return;
      setState(() => _loading = false);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your 14-day free trial is now active! Enjoy Pro.'),
          backgroundColor: AppTheme.accent,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // In trial or trial expired — trigger actual purchase
    setState(() => _loading = true);
    String? error;

    if (kIsWeb) {
      try {
        await StripeService.instance.launchCheckout(
          priceId: _isAnnual ? kStripePriceIdAnnual : kStripePriceIdMonthly,
        );
      } catch (e) {
        error = e.toString();
      }
    } else {
      error = await sub.purchaseMobile(
        _isAnnual ? _kAnnualPackageId : _kMonthlyPackageId,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.danger),
      );
      return;
    }

    if (sub.isPro) context.pop();
  }

  Future<void> _restore() async {
    if (kIsWeb) return;
    setState(() => _restoring = true);
    final error = await context.read<SubscriptionProvider>().restore();
    if (!mounted) return;
    setState(() => _restoring = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.danger),
      );
      return;
    }
    if (context.read<SubscriptionProvider>().isPro) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHero(l10n),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBillingToggle(l10n),
                  const SizedBox(height: 24),
                  _buildProFeatures(l10n),
                  const SizedBox(height: 20),
                  _buildComparison(l10n),
                  const SizedBox(height: 24),
                  _buildCTA(l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────────────

  Widget _buildHero(AppLocalizations l10n) {
    final sub = context.watch<SubscriptionProvider>();
    final isInTrial = sub.isInTrial;
    final trialEndsAt = sub.trialEndsAt;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1F35), Color(0xFF1B3D6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Glow orbs
          Positioned(
            top: -40, right: -40,
            child: _GlowCircle(size: 160, color: AppTheme.primaryLight),
          ),
          Positioned(
            bottom: -30, left: 20,
            child: _GlowCircle(size: 120, color: const Color(0xFFFFD700)),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button row
                  SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFFFD700),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.upgradeToPro,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Text(
                    isInTrial && trialEndsAt != null
                        ? 'Your trial ends ${trialEndsAt.month}/${trialEndsAt.day}/${trialEndsAt.year}. Upgrade now to keep Pro access.'
                        : 'Plan trips smarter with AI,\nunlimited events, and premium tools.',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  if (isInTrial && trialEndsAt != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 13, color: AppTheme.accent),
                          const SizedBox(width: 6),
                          Text(
                            'Trial active · Ends ${trialEndsAt.month}/${trialEndsAt.day}/${trialEndsAt.year}',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Billing toggle ────────────────────────────────────────────────────────────

  Widget _buildBillingToggle(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F7),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              alignment:
                  _isAnnual ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToggleOption(
                  label: l10n.proAnnualPrice,
                  badge: l10n.proAnnualSavings,
                  selected: _isAnnual,
                  onTap: () => setState(() => _isAnnual = true),
                ),
                _ToggleOption(
                  label: l10n.proMonthlyPrice,
                  selected: !_isAnnual,
                  onTap: () => setState(() => _isAnnual = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Pro features ──────────────────────────────────────────────────────────────

  Widget _buildProFeatures(AppLocalizations l10n) {
    final features = [
      (Icons.auto_awesome, const Color(0xFF8B5CF6), l10n.proFeatureAIPlanner),
      (Icons.all_inclusive, const Color(0xFF1A73E8), l10n.proFeatureUnlimitedEvents),
      (Icons.picture_as_pdf_outlined, const Color(0xFFFF6B35), l10n.proFeatureExpenseExport),
      (Icons.wifi_off_outlined, const Color(0xFF0EA5E9), l10n.proFeatureOfflineAccess),
      (Icons.style_outlined, const Color(0xFF0D9488), l10n.proFeatureTemplates),
    ];

    return Column(
      children: features.map((entry) {
        final (icon, color, label) = entry;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                Icon(Icons.check_circle_rounded, color: color, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Comparison table ──────────────────────────────────────────────────────────

  Widget _buildComparison(AppLocalizations l10n) {
    const proColor = Color(0xFF1D4ED8);
    const basicColor = Color(0xFFCBD5E1);

    final rows = [
      (l10n.freeEventsLimit,       '3',  '∞'),
      (l10n.freeGuestsLimit,       '10', '∞'),
      (l10n.freeBasicPlanning,     '✓',  '✓'),
      (l10n.proFeatureAIPlanner,   '—',  '✓'),
      (l10n.proFeatureExpenseExport, '—', '✓'),
      (l10n.proFeatureOfflineAccess, '—', '✓'),
      (l10n.proFeatureTemplates,   '—',  '✓'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.comparePlans.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Column headers
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    SizedBox(
                      width: 68,
                      child: Text(
                        l10n.tierFree,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.tierPro,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Feature rows
              ...rows.asMap().entries.map((entry) {
                final i = entry.key;
                final (feature, basic, pro) = entry.value;
                final isLast = i == rows.length - 1;
                final isProOnly = basic == '—';

                return Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isProOnly
                            ? const Color(0xFF1D4ED8).withValues(alpha: 0.03)
                            : null,
                        borderRadius: isLast
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(16))
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 13,
                                color: isProOnly
                                    ? const Color(0xFF1E293B)
                                    : Colors.grey[600],
                                fontWeight: isProOnly
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 68,
                            child: Center(
                              child: basic == '✓'
                                  ? Icon(Icons.check_rounded,
                                      color: basicColor, size: 18)
                                  : basic == '—'
                                      ? Icon(Icons.remove,
                                          color: Colors.grey[300], size: 18)
                                      : Text(basic,
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 68,
                            child: Center(
                              child: pro == '✓'
                                  ? const Icon(Icons.check_circle_rounded,
                                      color: proColor, size: 20)
                                  : ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        colors: [
                                          Color(0xFF1D4ED8),
                                          Color(0xFF7C3AED)
                                        ],
                                      ).createShader(bounds),
                                      child: Text(pro,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800)),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: Colors.grey[100]),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ── CTA ───────────────────────────────────────────────────────────────────────

  Widget _buildCTA(AppLocalizations l10n) {
    final sub = context.watch<SubscriptionProvider>();
    final isInTrial = sub.isInTrial;
    final hadTrial = sub.trialEndsAt != null;

    final String label;
    final String subtitle;

    if (!hadTrial) {
      label = 'Start Free Trial';
      subtitle = '14 days free, then ${_isAnnual ? l10n.proAnnualPrice : l10n.proMonthlyPrice}. No credit card required.';
    } else if (isInTrial) {
      label = l10n.upgradeNow;
      final end = sub.trialEndsAt!;
      subtitle = 'Billed after ${end.month}/${end.day}/${end.year} · Cancel anytime';
    } else {
      label = _isAnnual
          ? '${l10n.upgradeToPro} — ${l10n.proAnnualPrice}'
          : '${l10n.upgradeToPro} — ${l10n.proMonthlyPrice}';
      subtitle = 'Cancel anytime.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTappable(
          onTap: _loading ? null : () => _subscribe(isInTrial: isInTrial, hadTrial: hadTrial),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: 16),
          Center(
            child: AppTappable(
              onTap: _restoring ? null : _restore,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: _restoring
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        l10n.restorePurchases,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Glow circle ──────────────────────────────────────────────────────────────

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.09),
      ),
    );
  }
}

// ─── Billing toggle option ────────────────────────────────────────────────────

class _ToggleOption extends StatelessWidget {
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
                child: Text(label, textAlign: TextAlign.center),
              ),
              if (badge != null) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppTheme.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
