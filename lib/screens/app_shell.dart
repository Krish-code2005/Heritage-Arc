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
    fontSize: 24,
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

  // Purple Accent Theme
  static const Color _purpleAccent = Color(0xFF8E24AA);
  static const Color _lightPurpleAccent = Color(0xFFBA68C8);

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
        title: Text('New Lineage', style: _bodyStyle.copyWith(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Shrestha Family'),
          style: _bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
        const SnackBar(content: Text('Logged out successfully')),
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

  Widget _buildSidebarContent({required VoidCallback? onSelect}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Bangsha',
            style: _titleStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(color: Colors.grey.shade300),
        ),
        const SizedBox(height: 12),

        // Lineages List
        Expanded(
          child: _lineages.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No lineages yet. Tap + to create one.',
                    style: _bodyStyle.copyWith(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _lineages.length,
                  itemBuilder: (context, index) {
                    final lineage = _lineages[index];
                    final isSelected = lineage.id == _selectedLineageId;

                    return ListTile(
                      leading: Icon(
                        Icons.people,
                        color: isSelected ? _purpleAccent : Colors.grey.shade600,
                        size: 26,
                      ),
                      title: Text(
                        lineage.name,
                        style: _sidebarItemStyle.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? _purpleAccent : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: _lightPurpleAccent.withOpacity(0.12),
                      hoverColor: _lightPurpleAccent.withOpacity(0.09),
                      onTap: () {
                        setState(() {
                          _selectedLineageId = lineage.id;
                        });
                        onSelect?.call();
                      },
                    );
                  },
                ),
        ),

        // New Tree Button - Moved ABOVE the divider
        if (_isLoggedIn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: OutlinedButton.icon(
              onPressed: () {
                onSelect?.call();
                _addLineage();
              },
              icon: const Icon(Icons.add),
              label: Text('New Tree', style: _bodyStyle.copyWith(fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _purpleAccent,
                side: const BorderSide(color: _purpleAccent),
              ),
            ),
          ),

        const Divider(height: 1),

        // Login / Logout section
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: _isLoggedIn
                ? TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () {
                      onSelect?.call();
                      _handleLogout();
                    },
                    icon: const Icon(Icons.logout),
                    label: Text('Log Out', style: _bodyStyle.copyWith(fontSize: 15)),
                  )
                : ElevatedButton.icon(
                    onPressed: () {
                      onSelect?.call();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Login()),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: Text('Log In', style: _bodyStyle.copyWith(fontSize: 15)),
                  ),
          ),
        ),
      ],
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
            body: Row(
              children: [
                Container(
                  width: 240,
                  color: const Color(0xFFF5F5F7),
                  child: _buildSidebarContent(onSelect: null),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: mainContent),
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