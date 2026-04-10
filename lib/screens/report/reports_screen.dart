import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/cloudinary_service.dart';
import '../../services/report_extraction_service.dart';
import '../home/home_screen.dart';

class _PendingFile {
  final String name;
  final Uint8List bytes;
  final int sizeKB;
  bool isExtracting = false;
  bool isExtracted = false;
  
  _PendingFile({required this.name, required this.bytes, required this.sizeKB});

  String get ext => name.split('.').last.toUpperCase();
  bool get isImage => ['JPG', 'JPEG', 'PNG'].contains(ext);
}

class ReportsScreen extends StatefulWidget {
  /// Pass these when opening in edit mode from the calendar.
  final Map<String, dynamic>? existingData;
  final String? reportDocId;

  const ReportsScreen({
    super.key,
    this.existingData,
    this.reportDocId,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  // ── Upload state ──────────────────────────────────────────
  bool _isSaving = false;
  bool _showUploadOptions = false;
  final List<_PendingFile> _pendingFiles = [];
  /// URLs already stored in Firestore (kept when editing)
  List<String> _existingUrls = [];
  static const int _maxSizeKB = 1024;

  // ── Age (fetched from profile DOB) ────────────────────────
  int? _age;

  // ── Animation ─────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Form ──────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _bmiCtrl = TextEditingController();
  final TextEditingController _rbsCtrl = TextEditingController();
  final TextEditingController _tshCtrl = TextEditingController();
  final TextEditingController _hbCtrl = TextEditingController();
  final TextEditingController _whrCtrl = TextEditingController();
  final TextEditingController _lhCtrl = TextEditingController();
  final TextEditingController _fshCtrl = TextEditingController();
  final TextEditingController _amhCtrl = TextEditingController();
  final TextEditingController _prlCtrl = TextEditingController();
  final TextEditingController _prgCtrl = TextEditingController();


  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fetchUserData();
    if (widget.existingData != null) {
      _populateExisting();
    }
  }

  void _populateExisting() {
    final d = widget.existingData!;
    final m = (d['metrics'] as Map<String, dynamic>?) ?? {};
    final urls = d['reportUrls'];

    // Preserve existing uploaded URLs
    if (urls is List) {
      _existingUrls = urls.map((e) => e.toString()).toList();
    }

    // Pre-fill metric fields (after build, so we use addPostFrameCallback)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (m['bmi'] != null) _bmiCtrl.text = m['bmi'].toString();
        if (m['rbs'] != null) _rbsCtrl.text = m['rbs'].toString();
        if (m['tsh'] != null) _tshCtrl.text = m['tsh'].toString();
        if (m['hb'] != null) _hbCtrl.text = m['hb'].toString();
        if (m['whr'] != null) _whrCtrl.text = m['whr'].toString();
        if (m['lh'] != null) _lhCtrl.text = m['lh'].toString();
        if (m['fsh'] != null) _fshCtrl.text = m['fsh'].toString();
        if (m['amh'] != null) _amhCtrl.text = m['amh'].toString();
        if (m['prl'] != null) _prlCtrl.text = m['prl'].toString();
        if (m['prg'] != null) _prgCtrl.text = m['prg'].toString();
      });
    });
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        
        // 1. Fetch Age
        if (data['dob'] != null) {
          final dob = (data['dob'] as Timestamp).toDate();
          final now = DateTime.now();
          int age = now.year - dob.year;
          if (now.month < dob.month ||
              (now.month == dob.month && now.day < dob.day)) {
            age--;
          }
          if (mounted) setState(() => _age = age);
        }

        // 2. Fetch Height & Weight and calculate BMI (only if it's a new report)
        if (widget.existingData == null) {
          final weight = data['weight'];
          final height = data['height'];

          if (weight != null && height != null) {
            final w = (weight is num) ? weight.toDouble() : double.tryParse(weight.toString());
            final h = (height is num) ? height.toDouble() : double.tryParse(height.toString());

            if (w != null && h != null && h > 0) {
              final bmi = w / ((h / 100) * (h / 100));
              if (mounted) {
                setState(() {
                  _bmiCtrl.text = bmi.toStringAsFixed(1);
                });
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bmiCtrl.dispose();
    _rbsCtrl.dispose();
    _tshCtrl.dispose();
    _hbCtrl.dispose();
    _whrCtrl.dispose();
    _lhCtrl.dispose();
    _fshCtrl.dispose();
    _amhCtrl.dispose();
    _prlCtrl.dispose();
    _prgCtrl.dispose();
    super.dispose();
  }

  // ── Extract and autofill from report ─────────────────────
  Future<void> _extractAndAutofillFromReport(_PendingFile file, int index) async {
    print('\n');
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║         STARTING REPORT EXTRACTION PROCESS                ║');
    print('╚═══════════════════════════════════════════════════════════╝');
    print('📁 File: ${file.name}');
    print('📏 Size: ${file.sizeKB} KB');
    print('🖼️  Type: ${file.isImage ? "Image" : "PDF"}');
    print('───────────────────────────────────────────────────────────');
    
    setState(() => file.isExtracting = true);

    try {
      // Show processing message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🤖 AI is analyzing your report... This may take 10-60 seconds'),
            backgroundColor: Color(0xFF2E4A6B),
            duration: Duration(seconds: 3),
          ),
        );
      }

      print('🚀 Calling AI extraction service...');
      print('⏳ Please wait, this may take 10-60 seconds...');
      
      // Extract and parse medical values directly from bytes
      final result = await ReportExtractionService.extractAndParseReport(
        imageBytes: file.bytes,
        fileName: file.name,
      );

      print('📦 EXTRACTION RESULT:');
      print('Success: ${result['success']}');
      if (result['error'] != null) {
        print('Error: ${result['error']}');
      }
      if (result['extractedData'] != null) {
        print('Extracted Data: ${result['extractedData']}');
      }
      print('───────────────────────────────────────────────────────────');

      if (result['success'] == true) {
        final extractedData = result['extractedData'] as Map<String, dynamic>;
        
        if (extractedData.isEmpty) {
          print('⚠️  NO DATA EXTRACTED - Fields are empty');
          setState(() => file.isExtracting = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ No medical values found in the report. Please fill manually.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          print('╚═══════════════════════════════════════════════════════════╝\n');
          return;
        }

        int fieldsFilledCount = 0;
        
        print('🔄 AUTOFILLING FORM FIELDS:');
        
        // Autofill the form fields
        setState(() {
          if (extractedData['bmi'] != null) {
            _bmiCtrl.text = extractedData['bmi'].toString();
            fieldsFilledCount++;
            print('  ✓ BMI: ${extractedData['bmi']}');
          }
          if (extractedData['rbs'] != null) {
            _rbsCtrl.text = extractedData['rbs'].toString();
            fieldsFilledCount++;
            print('  ✓ RBS: ${extractedData['rbs']}');
          }
          if (extractedData['tsh'] != null) {
            _tshCtrl.text = extractedData['tsh'].toString();
            fieldsFilledCount++;
            print('  ✓ TSH: ${extractedData['tsh']}');
          }
          if (extractedData['hb'] != null) {
            _hbCtrl.text = extractedData['hb'].toString();
            fieldsFilledCount++;
            print('  ✓ Hb: ${extractedData['hb']}');
          }
          if (extractedData['whr'] != null) {
            _whrCtrl.text = extractedData['whr'].toString();
            fieldsFilledCount++;
            print('  ✓ WHR: ${extractedData['whr']}');
          }
          if (extractedData['lh'] != null) {
            _lhCtrl.text = extractedData['lh'].toString();
            fieldsFilledCount++;
            print('  ✓ LH: ${extractedData['lh']}');
          }
          if (extractedData['fsh'] != null) {
            _fshCtrl.text = extractedData['fsh'].toString();
            fieldsFilledCount++;
            print('  ✓ FSH: ${extractedData['fsh']}');
          }
          if (extractedData['amh'] != null) {
            _amhCtrl.text = extractedData['amh'].toString();
            fieldsFilledCount++;
            print('  ✓ AMH: ${extractedData['amh']}');
          }
          if (extractedData['prl'] != null) {
            _prlCtrl.text = extractedData['prl'].toString();
            fieldsFilledCount++;
            print('  ✓ PRL: ${extractedData['prl']}');
          }
          if (extractedData['prg'] != null) {
            _prgCtrl.text = extractedData['prg'].toString();
            fieldsFilledCount++;
            print('  ✓ PRG: ${extractedData['prg']}');
          }
          
          file.isExtracting = false;
          file.isExtracted = true;
        });

        print('───────────────────────────────────────────────────────────');
        print('✅ AUTOFILL COMPLETE');
        print('📊 Total fields filled: $fieldsFilledCount');
        print('╚═══════════════════════════════════════════════════════════╝\n');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ $fieldsFilledCount field${fieldsFilledCount > 1 ? 's' : ''} extracted! Please review before saving.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        setState(() => file.isExtracting = false);
        final errorMsg = result['error'] ?? 'Unknown error';
        
        print('❌ EXTRACTION FAILED');
        print('Error: $errorMsg');
        if (result['rawText'] != null) {
          print('Raw response: ${result['rawText']}');
        }
        print('╚═══════════════════════════════════════════════════════════╝\n');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Extraction failed: $errorMsg'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _extractAndAutofillFromReport(file, index),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => file.isExtracting = false);
      
      print('❌ EXCEPTION DURING EXTRACTION');
      print('Exception: $e');
      print('╚═══════════════════════════════════════════════════════════╝\n');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ── File picker ───────────────────────────────────────────
  Future<void> _pickReport(bool isCamera) async {
    Uint8List? bytes;
    String? fileName;

    try {
      if (isCamera) {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.camera);
        if (pickedFile != null) {
          bytes = await pickedFile.readAsBytes();
          fileName = pickedFile.name;
        }
      } else {
        FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
          withData: true,
        );
        if (result != null && result.files.single.bytes != null) {
          bytes = result.files.single.bytes;
          fileName = result.files.single.name;
        }
      }

      if (bytes == null || fileName == null) return;

      final sizeKB = bytes.length ~/ 1024;
      if (sizeKB > _maxSizeKB) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File too large (${sizeKB}KB). Max is ${_maxSizeKB}KB.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      setState(() {
        _pendingFiles.add(
          _PendingFile(name: fileName!, bytes: bytes!, sizeKB: sizeKB),
        );
        _showUploadOptions = false;
      });

      // Auto-trigger extraction for images
      if (fileName.toLowerCase().endsWith('.jpg') ||
          fileName.toLowerCase().endsWith('.jpeg') ||
          fileName.toLowerCase().endsWith('.png')) {
        // Wait a bit for UI to update, then trigger extraction
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _pendingFiles.isNotEmpty) {
            final lastIndex = _pendingFiles.length - 1;
            _extractAndAutofillFromReport(_pendingFiles[lastIndex], lastIndex);
          }
        });
      }
    } catch (e) {
      debugPrint('Pick error: $e');
    }
  }

  // ── Save ──────────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // Upload any newly picked files and merge with existing URLs
      final List<String> newUrls = [];
      for (final f in _pendingFiles) {
        final url = await CloudinaryService.uploadFile(f.bytes, f.name);
        if (url != null) {
          newUrls.add(url);
        }
      }
      final List<String> allUrls = [..._existingUrls, ...newUrls];

      final dateStr = widget.existingData?['date'] ??
          DateFormat('yyyy-MM-dd').format(DateTime.now());

      final reportName = (_pendingFiles.isNotEmpty || _existingUrls.isNotEmpty)
          ? (_pendingFiles.isNotEmpty
              ? _pendingFiles.map((f) => f.name).join(', ')
              : (widget.existingData?['reportName'] ?? 'Health Report'))
          : 'Manual Entry';

      final data = {
        'reportName': reportName,
        'reportUrls': allUrls,
        'date': dateStr,
        'updatedAt': FieldValue.serverTimestamp(),
        'metrics': {
          'age': _age,
          'bmi': double.tryParse(_bmiCtrl.text),
          'rbs': double.tryParse(_rbsCtrl.text),
          'tsh': double.tryParse(_tshCtrl.text),
          'hb': double.tryParse(_hbCtrl.text),
          'whr': double.tryParse(_whrCtrl.text),
          'lh': double.tryParse(_lhCtrl.text),
          'fsh': double.tryParse(_fshCtrl.text),
          'amh': double.tryParse(_amhCtrl.text),
          'prl': double.tryParse(_prlCtrl.text),
          'prg': double.tryParse(_prgCtrl.text),
        },
      };

      final reportsCol = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reports');

      if (widget.reportDocId != null) {
        // ── Edit mode: update existing document ──
        await reportsCol.doc(widget.reportDocId).update(data);
      } else {
        // ── New report ──
        data['uploadedAt'] = FieldValue.serverTimestamp();
        await reportsCol.add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.reportDocId != null
                ? 'Report updated successfully!'
                : 'Report saved successfully!'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          widget.reportDocId != null
                              ? 'Edit Report'
                              : 'Health Report',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E4A6B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Container(
                        width: 30,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A6EA8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Color(0xFF2E4A6B),
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.reportDocId != null
                          ? 'Edit Report'
                          : 'Health Reports',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E4A6B),
                        letterSpacing: -1,
                      ),
                    ),

                    // ── Upload card ───────────────────────────
                    const SizedBox(height: 24),
                    
                    // ── AI Extraction Info Banner ─────────────
                    if (_pendingFiles.any((f) => f.isImage && !f.isExtracted))
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E4A6B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF2E4A6B).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Color(0xFF2E4A6B),
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tip: Click "Extract" to auto-fill medical values from your report using AI',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2E4A6B),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    _buildMainCard(),

                    // ── Metrics form ──────────────────────────
                    _buildSectionHeader('BASIC DATA'),
                    _buildInputRow([
                      _buildReadOnlyTile(
                        'Age (yrs)',
                        _age != null ? '$_age' : '—',
                      ),
                      _buildTextField(_bmiCtrl, 'BMI'),
                    ]),

                    _buildSectionHeader('BLOOD & HORMONES'),
                    _buildInputRow([
                      _buildTextField(_rbsCtrl, 'RBS (mg/dL)'),
                      _buildTextField(_tshCtrl, 'TSH (mIU/L)'),
                    ]),
                    _buildInputRow([
                      _buildTextField(_hbCtrl, 'Hb (g/dL)'),
                      _buildTextField(_whrCtrl, 'Waist:Hip Ratio'),
                    ]),
                    _buildInputRow([
                      _buildTextField(_lhCtrl, 'LH (mIU/mL)'),
                      _buildTextField(_fshCtrl, 'FSH (mIU/mL)'),
                    ]),
                    _buildInputRow([
                      _buildTextField(_amhCtrl, 'AMH (ng/mL)'),
                      _buildTextField(_prlCtrl, 'PRL (ng/mL)'),
                    ]),
                    _buildTextField(_prgCtrl, 'PRG (ng/mL)'),

                    // ── Save button ───────────────────────────
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E4A6B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Save Metrics & Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
          if (_isSaving) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // ── Upload card widgets ───────────────────────────────────

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_pendingFiles.isEmpty)
            _buildIdleState()
          else ...[
            ..._pendingFiles.asMap().entries.map(
              (e) => _buildFileRow(e.value, e.key),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildActionSwitcher(),
          ],
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFFF4F6FA),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.upload_file,
            color: Color(0xFF2E4A6B),
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select Report (Optional)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1F26),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'PDF or Images — Max 1MB.\nYou can also fill in metrics below without uploading.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF7A8FA6), height: 1.5),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickReport(false),
                child: _uploadButton(Icons.description, 'File'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _pickReport(true),
                child: _uploadButton(Icons.photo_camera, 'Camera'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionSwitcher() {
    if (!_showUploadOptions) {
      return GestureDetector(
        onTap: () => setState(() => _showUploadOptions = true),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_circle_outline, color: Color(0xFF2E4A6B), size: 18),
            SizedBox(width: 8),
            Text(
              'Add Another File',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E4A6B),
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickReport(false),
            child: _uploadButton(Icons.description_outlined, 'File'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickReport(true),
            child: _uploadButton(Icons.camera_alt, 'Camera'),
          ),
        ),
      ],
    );
  }

  Widget _buildFileRow(_PendingFile f, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: f.isImage
                      ? const Color(0xFF3A6EA8).withOpacity(0.1)
                      : const Color(0xFFB5616A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  f.isImage ? Icons.image : Icons.picture_as_pdf,
                  color: f.isImage
                      ? const Color(0xFF3A6EA8)
                      : const Color(0xFFB5616A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    Text(
                      '${f.sizeKB} KB • ${f.isExtracted ? "Values extracted ✓" : "Ready"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: f.isExtracted
                            ? Colors.green
                            : const Color(0xFF7A8FA6),
                      ),
                    ),
                  ],
                ),
              ),
              if (f.isImage && !f.isExtracting && !f.isExtracted)
                ElevatedButton.icon(
                  onPressed: () => _extractAndAutofillFromReport(f, index),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Extract', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E4A6B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              if (f.isExtracting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2E4A6B),
                    ),
                  ),
                ),
              if (f.isExtracted)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
              IconButton(
                onPressed: () => setState(() => _pendingFiles.removeAt(index)),
                icon: const Icon(Icons.close, color: Colors.red, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _uploadButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF2E4A6B), size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E4A6B),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form widgets ──────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF7A8FA6),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInputRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children:
            children
                .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
                .toList()
              ..removeLast(),
      ),
    );
  }

  Widget _buildReadOnlyTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7A8FA6)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E4A6B),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.lock_outline,
                size: 12,
                color: Color(0xFFB0C4D4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF7A8FA6)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  // ── Loading overlay ───────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  color: Color(0xFF2E4A6B),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Saving...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
