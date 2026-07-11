// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:graphview/GraphView.dart';
import 'package:heritage_arc/models/person.dart';
import 'package:heritage_arc/ProfileEditScreen.dart';

class HomeScreen extends StatefulWidget {
 final String lineageId;
  const HomeScreen({super.key, required this.lineageId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;

  final Graph graph = Graph()..isTree = true;
  late BuchheimWalkerConfiguration builder;
  bool _hasAnyData = false;
  final TransformationController _viewController = TransformationController();

  final Map<String, Person> persons = {};
  late Future<void> _loadFuture;
  // Add near other state variables
  String? _deletingPersonId;


  @override
  void initState() {
    super.initState();

    builder = BuchheimWalkerConfiguration()
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM
      ..siblingSeparation = 140
      ..levelSeparation = 220
      ..subtreeSeparation = 160;

    _loadFuture = _loadGraph();
  }

  // ---------------------------------------------------------------------
  // DATA LOADING — two-pass compiler
  // ---------------------------------------------------------------------
  Future<void> _loadGraph() async {
   final response = await _supabase
    .from('profiles')
    .select()
    .eq('lineage_id', widget.lineageId);
    final rows = response as List<dynamic>;

    persons.clear();
    graph.nodes.clear();
    graph.edges.clear();

    // Pass 1 — instantiate nodes
    for (final row in rows) {
      final person = Person.fromMap(row as Map<String, dynamic>);
      persons[person.id] = person;
    }

    // Recompute parentCount — only using father
    for (final person in persons.values) {
      person.parentCount = (person.fatherId != null ? 1 : 0);
    }

    // Pass 2 — draw directional father -> child edges
    for (final person in persons.values) {
      final childNode = Node.Id(person.id);
      if (person.fatherId != null && persons.containsKey(person.fatherId)) {
        graph.addEdge(Node.Id(person.fatherId!), childNode);
      }
      // Root nodes
      if (person.fatherId == null && !_nodeExists(childNode)) {
        graph.addNode(childNode);
      }
    }
    _hasAnyData = persons.isNotEmpty;
  }

  bool _nodeExists(Node node) => graph.nodes.any((n) => n.key == node.key);

  Future<void> _refresh() async {
    setState(() {
      _loadFuture = _loadGraph();
    });
    await _loadFuture;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerGraph());
  }

  // Add this helper method in _HomeScreenState class
bool _hasChildren(String personId) {
  return persons.values.any((p) => p.fatherId == personId);
}

// Add this delete method in _HomeScreenState class
Future<void> _deletePerson(String personId) async {
  final person = persons[personId];
  if (person == null) return;

  if (_hasChildren(personId)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot delete: This person has children in the tree.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // Confirmation dialog
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Person'),
      content: Text('Delete ${person.fullName}? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  // Start loading
  setState(() => _deletingPersonId = personId);

  try {
    await _supabase.from('profiles').delete().eq('id', personId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Person deleted successfully')),
    );
    
    await _refresh();
  } catch (e) {
    _showError(e);
  } finally {
    // Always stop loading
    if (mounted) {
      setState(() => _deletingPersonId = null);
    }
  }
}

  void _centerGraph() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    _viewController.value = Matrix4.identity()
      ..translate(size.width * 0.35, size.height * 0.1);
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save: $e')),
    );
  }

  // ---------------------------------------------------------------------
  // DB-WRITE HOOKS
  // ---------------------------------------------------------------------
    Future<void> _openAddParentForm({
    required Person targetPerson,
  }) async {
    if (targetPerson.fatherId != null) {
      print('DEBUG: Person already has father.');
      return;
    }

    final result = await Navigator.push<Person>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(
          isParent: true,
          lineageId: widget.lineageId,
        ),
      ),
    );
    if (result == null) return;

    try {
      print('DEBUG: Inserting new parent...');

      final inserted = await _supabase
          .from('profiles')
          .insert(result.toMap()..remove('id'))
          .select()
          .single();

      final newParentId = inserted['id'] as String;
      print('DEBUG: New parent inserted with ID: $newParentId');

      // === FIXED UPDATE ===
      print('DEBUG: Updating child with ID: ${targetPerson.id}');

      final updateResult = await _supabase
          .from('profiles')
          .update({'father_id': newParentId})
          .eq('id', targetPerson.id.toString())   // ← Added .toString()
          .select();

      if (updateResult.isNotEmpty) {
        print('✅ SUCCESS: father_id updated!');
      } else {
        print('❌ STILL FAILED. targetPerson.id = ${targetPerson.id} (${targetPerson.id.runtimeType})');
      }
    } catch (e) {
      print('❌ ERROR: $e');
      _showError(e);
      return;
    }

    await _refresh();
  }

  Future<void> _openAddChildForm({
    required Person targetPerson,
  }) async {
    final result = await Navigator.push<Person>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(
          lineageId: widget.lineageId,
        ),
      ),
    );
    if (result == null) return;

    try {
      final map = result.toMap()..remove('id');
      map['father_id'] = targetPerson.id;
      await _supabase.from('profiles').insert(map);
    } catch (e) {
      _showError(e);
      return;
    }

    await _refresh();
  }

  Future<void> _editPerson(Node node) async {
    final id = node.key!.value as String;
    final person = persons[id];
    if (person == null) return;

    final result = await Navigator.push<Person>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(
          person: person,
          lineageId: widget.lineageId,
        ),
      ),
    );
    if (result == null) return;

    try {
      await _supabase
          .from('profiles')
          .update(result.toMap()..remove('id'))
          .eq('id', person.id);
    } catch (e) {
      _showError(e);
      return;
    }

    await _refresh();
  }

  Future<void> _addRootPerson() async {
    final result = await Navigator.push<Person>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(
          lineageId: widget.lineageId,
        ),
      ),
    );
    if (result == null) return;

    try {
      await _supabase.from('profiles').insert(result.toMap()..remove('id'));
    } catch (e) {
      _showError(e);
      return;
    }

    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Failed to load tree: ${snapshot.error}'));
            }
            if (persons.isEmpty) {
              return  Center(child: Column(
                children: [
                  Lottie.asset(
        'assets/bangsha.json',
        width: 400,                    // ← Adjust this
        height: 400,                   // ← Adjust this
        fit: BoxFit.contain,
        repeat: true,
        // Optional: Control alignment
        alignment: Alignment.center,
      ),
  
                  Text('No family members yet.'),
                ],
              ));
            }

            WidgetsBinding.instance.addPostFrameCallback((_) => _centerGraph());

            return InteractiveViewer(
              transformationController: _viewController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(800),
              minScale: 0.1,
              maxScale: 3.0,
              child: GraphView(
                graph: graph,
                algorithm: BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
                paint: Paint()
                  ..color = Colors.blueGrey[200]!
                  ..strokeWidth = 2.8
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  final id = node.key!.value as String;
                  final person = persons[id];
                  if (person == null) return const SizedBox.shrink();
                  return _buildProfileCard(person, node);
                },
              ),
            );
          },
        ),
      ),
     floatingActionButton: (!isLoggedIn || _hasAnyData)
    ? null // Hidden completely if logged out OR if data already exists
    : FloatingActionButton(
        onPressed: isLoggedIn ? _addRootPerson : null, // Extra security check
        child: const Icon(Icons.person_add),
      ),
    );
  }
Widget _buildProfileCard(Person person, Node node) {
  final bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;
  final bool showAddParent = person.fatherId == null && isLoggedIn;
  final bool canDelete = isLoggedIn && !_hasChildren(person.id);

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Upper Add Parent Button
      if (showAddParent)
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
          onPressed: isLoggedIn ? () => _openAddParentForm(targetPerson: person) : null,
        ),

      GestureDetector(
        onTap: () => _editPerson(node),
        child: Stack(
          children: [
            Container(
              width: 200,
              constraints: const BoxConstraints(minHeight: 180),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: person.photoUrl != null
                        ? NetworkImage(person.photoUrl!)
                        : null,
                    child: person.photoUrl == null
                        ? const Icon(Icons.person, color: Colors.white, size: 45)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    person.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (person.dob != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${person.dob}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (person.occupation != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      person.occupation!,
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (person.partnerName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '💍 ${person.partnerName!}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Delete Button (Top Right)
            if (canDelete)
              Positioned(
                top: 8,
                right: 8,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _deletePerson(person.id),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),

      // Lower Add Child Button
      if (isLoggedIn)
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
          onPressed: () => _openAddChildForm(targetPerson: person),
        ),
    ],
  );
}}