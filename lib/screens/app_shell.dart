// lib/app_shell.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heritage_arc/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:heritage_arc/models/lineage.dart';
import 'package:heritage_arc/home_screen.dart';

const double _kWideBreakpoint = 800;

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _supabase = Supabase.instance.client;
  bool _isLoggedIn = false;
  late final StreamSubscription<AuthState> _authSubscription;

  List<Lineage> _lineages = [];
  String? _selectedLineageId;
  bool _isLoading = true;

  // ==================== UNIVERSAL TEXT STYLES ====================
  static final TextStyle _titleStyle = GoogleFonts.limelight(
    fontWeight: FontWeight.bold,
    fontSize: 22,
  );

  static final TextStyle _bodyStyle = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  static final TextStyle _sidebarItemStyle = GoogleFonts.poppins(
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  // Accent Theme (matched to reference UI)
  static const Color _purpleAccent = Color(0xFF3B7CFF);
  static const Color _lightPurpleAccent = Color(0xFF3B7CFF);
  static const Color _sidebarBg = Color(0xFFF7F8FC);
  static const Color _mutedText = Color(0xFF8A8FA3);

  @override
  void initState() {
    super.initState();
    _loadLineages();
    _isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      setState(() {
        _isLoggedIn = data.session != null;
      });
      _loadLineages();
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadLineages() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('lineages').select().order('name');
      final lineages = (data as List)
          .map((row) => Lineage.fromMap(row as Map<String, dynamic>))
          .toList();

      setState(() {
        _lineages = lineages;
        if (_selectedLineageId == null ||
            !lineages.any((l) => l.id == _selectedLineageId)) {
          _selectedLineageId = lineages.isNotEmpty ? lineages.first.id : null;
        }
      });
    } catch (e) {
      debugPrint('Error loading lineages: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addLineage() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        title: Text('New Lineage', style: _bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: _bodyStyle,
          decoration: InputDecoration(
            hintText: 'e.g. Shrestha Family',
            hintStyle: _sidebarItemStyle.copyWith(color: _mutedText),
            filled: true,
            fillColor: _sidebarBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _purpleAccent, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _mutedText),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purpleAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final inserted = await _supabase
          .from('lineages')
          .insert({'name': name})
          .select()
          .single();

      await _loadLineages();
      setState(() {
        _selectedLineageId = inserted['id'] as String;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create lineage: $e')),
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully'),
        backgroundColor: Colors.redAccent,),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  String get _selectedLineageName {
    if (_selectedLineageId == null) return 'Heritage Arc';
    final match = _lineages.where((l) => l.id == _selectedLineageId);
    return match.isEmpty ? 'Heritage Arc' : match.first.name;
  }

  String get _currentUserDisplayName {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'Account';

    final metadata = user.userMetadata;
    final username = metadata?['username'] as String?;
    if (username != null && username.trim().isNotEmpty) return username;

    final fullName = metadata?['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) return fullName;

    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;

    return 'Account';
  }

  Widget _buildSidebarContent({required VoidCallback? onSelect}) {
    return Container(
      color: _sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- Logo / Title ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _purpleAccent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Bangsha', style: _titleStyle.copyWith(color: Colors.black87, fontSize: 20)),
              ],
            ),
          ),

          // ---------- Search bar (visual) ----------
        

          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Colors.grey.shade200, height: 1),
          ),
          const SizedBox(height: 12),

          // ---------- Lineages List ----------
          Expanded(
            child: _lineages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No lineages yet. Tap + to create one.',
                      style: _bodyStyle.copyWith(color: _mutedText, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _lineages.length,
                    itemBuilder: (context, index) {
                      final lineage = _lineages[index];
                      final isSelected = lineage.id == _selectedLineageId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: isSelected ? _purpleAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _selectedLineageId = lineage.id;
                              });
                              onSelect?.call();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    color: isSelected ? Colors.white : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      lineage.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: _sidebarItemStyle.copyWith(
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ---------- New Tree Button ----------
          if (_isLoggedIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    onSelect?.call();
                    _addLineage();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _purpleAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, color: _purpleAccent, size: 18),
                        const SizedBox(width: 6),
                        Text('New Tree', style: _sidebarItemStyle.copyWith(color: _purpleAccent)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          Divider(color: Colors.grey.shade200, height: 1),

          // ---------- Login / Logout / Profile section ----------
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoggedIn
                ? Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _purpleAccent.withOpacity(0.15),
                        child: Icon(Icons.person, color: _purpleAccent, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUserDisplayName,
                              overflow: TextOverflow.ellipsis,
                              style: _sidebarItemStyle.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: () {
                                onSelect?.call();
                                _handleLogout();
                              },
                              child: Text(
                                'Log Out',
                                style: _sidebarItemStyle.copyWith(fontSize: 13, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        onSelect?.call();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Login()),
                        );
                      },
                      icon: const Icon(Icons.login, size: 18),
                      label: Text('Log In', style: _bodyStyle.copyWith(fontSize: 15, color: Colors.white)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kWideBreakpoint;

        final mainContent = _selectedLineageId == null
            ? const Center(child: Text('No lineage selected'))
            : HomeScreen(
                key: ValueKey(_selectedLineageId),
                lineageId: _selectedLineageId!,
              );

        if (isWide) {
          return Scaffold(
            backgroundColor: _sidebarBg,
            body: Row(
              children: [
                Container(
                  width: 260,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildSidebarContent(onSelect: null),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: mainContent,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _selectedLineageName,
              style: _bodyStyle.copyWith(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
          ),
          drawer: Drawer(
            child: SafeArea(
              child: _buildSidebarContent(
                onSelect: () => Navigator.pop(context),
              ),
            ),
          ),
          body: mainContent,
        );
      },
    );
  }
}