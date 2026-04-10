import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/user_profile.dart';
import '../../design/colors.dart';
import '../../services/admin_service.dart';
import '../../services/user_service.dart';
import '../community/user_profile_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AdminPanelScreen — only reachable when AdminService.isCurrentUserAdmin
// ══════════════════════════════════════════════════════════════════════════════

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.primary.withAlpha(120)),
            ),
            child: const Text('ADMIN',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
          ),
          const SizedBox(width: 10),
          const Text('Control Panel',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Users'),
            Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'Admins'),
            Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _UsersTab(),
          _AdminsTab(),
          _StatsTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 1 — Users
// ══════════════════════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _searchCtrl = TextEditingController();
  List<UserProfile> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadRecent();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    setState(() { _loading = true; _searched = false; });
    final list = await AdminService().loadRecentUsers(limit: 40);
    if (mounted) setState(() { _results = list; _loading = false; });
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.isEmpty) { _loadRecent(); return; }
    setState(() { _loading = true; _searched = true; });
    List<UserProfile> res;
    final asInt = int.tryParse(q);
    if (asInt != null) {
      // Numeric ID search
      final p = await AdminService().searchByNumericId(asInt);
      res = p != null ? [p] : [];
    } else if (q.contains('@')) {
      // Email search
      final p = await AdminService().searchByEmail(q);
      res = p != null ? [p] : [];
    } else {
      // Name search
      res = await AdminService().searchUsers(q);
    }
    if (mounted) setState(() { _results = res; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when AdminService notifies (admin granted/revoked) so badges update
    return ListenableBuilder(
      listenable: AdminService(),
      builder: (context, _) {
        return Column(children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search by name, ID or email…',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    color: Colors.white38, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.white38, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadRecent();
                        })
                    : null,
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(children: [
              Text(
                _searched
                    ? '${_results.length} result(s)'
                    : 'Recent users (${_results.length})',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadRecent,
                icon: const Icon(Icons.refresh,
                    size: 14, color: Colors.white38),
                label: const Text('Refresh',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _results.isEmpty
                    ? const Center(
                        child: Text('No users found',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _results.length,
                        itemBuilder: (_, i) => _UserTile(
                          user: _results[i],
                          onRefresh: _loadRecent,
                        ),
                      ),
          ),
        ]);
      },
    );
  }
}

// ── User tile with action menu ────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onRefresh;
  const _UserTile({required this.user, required this.onRefresh});

  void _snack(BuildContext ctx, String msg, {bool error = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _confirmAction(
    BuildContext ctx,
    String title,
    String body,
    Future<void> Function() action,
  ) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        content: Text(body,
            style:
                const TextStyle(color: Colors.white60, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await action();
        if (ctx.mounted) {
          _snack(ctx, 'Done!');
          onRefresh(); // reload the list so badges/state update
        }
      } catch (e) {
        if (ctx.mounted) _snack(ctx, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = user.id == UserService().userId;
    final isPremium = user.isPremium;
    // Check both the profile field AND the live AdminService roster
    final isAdmin = user.isAdmin ||
        AdminService().adminUserIds.contains(user.id) ||
        (user.numericId != null && const {517913}.contains(user.numericId));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelf
              ? AppColors.primary.withAlpha(80)
              : Colors.white.withAlpha(15),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withAlpha(40),
          backgroundImage:
              user.imageUrl != null && user.imageUrl!.isNotEmpty
                  ? NetworkImage(user.imageUrl!)
                  : null,
          child: user.imageUrl == null || user.imageUrl!.isEmpty
              ? Text(
                  user.name.isNotEmpty
                      ? user.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700))
              : null,
        ),
        title: Row(children: [
          Flexible(
            child: Text(
              user.name.isNotEmpty ? user.name : '(no name)',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSelf) ...[
            const SizedBox(width: 6),
            _badge('YOU', AppColors.primary),
          ],
          if (isAdmin) ...[
            const SizedBox(width: 6),
            _badge('ADMIN', Colors.orange),
          ],
          if (isPremium) ...[
            const SizedBox(width: 6),
            _badge('PRO', Colors.amber),
          ],
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.numericId != null)
              Text('ID: ${user.numericId}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            if (user.email.isNotEmpty)
              Text(user.email,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: PopupMenuButton<String>(
          color: const Color(0xFF1E1E1E),
          icon:
              const Icon(Icons.more_vert, color: Colors.white54, size: 20),
          onSelected: (val) async {
            switch (val) {
              case 'view':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: user.id),
                  ),
                );
              case 'copy_id':
                await Clipboard.setData(ClipboardData(text: user.id));
                await HapticFeedback.lightImpact();
                if (context.mounted) _snack(context, 'Firebase UID copied');
              case 'copy_numeric_id':
                if (user.numericId != null) {
                  await Clipboard.setData(
                      ClipboardData(text: '${user.numericId}'));
                  await HapticFeedback.lightImpact();
                  if (context.mounted) _snack(context, 'Numeric ID copied');
                }
              case 'grant_premium':
                await _confirmAction(
                  context,
                  'Grant Premium',
                  'Give ${user.name.isNotEmpty ? user.name : 'this user'} '
                      'free premium access?',
                  () => AdminService().grantPremium(user.id),
                );
              case 'revoke_premium':
                await _confirmAction(
                  context,
                  'Revoke Premium',
                  'Remove premium from '
                      '${user.name.isNotEmpty ? user.name : 'this user'}?',
                  () => AdminService().revokePremium(user.id),
                );
              case 'grant_admin':
                await _confirmAction(
                  context,
                  'Grant Admin',
                  'Make ${user.name.isNotEmpty ? user.name : 'this user'} '
                      'an admin? They will see the Admin Panel.',
                  () => AdminService().grantAdmin(user.id),
                );
              case 'revoke_admin':
                await _confirmAction(
                  context,
                  'Revoke Admin',
                  'Remove admin access from '
                      '${user.name.isNotEmpty ? user.name : 'this user'}?',
                  () => AdminService().revokeAdmin(user.id),
                );
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'view',
              child: _MenuItem(
                  icon: Icons.person_outline, label: 'View Profile'),
            ),
            const PopupMenuItem(
              value: 'copy_id',
              child: _MenuItem(
                  icon: Icons.copy_outlined, label: 'Copy Firebase UID'),
            ),
            if (user.numericId != null)
              const PopupMenuItem(
                value: 'copy_numeric_id',
                child: _MenuItem(
                    icon: Icons.tag, label: 'Copy Numeric ID'),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: isPremium ? 'revoke_premium' : 'grant_premium',
              child: _MenuItem(
                icon: isPremium ? Icons.star_border : Icons.star_rounded,
                label: isPremium ? 'Revoke Premium' : 'Grant Premium ⚡',
                color: Colors.amber,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: isAdmin ? 'revoke_admin' : 'grant_admin',
              child: _MenuItem(
                icon: isAdmin
                    ? Icons.shield_outlined
                    : Icons.shield_rounded,
                label: isAdmin ? 'Revoke Admin' : 'Grant Admin',
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 2 — Admins list
// ══════════════════════════════════════════════════════════════════════════════

class _AdminsTab extends StatefulWidget {
  const _AdminsTab();

  @override
  State<_AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<_AdminsTab> {
  final _addCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _addAdmin() async {
    final uid = _addCtrl.text.trim();
    if (uid.isEmpty) return;
    setState(() => _adding = true);
    try {
      await AdminService().grantAdmin(uid);
      _addCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Admin granted to $uid'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdminService(),
      builder: (context, _) {
        final adminIds = AdminService().adminUserIds.toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // ── Add admin by UID ─────────────────────────────────────
            const Text('ADD ADMIN BY FIREBASE UID',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _addCtrl,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Firebase UID',
                    hintStyle: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _adding ? null : _addAdmin,
                child: _adding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Add',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Superadmin (hardcoded) ────────────────────────────────
            const Text('SUPERADMIN',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            _AdminIdTile(
              label: 'Numeric ID 517913',
              sublabel: 'Hardcoded — cannot be revoked',
              canRevoke: false,
            ),
            const SizedBox(height: 20),

            // ── Firestore admins ──────────────────────────────────────
            Text('ADMINS (${adminIds.length})',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            if (adminIds.isEmpty)
              const Text('No admins added yet.',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 13))
            else
              ...adminIds.map((uid) => _AdminIdTile(
                    label: uid,
                    sublabel:
                        uid == UserService().userId ? 'You' : null,
                    canRevoke: uid != UserService().userId,
                    onRevoke: () async {
                      try {
                        await AdminService().revokeAdmin(uid);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    },
                  )),
          ],
        );
      },
    );
  }
}

class _AdminIdTile extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool canRevoke;
  final VoidCallback? onRevoke;

  const _AdminIdTile({
    required this.label,
    this.sublabel,
    required this.canRevoke,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withAlpha(60)),
      ),
      child: Row(children: [
        const Icon(Icons.shield_rounded, color: Colors.orange, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              if (sublabel != null)
                Text(sublabel!,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        if (canRevoke && onRevoke != null)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: Colors.red, size: 20),
            onPressed: onRevoke,
            tooltip: 'Revoke admin',
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 3 — Quick stats
// ══════════════════════════════════════════════════════════════════════════════

class _StatsTab extends StatefulWidget {
  const _StatsTab();

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  int _totalUsers = 0;
  int _premiumUsers = 0;
  int _adminCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await AdminService().loadRecentUsers(limit: 200);
      final adminCount =
          AdminService().adminUserIds.length + 1; // +1 superadmin
      if (mounted) {
        setState(() {
          _totalUsers = users.length;
          _premiumUsers = users.where((u) => u.isPremium).length;
          _adminCount = adminCount;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    final myProfile = UserService().profile;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('APP OVERVIEW',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard('Users (recent)', '$_totalUsers',
              Icons.people_outline, Colors.blue)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard('Premium', '$_premiumUsers',
              Icons.star_rounded, Colors.amber)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard('Admins', '$_adminCount',
              Icons.shield_rounded, Colors.orange)),
          const SizedBox(width: 12),
          const Expanded(child: SizedBox()),
        ]),
        const SizedBox(height: 24),
        const Text('YOUR ACCOUNT',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withAlpha(60)),
          ),
          child: Column(children: [
            _infoRow('Name',
                myProfile?.name.isNotEmpty == true
                    ? myProfile!.name
                    : '—'),
            _infoRow('Numeric ID',
                myProfile?.numericId?.toString() ?? '—'),
            _infoRow('Firebase UID', UserService().userId ?? '—'),
            _infoRow('Premium',
                myProfile?.isPremium == true ? 'Yes ⭐' : 'No'),
            _infoRow('Full Access',
                UserService().hasFullAccess ? 'Yes ✅' : 'No ❌'),
            _infoRow('Admin',
                AdminService().isCurrentUserAdmin ? 'Yes 🛡️' : 'No'),
          ]),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, color: AppColors.primary,
              size: 16),
          label: const Text('Refresh Stats',
              style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end),
          ),
        ]),
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ]),
      );
}
