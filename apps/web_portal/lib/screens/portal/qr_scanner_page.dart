import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:intl/intl.dart';

const _brandColor = Color(0xff215e3f);

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final _repo = SecurityPassRepository();
  final _tokenCtrl = TextEditingController();
  String _scanType = 'entry';

  bool _scanning = false;
  Map<String, dynamic>? _lastResult;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter or scan a QR code')));
      return;
    }

    setState(() {
      _scanning = true;
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
          _scanning = false;
          _lastResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                    Icon(Icons.qr_code_scanner, size: 48, color: Colors.white),
                    SizedBox(height: 12),
                    Text('Security Pass Scanner',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Scan a QR code to validate',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                  'This feature is coming soon! In the meantime, you can paste a QR code token below to test the validation logic.',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),

              const SizedBox(height: 24),

              // Entry/Exit toggle
              SegmentedButton<String>(
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
              ),

              const SizedBox(height: 20),

              // Token input
              TextField(
                controller: _tokenCtrl,
                decoration: InputDecoration(
                  labelText: 'QR Code Token',
                  hintText: 'Paste or scan QR code here',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _tokenCtrl.clear();
                      setState(() => _lastResult = null);
                    },
                  ),
                ),
                onSubmitted: (_) => _scan(),
              ),
              const SizedBox(height: 16),

              // Scan button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _scanning ? null : _scan,
                  icon: _scanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified_outlined,
                          color: Colors.white),
                  label: Text(_scanning ? 'Validating...' : 'Validate Pass'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Result card
              if (_lastResult != null) _buildResultCard(),
            ],
          ),
        ),
      ),
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
        border: Border.all(color: fgColor.withOpacity(0.3)),
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
