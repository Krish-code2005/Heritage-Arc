import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:heritage_arc/models/person.dart';
import 'package:heritage_arc/models/partner.dart';
import 'package:flutter/services.dart';

// Palette
const _kAccentStart = Color.fromARGB(255, 98, 151, 255);
const _kAccentEnd = Color.fromARGB(255, 148, 187, 255);
const _kFieldFill = Color(0xFFF5F5F7);
const _kLabelColor = Color(0xFF111111);
const _kHintColor = Color(0xFF9B9B9B);

class ProfileEditScreen extends StatefulWidget {
  final Person? person;
  final bool isParent;
  final String lineageId;

  const ProfileEditScreen({
    super.key,
    this.person,
    this.isParent = false,
    required this.lineageId,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  // Person controllers
  late TextEditingController _firstCtrl;
  late TextEditingController _middleCtrl;
  late TextEditingController _lastCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _dodCtrl;
  late TextEditingController _occCtrl;
  late TextEditingController _eduCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _fbCtrl;
  late TextEditingController _instaCtrl;

  // Parents
  late TextEditingController _fatherNameCtrl;
  late TextEditingController _motherNameCtrl;

  // Partners
  final List<PartnerData> _partners = [];

  Uint8List? _selectedImageBytes; // Main person photo
  String? _existingPhotoUrl;

  bool _isSaving = false;
  bool _isAuthenticated = false;
 

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _initializeControllers();
  }

  void _initializeControllers() {
  final p = widget.person;

  _firstCtrl = TextEditingController(text: p?.firstName ?? '');
  _middleCtrl = TextEditingController(text: p?.middleName ?? '');
  _lastCtrl = TextEditingController(text: p?.lastName ?? '');
  _dobCtrl = TextEditingController(text: p?.dob ?? '');
  _dodCtrl = TextEditingController(text: p?.dod ?? '');
  _occCtrl = TextEditingController(text: p?.occupation ?? '');
  _eduCtrl = TextEditingController(text: p?.education ?? '');
  _descCtrl = TextEditingController(text: p?.description ?? '');
  _addrCtrl = TextEditingController(text: p?.address ?? '');
  _phoneCtrl = TextEditingController(text: p?.phone ?? '');
  _emailCtrl = TextEditingController(text: p?.email ?? '');
  _fbCtrl = TextEditingController(text: p?.facebook ?? '');
  _instaCtrl = TextEditingController(text: p?.instagram ?? '');

  // FIXED: Properly initialize father & mother names
  _fatherNameCtrl = TextEditingController(text: p?.fatherName ?? p?.fatherFullName ?? '');
  _motherNameCtrl = TextEditingController(text: p?.motherName ?? p?.motherFullName ?? '');

  _existingPhotoUrl = p?.photoUrl;

  // Partners...
  _partners.clear();
  if (p?.partner1 != null) _partners.add(PartnerData.fromPartner(p!.partner1!));
  if (p?.partner2 != null) _partners.add(PartnerData.fromPartner(p!.partner2!));
  while (_partners.length < 2) _partners.add(PartnerData());
}

  @override
  void dispose() {
    for (var ctrl in [_firstCtrl, _middleCtrl, _lastCtrl, _dobCtrl, _dodCtrl, _occCtrl, _eduCtrl, _descCtrl, _addrCtrl, _phoneCtrl, _emailCtrl, _fbCtrl, _instaCtrl, _fatherNameCtrl, _motherNameCtrl]) {
      ctrl.dispose();
    }
    for (var partner in _partners) {
      partner.dispose();
    }
    super.dispose();
  }

  void _checkAuthStatus() {
    final session = _supabase.auth.currentSession;
    setState(() => _isAuthenticated = session != null);

    _supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() => _isAuthenticated = data.session != null);
    });
  }

  // ==================== IMAGE PICKING ====================
  Future<void> _pickMainImage() async {
    if (!_isAuthenticated) return _showLoginRequired();
    final bytes = await _pickImageBytes();
    if (bytes != null) {
      setState(() => _selectedImageBytes = bytes);
    }
  }

  Future<void> _pickPartnerImage(int index) async {
    if (!_isAuthenticated) return _showLoginRequired();
    final bytes = await _pickImageBytes();
    if (bytes != null) {
      setState(() {
        _partners[index].selectedBytes = bytes;
      });
    }
  }

  Future<Uint8List?> _pickImageBytes() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      return image != null ? await image.readAsBytes() : null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
      return null;
    }
  }

Future<String?> _uploadImage(Uint8List bytes, String folder) async {
  try {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 800,
      quality: 85,
      format: CompressFormat.webp,
    );

    if (compressed.isEmpty) return null;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.webp';
    final path = '$folder/$fileName';

    await _supabase.storage.from('profiles').uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/webp',
            upsert: true,
          ),
        );

    return _supabase.storage.from('profiles').getPublicUrl(path);
  } catch (e) {
    debugPrint('❌ Upload Error: $e');
    return null;
  }
}

  // ==================== SAVE ====================
  Future<void> _save() async {
    if (!_isAuthenticated) {
      _showLoginRequired();
      return;
    }
    if (_isSaving) return;

    if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First and Last name are required')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload main photo
      String? photoUrl = _existingPhotoUrl;
      if (_selectedImageBytes != null) {
        photoUrl = await _uploadImage(_selectedImageBytes!, 'profile_photos');
      }

      // Upload partner photos and build partners
      final partner1 = await _partners[0].toPartnerWithUpload(_uploadImage);
      final partner2 = await _partners[1].toPartnerWithUpload(_uploadImage);
final person = Person(
  id: widget.person?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
  firstName: _firstCtrl.text.trim(),
  middleName: _middleCtrl.text.trim().isEmpty ? null : _middleCtrl.text.trim(),
  lastName: _lastCtrl.text.trim(),
  dob: _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
  dod: _dodCtrl.text.trim().isEmpty ? null : _dodCtrl.text.trim(),
  occupation: _occCtrl.text.trim().isEmpty ? null : _occCtrl.text.trim(),
  education: _eduCtrl.text.trim().isEmpty ? null : _eduCtrl.text.trim(),
  description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
  address: _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
  phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
  email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
  facebook: _fbCtrl.text.trim().isEmpty ? null : _fbCtrl.text.trim(),
  instagram: _instaCtrl.text.trim().isEmpty ? null : _instaCtrl.text.trim(),
  photoUrl: photoUrl,
  fatherId: widget.person?.fatherId,
  lineageId: widget.person?.lineageId ?? widget.lineageId,
  
  // FIXED: Explicitly pass fatherName and motherName
  fatherName: _fatherNameCtrl.text.trim().isEmpty ? null : _fatherNameCtrl.text.trim(),
  motherName: _motherNameCtrl.text.trim().isEmpty ? null : _motherNameCtrl.text.trim(),
  
  partner1: partner1,
  partner2: partner2,
  parentCount: widget.person?.parentCount ?? 0,
);
      if (mounted) Navigator.pop(context, person);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in to edit or add profiles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.person == null;
    final canEdit = _isAuthenticated;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kAccentStart, _kAccentEnd],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 12)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isNew ? 'Add New Person' : 'Edit Profile',
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kLabelColor),
                                ),
                              ),
                              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: _kHintColor)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isNew ? 'Fill in their details to add them to the tree.' : 'Update their details below.',
                            style: const TextStyle(fontSize: 14, color: _kHintColor),
                          ),

                          if (!canEdit) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
                              child: const Row(
                                children: [Icon(Icons.lock, color: Colors.amber), SizedBox(width: 8), Expanded(child: Text('Login required to edit profiles', style: TextStyle(fontWeight: FontWeight.w600)))],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Main Photo
                          Center(
                            child: GestureDetector(
                              onTap: canEdit ? _pickMainImage : null,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 56,
                                    backgroundColor: _kFieldFill,
                                    backgroundImage: _selectedImageBytes != null
                                        ? MemoryImage(_selectedImageBytes!)
                                        : (_existingPhotoUrl != null ? NetworkImage(_existingPhotoUrl!) : null),
                                    child: (_selectedImageBytes == null && _existingPhotoUrl == null) ? const Icon(Icons.person, size: 56, color: _kHintColor) : null,
                                  ),
                                  if (canEdit)
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kAccentStart, _kAccentEnd]), shape: BoxShape.circle),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(child: Text(canEdit ? 'Tap to change photo' : 'Photo', style: TextStyle(color: _kHintColor, fontSize: 13))),

                          const SizedBox(height: 28),

                          _sectionLabel('Basic Information'),
                           const SizedBox(height: 24),
                          _fieldGrid([_field('First name', _firstCtrl, hint: 'Roman', readOnly: !canEdit),   
          
                            _field('Middle name', _middleCtrl, hint: 'Optional', readOnly: !canEdit)]),
        
                          _fieldGrid([_field('Last name', _lastCtrl, hint: 'Bajracharya', readOnly: !canEdit)]),
                           _fieldGrid([
                            _field('Date of birth', _dobCtrl, hint: 'YYYY-MM-DD', readOnly: !canEdit, inputFormatters: [_DateInputFormatter()]),
                            _field('Date of death', _dodCtrl, hint: 'YYYY-MM-DD', readOnly: !canEdit, inputFormatters: [_DateInputFormatter()]),
                          ]),

                          const SizedBox(height: 24),
                          _sectionLabel('Parents'),
                           const SizedBox(height: 24),
                          _fieldGrid([_field('Father Name', _fatherNameCtrl, hint: 'Full name', readOnly: !canEdit), _field('Mother Name', _motherNameCtrl, hint: 'Full name', readOnly: !canEdit)]),

                                                 const SizedBox(height: 24),
                          _sectionLabel('Partners (Maximum 2)'),
                          const SizedBox(height: 8),

                          ...List.generate(2, (index) {
                            final partner = _partners[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey[200]!, width: 1.5),
                                boxShadow: [
                                
                                ],
                              ),
                              child: ExpansionTile(
                              
                                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text(
                                  'Partner ${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _kLabelColor,
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                                    child: Column(
                                      children: [
                                        // Partner Photo - Same as Main Photo
                                        Center(
                                          child: GestureDetector(
                                            onTap: canEdit ? () => _pickPartnerImage(index) : null,
                                            child: Stack(
                                              alignment: Alignment.bottomRight,
                                              children: [
                                                CircleAvatar(
                                                  radius: 52,
                                                  backgroundColor: _kFieldFill,
                                                  backgroundImage: partner.selectedBytes != null
                                                      ? MemoryImage(partner.selectedBytes!)
                                                      : (partner.existingUrl != null
                                                          ? NetworkImage(partner.existingUrl!)
                                                          : null),
                                                  child: (partner.selectedBytes == null && partner.existingUrl == null)
                                                      ? const Icon(Icons.person, size: 52, color: _kHintColor)
                                                      : null,
                                                ),
                                                if (canEdit)
                                                  Container(
                                                    padding: const EdgeInsets.all(7),
                                                    decoration: const BoxDecoration(
                                                      gradient: LinearGradient(colors: [_kAccentStart, _kAccentEnd]),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Center(
                                          child: Text(
                                            canEdit ? 'Tap to change photo' : 'Partner Photo',
                                            style: TextStyle(color: _kHintColor, fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(height: 28),

                                        // Fields - Same style as rest of form
                                        _fieldGrid([
                                          _field('Full Name', partner.nameCtrl, hint: 'Enter full name', readOnly: !canEdit),
                                        ]),
                                        _fieldGrid([
                                          _field('Date of Birth', partner.dobCtrl, hint: 'YYYY-MM-DD', readOnly: !canEdit, inputFormatters: [_DateInputFormatter()]),
                                          _field('Date of Death', partner.dodCtrl, hint: 'YYYY-MM-DD', readOnly: !canEdit, inputFormatters: [_DateInputFormatter()]),
                                        ]),
                                        _fieldGrid([
                                          _field('Occupation', partner.occCtrl, hint: 'e.g. Engineer', readOnly: !canEdit),
                                          _field('Education', partner.eduCtrl, hint: 'e.g. Bachelor Degree', readOnly: !canEdit),
                                        ]),
                                        const SizedBox(height: 16),
                                        _labeled(
                                          'Description',
                                          TextField(
                                            controller: partner.descCtrl,
                                            maxLines: 3,
                                            readOnly: !canEdit,
                                            decoration: _decoration('Brief information about this partner'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 24),
                          _sectionLabel('Additional Information'),
                           const SizedBox(height: 24),
                          _fieldGrid([_field('Occupation', _occCtrl, readOnly: !canEdit), _field('Education', _eduCtrl, readOnly: !canEdit)]),
                          _field('Address', _addrCtrl, fullWidth: true, readOnly: !canEdit),
                          const SizedBox(height: 14),
                          _labeled('Bio / Description', TextField(controller: _descCtrl, maxLines: 3, readOnly: !canEdit, decoration: _decoration('Tell us briefly about them'))),

                          const SizedBox(height: 24),
                          _sectionLabel('Contact & Social'),
                           const SizedBox(height: 24),
                          _fieldGrid([_field('Phone', _phoneCtrl, readOnly: !canEdit), _field('Email', _emailCtrl, readOnly: !canEdit)]),
                          _fieldGrid([_field('Facebook', _fbCtrl, readOnly: !canEdit), _field('Instagram', _instaCtrl, readOnly: !canEdit)]),

                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: canEdit && !_isSaving ? _save : null,
                              style: ElevatedButton.styleFrom(backgroundColor: _kAccentStart, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                              child: _isSaving
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                                  : Text(canEdit ? 'Save' : 'Login to Save', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_isSaving)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== UI HELPERS ====================
  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kLabelColor));

  Widget _fieldGrid(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14,),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 420) {
            return Column(children: children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)).toList());
          }
          return Row(children: children.map((w) => Expanded(child: w)).toList());
        },
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {String? hint, bool fullWidth = false, List<TextInputFormatter>? inputFormatters, bool readOnly = false}) {
    final field = _labeled(
      label,
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: controller,
          decoration: _decoration(hint),
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          enabled: !readOnly,
        ),
      ),
    );
    return fullWidth ? Padding(padding: const EdgeInsets.only(bottom: 14), child: field) : field;
  }

  Widget _labeled(String label, Widget input) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kLabelColor)), const SizedBox(height: 6), input],
    );
  }

  InputDecoration _decoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHintColor, fontSize: 14),
      filled: true,
      fillColor: _kFieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kAccentStart, width: 1.6)),
    );
  }
}

// ==================== PARTNER DATA CLASS ====================
class PartnerData {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController dobCtrl = TextEditingController();
  final TextEditingController dodCtrl = TextEditingController();
  final TextEditingController occCtrl = TextEditingController();
  final TextEditingController eduCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();

  Uint8List? selectedBytes;
  String? existingUrl;

  PartnerData();

  factory PartnerData.fromPartner(Partner p) {
    final data = PartnerData();
    data.nameCtrl.text = p.name ?? '';
    data.dobCtrl.text = p.dob ?? '';
    data.dodCtrl.text = p.dod ?? '';
    data.occCtrl.text = p.occupation ?? '';
    data.eduCtrl.text = p.education ?? '';
    data.descCtrl.text = p.description ?? '';
    data.existingUrl = p.photoUrl;
    return data;
  }

  Future<Partner> toPartnerWithUpload(Future<String?> Function(Uint8List, String) uploadFn) async {
    String? photoUrl = existingUrl;
    if (selectedBytes != null) {
      photoUrl = await uploadFn(selectedBytes!, 'partner_photos');
    }

    return Partner(
      name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
      dob: dobCtrl.text.trim().isEmpty ? null : dobCtrl.text.trim(),
      dod: dodCtrl.text.trim().isEmpty ? null : dodCtrl.text.trim(),
      occupation: occCtrl.text.trim().isEmpty ? null : occCtrl.text.trim(),
      education: eduCtrl.text.trim().isEmpty ? null : eduCtrl.text.trim(),
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      photoUrl: photoUrl,
    );
  }

  void dispose() {
    nameCtrl.dispose();
    dobCtrl.dispose();
    dodCtrl.dispose();
    occCtrl.dispose();
    eduCtrl.dispose();
    descCtrl.dispose();
  }
}

// Date Formatter
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      if (i == 3 || i == 5) if (i != limited.length - 1) buffer.write('-');
    }
    final formatted = buffer.toString();
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}