import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/notifications_provider.dart';
import '../../responsive/breakpoints.dart';

// ─── Animated emoji icon ─────────────────────────────────────────────────────

class _AnimatedEmojiIcon extends StatefulWidget {
  final String emoji;
  final Color color;
  final bool isUnread;

  const _AnimatedEmojiIcon({
    required this.emoji,
    required this.color,
    required this.isUnread,
  });

  @override
  State<_AnimatedEmojiIcon> createState() => _AnimatedEmojiIconState();
}

class _AnimatedEmojiIconState extends State<_AnimatedEmojiIcon>
    with TickerProviderStateMixin {
  AnimationController? _bounceCtrl;
  AnimationController? _pulseCtrl;
  Animation<double>? _bounceAnim;
  Animation<double>? _pulseAnim;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bounceAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceCtrl!, curve: Curves.elasticOut),
    );
    _bounceCtrl!.forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut),
    );
    if (widget.isUnread) _pulseCtrl!.repeat(reverse: true);
  }

  @override
  void reassemble() {
    // Called only on hot reload — re-trigger the bounce so devs can see it.
    super.reassemble();
    _bounceCtrl?.reset();
    _bounceCtrl?.forward();
  }

  @override
  void didUpdateWidget(_AnimatedEmojiIcon old) {
    super.didUpdateWidget(old);
    final pulse = _pulseCtrl;
    if (pulse == null) return;
    if (widget.isUnread && !pulse.isAnimating) {
      pulse.repeat(reverse: true);
    } else if (!widget.isUnread && pulse.isAnimating) {
      pulse.stop();
      pulse.animateTo(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _bounceCtrl?.dispose();
    _pulseCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounce = _bounceCtrl;
    final pulse = _pulseCtrl;
    if (bounce == null || pulse == null) {
      // Rendered before initState completes — show static icon
      return _staticCircle;
    }
    return AnimatedBuilder(
      animation: Listenable.merge([bounce, pulse]),
      builder: (_, child) => Transform.scale(
        scale: (_bounceAnim?.value ?? 1.0) * (_pulseAnim?.value ?? 1.0),
        child: child,
      ),
      child: _staticCircle,
    );
  }

  Widget get _staticCircle => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(widget.emoji, style: const TextStyle(fontSize: 20)),
      );
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Always reload on open — real-time is a best-effort bonus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsProvider>().reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          Consumer<NotificationsProvider>(
            builder: (_, notifs, _) {
              if (notifs.unreadCount == 0) return const SizedBox.shrink();
              return Tooltip(
                message: l10n.notificationsMarkAllRead,
                child: IconButton(
                  icon: const Icon(Icons.done_all_rounded),
                  onPressed: notifs.markAllRead,
                ),
              );
            },
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop(context) ? 800 : double.infinity,
          ),
          child: Consumer<NotificationsProvider>(
            builder: (_, notifs, _) {
              if (notifs.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (notifs.notifications.isEmpty) {
                return _EmptyState(label: l10n.notificationsEmpty);
              }
              return RefreshIndicator(
                onRefresh: notifs.reload,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: notifs.notifications.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, i) {
                    final n = notifs.notifications[i];
                    return _NotificationTile(
                      notification: n,
                      onTap: () async {
                        await notifs.markRead(n.id);
                        final route = n.targetRoute;
                        if (!context.mounted) return;
                        // NotificationsScreen is on the root navigator — capture
                        // the GoRouter reference before popping, then navigate.
                        final router = GoRouter.of(context);
                        Navigator.of(context, rootNavigator: true).pop();
                        router.go(route);
                      },
                      onDismiss: () => notifs.deleteNotification(n.id),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red.shade400,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss(),
      child: AppTappable(
        onTap: onTap,
        child: Container(
          color: n.isRead ? null : n.iconColor.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnimatedEmojiIcon(
                emoji: n.iconEmoji,
                color: n.iconColor,
                isUnread: !n.isRead,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(n.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        n.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              if (!n.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: n.iconColor,
                    shape: BoxShape.circle,
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

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
