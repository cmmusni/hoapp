import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _brandColor = Color(0xff215e3f);

enum _ScanMode { camera, manual }

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final _repo = SecurityPassRepository();
  final _tokenCtrl = TextEditingController();
  MobileScannerController? _cameraController;

  String _scanType = 'entry';
  _ScanMode _mode = _ScanMode.camera;
  bool _validating = false;
  bool _cameraError = false;
  Map<String, dynamic>? _lastResult;
  String? _lastScannedToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop camera when app goes to background; restart when resumed.
    if (_cameraController == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController?.stop();
    } else if (state == AppLifecycleState.resumed &&
        _mode == _ScanMode.camera &&
        !_cameraError) {
      _cameraController?.start();
    }
  }

  void _initCamera() {
    _cameraController?.dispose();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.qrCode],
    );
    _cameraController!.start().catchError((_) {
      if (mounted) {
        setState(() {
          _cameraError = true;
          _mode = _ScanMode.manual;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.stop();
    _cameraController?.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_validating) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    if (code == _lastScannedToken) return;
    _lastScannedToken = code;
    _validateToken(code);
  }

  Future<void> _validateManual() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a QR code token')));
      return;
    }
    _validateToken(token);
  }

  Future<void> _validateToken(String token) async {
    setState(() {
      _validating = true;
      _lastResult = null;
    });

    try {
      final appState = context.read<AppState>();
      final result = await _repo.validateQr(
        qrToken: token,
        communityId: appState.activeCommunityId!,
        scanType: _scanType,
      );

      if (mounted) {
        setState(() {
          _validating = false;
          _lastResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _validating = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _resetScan() {
    setState(() {
      _lastResult = null;
      _lastScannedToken = null;
      _tokenCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildScanTypeToggle(),
            const SizedBox(height: 16),
            _buildModeToggle(),
            const SizedBox(height: 16),
            if (_mode == _ScanMode.camera) _buildCameraScanner(),
            if (_mode == _ScanMode.manual) _buildManualInput(),
            const SizedBox(height: 16),
            if (_validating)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Validating pass…', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            if (_lastResult != null) ...[
              _buildResultCard(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _resetScan,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan Next Pass'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandColor,
                    side: const BorderSide(color: _brandColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandColor, Color(0xff2e8b57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.qr_code_scanner, size: 40, color: Colors.white),
          SizedBox(height: 10),
          Text('Security Pass Scanner',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Scan or enter a QR code to validate',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildScanTypeToggle() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
            value: 'entry',
            label: Text('Entry'),
            icon: Icon(Icons.login_outlined)),
        ButtonSegment(
          value: 'exit',
          label: Text('Exit'),
          icon: Icon(Icons.logout_outlined),
        ),
      ],
      selected: {_scanType},
      onSelectionChanged: (v) => setState(() => _scanType = v.first),
    );
  }

  Widget _buildModeToggle() {
    return SegmentedButton<_ScanMode>(
      segments: const [
        ButtonSegment(
            value: _ScanMode.camera,
            label: Text('Camera'),
            icon: Icon(Icons.camera_alt_outlined)),
        ButtonSegment(
            value: _ScanMode.manual,
            label: Text('Manual'),
            icon: Icon(Icons.keyboard_outlined)),
      ],
      selected: {_mode},
      onSelectionChanged: (v) => setState(() => _mode = v.first),
    );
  }

  Widget _buildCameraScanner() {
    if (_cameraError) {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Camera not available',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54)),
            const SizedBox(height: 6),
            Text('Grant camera permission or use Manual mode.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() => _cameraError = false);
                _cameraController?.dispose();
                _initCamera();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry Camera'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: _brandColor.withValues(alpha: 0.3), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (_cameraController != null)
                MobileScanner(
                  controller: _cameraController!,
                  onDetect: _onDetect,
                ),
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _validating ? 'Validating…' : 'Point camera at QR code',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Position the QR code within the frame',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildManualInput() {
    return Column(
      children: [
        TextField(
          controller: _tokenCtrl,
          decoration: InputDecoration(
            labelText: 'QR Code Token',
            hintText: 'Paste the QR code token here',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.qr_code),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _tokenCtrl.clear();
                setState(() => _lastResult = null);
              },
            ),
          ),
          onSubmitted: (_) => _validateManual(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _validating ? null : _validateManual,
            icon: _validating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_outlined, color: Colors.white),
            label: Text(_validating ? 'Validating…' : 'Validate Pass'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    final result = _lastResult!;
    final isValid = result['ok'] == true;
    final scanResult = result['scan_result'] as String? ?? 'unknown';
    final message = result['message'] as String? ?? '';
    final passData = result['pass'] as Map<String, dynamic>?;

    final bgColor = isValid ? Colors.green.shade50 : Colors.red.shade50;
    final fgColor = isValid ? Colors.green.shade800 : Colors.red.shade800;
    final icon = isValid ? Icons.check_circle : Icons.cancel;
    final dateFmt = DateFormat('MMM dd, yyyy hh:mm a');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: fgColor),
          const SizedBox(height: 10),
          Text(
            isValid ? 'PASS VALID' : scanResult.toUpperCase(),
            style: TextStyle(
                color: fgColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: fgColor, fontSize: 14)),
          if (passData != null) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            _detailRow('Pass Type', passData['pass_type'] ?? ''),
            _detailRow('Visitor', passData['visitor_name'] ?? ''),
            _detailRow('Purpose', passData['purpose'] ?? ''),
            if (passData['plate_number'] != null)
              _detailRow('Plate #', passData['plate_number']),
            _detailRow(
                'Valid From', _tryFormatDate(passData['valid_from'], dateFmt)),
            _detailRow('Valid Until',
                _tryFormatDate(passData['valid_until'], dateFmt)),
            _detailRow(
                'Uses', '${passData['use_count']} / ${passData['max_uses']}'),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _tryFormatDate(String? isoStr, DateFormat fmt) {
    if (isoStr == null) return '';
    try {
      return fmt.format(DateTime.parse(isoStr).toLocal());
    } catch (_) {
      return isoStr;
    }
  }
}
