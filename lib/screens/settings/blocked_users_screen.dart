import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/blocked_users_provider.dart';
import '../../widgets/supabase_image.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BlockedUsersProvider>().load();
    });
  }

  Future<void> _unblock(String userId, String name) async {
    final l10n = AppLocalizations.of(context);
    final provider = context.read<BlockedUsersProvider>();
    try {
      await provider.unblockUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.unblockSuccess(name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<BlockedUsersProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: Text(l10n.blockedUsersTitle)),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : provider.blocked.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.blockedUsersEmpty,
                        style:
                            TextStyle(fontSize: 15, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  itemCount: provider.blocked.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final b = provider.blocked[i];
                    final url = b.avatarUrl.isNotEmpty ? b.avatarUrl : null;
                    final initials = b.fullName.isNotEmpty
                        ? b.fullName[0].toUpperCase()
                        : '?';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: SupabaseAvatar(
                        url: url,
                        radius: 22,
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.12),
                        fallback: Text(initials,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary)),
                      ),
                      title: Text(
                        b.fullName.isNotEmpty ? b.fullName : b.userId,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: TextButton(
                        onPressed: () => _unblock(b.userId, b.fullName),
                        child: Text(l10n.unblockUser,
                            style:
                                const TextStyle(color: AppTheme.primary)),
                      ),
                    );
                  },
                ),
    );
  }
}
