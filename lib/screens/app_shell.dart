// lib/app_shell.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heritage_arc/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:heritage_arc/models/lineage.dart';
import 'package:heritage_arc/home_screen.dart';
// TODO: Replace this import path with the actual location of your login screen widget


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

  @override
  void initState() {
    super.initState();
    _loadLineages();
    _isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      setState(() {
        _isLoggedIn = data.session != null;
      });
      // Refresh the lineage list if their login status changes (in case of RLS policies)
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
      // Catching potential RLS or connection errors gracefully
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
        title: const Text('New Lineage'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Shrestha Family'),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Heritage Arc',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _lineages.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No lineages yet. Tap + to create one.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _lineages.length,
                  itemBuilder: (context, index) {
                    final lineage = _lineages[index];
                    final isSelected = lineage.id == _selectedLineageId;
                    return ListTile(
                      title: Text(
                        lineage.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: Colors.blue.withOpacity(0.08),
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
        const Divider(height: 1),
        
        // Contextual action section at the bottom of the sidebar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Show 'New Tree' button only if logged in
              if (_isLoggedIn) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onSelect?.call();
                      _addLineage();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('New Tree'),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 2. Dynamic Login / Logout actions
              SizedBox(
                width: double.infinity,
                child: _isLoggedIn
                    ? TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () {
                          onSelect?.call();
                          _handleLogout();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out'),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          onSelect?.call();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              // Adjust this to your actual login widget class name
                              builder: (context) => const Login(), 
                            ),
                          );
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Log In'),
                      ),
              ),
            ],
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
            title: Text(_selectedLineageName),
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