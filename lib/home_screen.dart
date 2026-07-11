// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:heritage_arc/models/partner.dart';
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
  bool _isLoading = true;   // ← Add this
  static const Color _purpleAccent = Color(0xFF3B7CFF);
  static const Color _lightPurpleAccent = Color(0xFF3B7CFF);


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
  setState(() => _isLoading = true);

  try {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('lineage_id', widget.lineageId);

    final rows = response as List<dynamic>;

    persons.clear();
    graph.nodes.clear();
    graph.edges.clear();

    for (final row in rows) {
      final person = Person.fromMap(row as Map<String, dynamic>);
      persons[person.id] = person;
    }

    for (final person in persons.values) {
      person.parentCount = (person.fatherId != null ? 1 : 0);
    }

    for (final person in persons.values) {
      final childNode = Node.Id(person.id);
      if (person.fatherId != null && persons.containsKey(person.fatherId)) {
        graph.addEdge(Node.Id(person.fatherId!), childNode);
      }
      if (person.fatherId == null && !_nodeExists(childNode)) {
        graph.addNode(childNode);
      }
    }

    setState(() {
      _hasAnyData = persons.isNotEmpty;
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    print('Error loading graph: $e');
  }
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

  // Must be logged in to delete
  final loggedIn = Supabase.instance.client.auth.currentSession != null;
  if (!loggedIn) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You must be logged in to delete a person.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

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

    // Best-effort cleanup of the person's photo in storage.
    // A failure here should not block the row delete from succeeding.
    await _deletePersonPhoto(person.photoUrl);

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

// Removes the corresponding object from Supabase Storage for a given
// public photo URL. Safe to call with null/empty/malformed URLs — it
// just no-ops in that case rather than throwing.
Future<void> _deletePersonPhoto(String? photoUrl) async {
  if (photoUrl == null || photoUrl.trim().isEmpty) return;

  try {
    final uri = Uri.parse(photoUrl);
    final segments = uri.pathSegments;

    // Supabase public storage URLs look like:
    // https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path/to/file.jpg>
    final publicIndex = segments.indexOf('public');
    if (publicIndex == -1 || publicIndex + 1 >= segments.length) {
      debugPrint('Could not parse storage bucket from photoUrl: $photoUrl');
      return;
    }

    final bucket = segments[publicIndex + 1];
    final objectPath = segments.sublist(publicIndex + 2).join('/');
    if (objectPath.isEmpty) return;

    await _supabase.storage.from(bucket).remove([objectPath]);
  } catch (e) {
    // Don't fail the whole delete flow just because photo cleanup failed.
    debugPrint('Failed to delete photo from storage: $e');
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
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
        'assets/bangsha.json',
        width: 600,                    // ← Adjust this
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
floatingActionButton: (Supabase.instance.client.auth.currentSession != null && !_hasAnyData)
    ? FloatingActionButton(

        onPressed: _addRootPerson,
        elevation: 0,
        backgroundColor: _purpleAccent,
        child: const Icon(Icons.person_add, color: Colors.white,),
      )
    : null,
    );
  }
Widget _buildProfileCard(Person person, Node node) {
  final bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;
  final bool showAddParent = person.fatherId == null && isLoggedIn;
  final bool canDelete = isLoggedIn && !_hasChildren(person.id);
  final bool isDeleting = _deletingPersonId == person.id;

  // Filter partners with valid names
  final Partner? partner1 = (person.partner1?.name?.trim().isNotEmpty ?? false) ? person.partner1 : null;
  final Partner? partner2 = (person.partner2?.name?.trim().isNotEmpty ?? false) ? person.partner2 : null;
  final bool hasPartners = partner1 != null || partner2 != null;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (showAddParent)
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
          onPressed: isLoggedIn ? () => _openAddParentForm(targetPerson: person) : null,
        ),

      Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => _editPerson(node),
            child: Container(
              width: hasPartners ? 480 : 220,
              constraints: const BoxConstraints(minHeight: 210),
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ==================== MAIN PERSON ====================
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: person.photoUrl != null ? NetworkImage(person.photoUrl!) : null,
                          child: person.photoUrl == null
                              ? const Icon(Icons.person, color: Colors.white, size: 48)
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          person.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                          textAlign: TextAlign.center,
                        ),
                        if (person.dob != null) ...[
                          const SizedBox(height: 4),
                          Text(person.dob!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                        if (person.occupation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            person.occupation!,
                            style: const TextStyle(fontSize: 13.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ==================== VERTICAL DIVIDER ====================
                  if (hasPartners)
                    Container(
                      height: 160,
                      width: 1.5,
                      color: Colors.grey[400],
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),

                  // ==================== PARTNERS ====================
                  if (hasPartners)
                    Expanded(
                      flex: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (partner1 != null) _buildPartnerMiniCard(partner1),
                          if (partner2 != null) _buildPartnerMiniCard(partner2),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ==================== DELETE BUTTON ====================
          // Only visible when the user is logged in AND this person has
          // no children pointing at them via father_id (canDelete).
          if (canDelete)
            Positioned(
              top: -6,
              right: -6,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: isDeleting ? null : () => _deletePerson(person.id),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: isDeleting
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
        ],
      ),

      // Lower Add Child Button
      if (isLoggedIn)
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
          onPressed: () => _openAddChildForm(targetPerson: person),
        ),
    ],
  );
}

// Partner Mini Card
Widget _buildPartnerMiniCard(Partner partner) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 42,
        backgroundColor: Colors.pink[50],
        backgroundImage: partner.photoUrl != null ? NetworkImage(partner.photoUrl!) : null,
        child: partner.photoUrl == null
            ? const Icon(Icons.person, color: Colors.pink, size: 32)
            : null,
      ),
     
      const SizedBox(height: 10),
      SizedBox(
        width: 115,
        child: Text(
          partner.name ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
       SizedBox(height: 10,),
      Text('Partner',style: const TextStyle(fontSize: 13.5, color: Colors.grey),),
      if (partner.occupation != null)
        SizedBox(
          width: 115,
          child: Text(
            partner.occupation!,
            style: const TextStyle(fontSize: 13.5, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
  );
}}