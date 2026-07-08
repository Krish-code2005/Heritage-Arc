// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:graphview/GraphView.dart';
import 'package:heritage_arc/person.dart';
import 'package:heritage_arc/ProfileEditScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final Graph graph = Graph()..isTree = true;
  late BuchheimWalkerConfiguration builder;
  bool _hasAnyData = false;
  final TransformationController _viewController = TransformationController();

  final Map<String, Person> persons = {};
  late Future<void> _loadFuture;

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
    final response = await _supabase.from('profiles').select();
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
      MaterialPageRoute(builder: (_) => const ProfileEditScreen(isParent: true)),
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
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
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
      MaterialPageRoute(builder: (_) => ProfileEditScreen(person: person)),
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
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
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
      appBar: AppBar(title: const Text('Family Tree')),
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
              return const Center(child: Text('No family members yet.'));
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
      floatingActionButton: _hasAnyData
          ? null
          : FloatingActionButton(
              onPressed: _addRootPerson,
              child: const Icon(Icons.person_add),
            ),
    );
  }

    Widget _buildProfileCard(Person person, Node node) {
    final bool canAddParent = person.fatherId == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upper Add Parent Button
        if (canAddParent)
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
            onPressed: () => _openAddParentForm(targetPerson: person),
          ),

        GestureDetector(
          onTap: () => _editPerson(node),
          child: SizedBox(
            width: 200,
            height: 190,   // Slightly increased to fit photo
            child: Container(
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
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Photo Display
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
                  if (person.dob != null)
                    Text(
                      '${person.dob}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  if (person.occupation != null)
                    Text(
                      person.occupation!,
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ),

        // Lower Add Child Button
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
          onPressed: () => _openAddChildForm(targetPerson: person),
        ),
      ],
    );
  }}