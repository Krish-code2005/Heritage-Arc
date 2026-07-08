
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:heritage_arc/person.dart';
import 'package:flutter/services.dart';

// Palette pulled from the reference card
const _kAccentStart = Color(0xFFEF4A6D); // pink
const _kAccentEnd = Color(0xFFF6A94A);   // orange
const _kFieldFill = Color(0xFFF5F5F7);
const _kLabelColor = Color(0xFF111111);
const _kHintColor = Color(0xFF9B9B9B);

class ProfileEditScreen extends StatefulWidget {
  final Person? person;
  final bool isParent;

  const ProfileEditScreen({
    super.key,
    this.person,
    this.isParent = false,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

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
  late TextEditingController _partnerCtrl;

  Uint8List? _selectedImageBytes;
  String? _existingPhotoUrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
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
    _partnerCtrl = TextEditingController(text: p?.partnerName ?? '');

    _existingPhotoUrl = p?.photoUrl;
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _middleCtrl.dispose();
    _lastCtrl.dispose();
    _dobCtrl.dispose();
    _dodCtrl.dispose();
    _occCtrl.dispose();
    _eduCtrl.dispose();
    _descCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _fbCtrl.dispose();
    _instaCtrl.dispose();
    _partnerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isSaving) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  Future<String?> _uploadCompressedImage() async {
    if (_selectedImageBytes == null) return _existingPhotoUrl;

    try {
      var image = img.decodeImage(_selectedImageBytes!);
      if (image == null) throw Exception('Failed to decode image');

      if (image.width > 800) {
        image = img.copyResize(image, width: 800);
      }

      final webpBytes = img.encodeWebP(image);

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.webp';
      final path = 'profile_photos/$fileName';

      await _supabase.storage.from('profiles').uploadBinary(
            path,
            webpBytes,
            fileOptions: const FileOptions(contentType: 'image/webp'),
          );

      final publicUrl = _supabase.storage.from('profiles').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Upload Error: $e');
      return _existingPhotoUrl;
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First and Last name are required')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final photoUrl = await _uploadCompressedImage();

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
        partnerName: _partnerCtrl.text.trim().isEmpty ? null : _partnerCtrl.text.trim(),
        photoUrl: photoUrl,
        parentCount: widget.person?.parentCount ?? 0,
      );

      if (mounted) {
        Navigator.pop(context, person);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.person == null;

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
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row: title + back button
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isNew ? 'Add New Person' : 'Edit Profile',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: _kLabelColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, color: _kHintColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isNew
                                ? 'Fill in their details to add them to the tree.'
                                : 'Update their details below.',
                            style: const TextStyle(fontSize: 14, color: _kHintColor),
                          ),
                          const SizedBox(height: 24),

                          // Photo
                          Center(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 56,
                                    backgroundColor: _kFieldFill,
                                    backgroundImage: _selectedImageBytes != null
                                        ? MemoryImage(_selectedImageBytes!)
                                        : (_existingPhotoUrl != null
                                            ? NetworkImage(_existingPhotoUrl!)
                                            : null) as ImageProvider?,
                                    child: (_selectedImageBytes == null &&
                                            _existingPhotoUrl == null)
                                        ? const Icon(Icons.person,
                                            size: 56, color: _kHintColor)
                                        : null,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [_kAccentStart, _kAccentEnd],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text('Tap to change photo',
                                style: TextStyle(color: _kHintColor, fontSize: 13)),
                          ),
                          const SizedBox(height: 28),

                          _sectionLabel('Basic Information'),
                          const SizedBox(height: 14),
                          _fieldGrid([
                            _field('First name', _firstCtrl, hint: 'Roman'),
                            _field('Middle name', _middleCtrl, hint: 'Optional'),
                          ]),
                          _fieldGrid([
                            _field('Last name', _lastCtrl, hint: 'Bajracharya'),
                            _field("Partner's name", _partnerCtrl, hint: 'Optional'),
                          ]),
                         _fieldGrid([
  _field(
    'Date of birth',
    _dobCtrl,
    hint: 'YYYY-MM-DD',
    keyboardType: TextInputType.number,
    inputFormatters: [_DateInputFormatter()],
  ),
  _field(
    'Date of death',
    _dodCtrl,
    hint: 'YYYY-MM-DD',
    keyboardType: TextInputType.number,
    inputFormatters: [_DateInputFormatter()],
  ),
]),

                          const SizedBox(height: 24),
                          _sectionLabel('Additional Information'),
                          const SizedBox(height: 14),
                          _fieldGrid([
                            _field('Occupation', _occCtrl, hint: 'e.g. Engineer'),
                            _field('Education', _eduCtrl, hint: 'e.g. MIT'),
                          ]),
                          _field('Address', _addrCtrl, hint: 'City, Country', fullWidth: true),
                          const SizedBox(height: 14),
                          _labeled(
                            'Bio / Description',
                            TextField(
                              controller: _descCtrl,
                              maxLines: 3,
                              decoration: _decoration('Tell us briefly about them'),
                            ),
                          ),

                          const SizedBox(height: 24),
                          _sectionLabel('Contact & Social'),
                          const SizedBox(height: 14),
                          _fieldGrid([
                            _field('Phone', _phoneCtrl, hint: 'e.g. 980000000'),
                            _field('Email address', _emailCtrl, hint: 'example@domain.com'),
                          ]),
                          _fieldGrid([
                            _field('Facebook link', _fbCtrl, hint: 'https://facebook.com/...'),
                            _field('Instagram', _instaCtrl, hint: '@username'),
                          ]),

                          const SizedBox(height: 28),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kAccentStart,
                                disabledBackgroundColor: _kAccentStart.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
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
                  child: IgnorePointer(
                    ignoring: false,
                    child: Container(
                      color: Colors.black.withOpacity(0.25),
                      child: Center(
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          margin: const EdgeInsets.all(24),
                          child: const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: _kAccentStart),
                                SizedBox(height: 16),
                                Text(
                                  'Compressing & Uploading...',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _kLabelColor,
        ),
      );

  Widget _fieldGrid(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;
          if (isNarrow) {
            return Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1) const SizedBox(height: 14),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i != children.length - 1) const SizedBox(width: 16),
              ],
            ],
          );
        },
      ),
    );
  }
Widget _field(
  String label,
  TextEditingController controller, {
  String? hint,
  bool fullWidth = false,
  List<TextInputFormatter>? inputFormatters,
  TextInputType? keyboardType,
}) {
  final field = _labeled(
    label,
    TextField(
      controller: controller,
      decoration: _decoration(hint),
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
    ),
  );
  return fullWidth
      ? Padding(padding: const EdgeInsets.only(bottom: 14), child: field)
      : field;
}
  Widget _labeled(String label, Widget input) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kLabelColor,
          ),
        ),
        const SizedBox(height: 6),
        input,
      ],
    );
  }

  InputDecoration _decoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHintColor, fontSize: 14),
      filled: true,
      fillColor: _kFieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kAccentStart, width: 1.6),
      ),
    );
  }
}

// Auto-inserts hyphens as the user types: YYYY-MM-DD
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digitsOnly.length > 8 ? digitsOnly.substring(0, 8) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      if (i == 3 || i == 5) {
        if (i != limited.length - 1) buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
