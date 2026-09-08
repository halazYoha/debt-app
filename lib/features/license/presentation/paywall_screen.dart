import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/license/license_provider.dart';
import '../../../core/license/license_service.dart';
import '../../auth/data/auth_repository.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAmharic = true;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call failed: $phoneNumber')),
        );
      }
    }
  }

  Future<void> _handleActivation() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = _isAmharic ? 'እባክዎን የማግበሪያ ኮዱን ያስገቡ' : 'Please enter the activation code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await ref.read(licenseStatusProvider.notifier).activate(code);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isAmharic
                        ? 'መተግበሪያው በስኬት ተነቅሏል! እንኳን ደስ አለዎት!'
                        : 'App successfully activated! Welcome!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = _isAmharic
              ? 'የተሳሳተ የማግበሪያ ኮድ! እባክዎን ደግመው ይሞክሩ ወይም ይደውሉ።'
              : 'Invalid activation code! Please check and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final licenseAsync = ref.watch(licenseStatusProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
              const Color(0xFF090D16),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Language Switcher Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isAmharic = !_isAmharic;
                            });
                          },
                          icon: const Icon(Icons.language, color: Colors.amber, size: 20),
                          label: Text(
                            _isAmharic ? 'English' : 'አማርኛ',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Icon & Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.withOpacity(0.15),
                        border: Border.all(color: Colors.amber.withOpacity(0.4), width: 2),
                      ),
                      child: const Icon(
                        Icons.lock_clock_rounded,
                        size: 64,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      _isAmharic ? 'የ 30 ቀን ነፃ ሙከራ ጊዜዎ ተጠናቋል' : '30-Day Free Trial Expired',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      _isAmharic
                          ? 'መተግበሪያውን መደበኛ አጠቃቀም ለመቀጠል እባክዎን ለልማት አውጭው ደውለው የማግበሪያ ኮድ ያግኙ።'
                          : 'To continue using all features, please contact the developer to receive your activation code.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Developer Phone Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.phone, color: Colors.black, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isAmharic ? 'ለልማት አውጭው ይደውሉ' : 'Call Developer',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      LicenseService.devPhoneNumber,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => _makePhoneCall(LicenseService.devPhoneNumber),
                            icon: const Icon(Icons.call, color: Colors.black),
                            label: Text(
                              _isAmharic ? 'አሁን ደውል (0938236272)' : 'Call Now (0938236272)',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Device Info Details (to give to developer)
                    licenseAsync.when(
                      data: (license) {
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _isAmharic ? 'የእርስዎ መሳሪያ መለያ (Device ID)' : 'Your Device ID',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18, color: Colors.amber),
                                    tooltip: 'Copy ID',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: license.deviceId));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(_isAmharic
                                              ? 'መሳሪያ ID ተገልብጧል'
                                              : 'Device ID copied to clipboard'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              SelectableText(
                                license.deviceId,
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (license.userEmail != null && license.userEmail!.isNotEmpty) ...[
                                const Divider(color: Colors.white12, height: 16),
                                Text(
                                  'Email: ${license.userEmail}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
                      error: (err, stack) => const SizedBox(),
                    ),
                    const SizedBox(height: 24),

                    // Activation Code Input Box
                    TextField(
                      controller: _codeController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 9,
                      decoration: InputDecoration(
                        hintText: 'XXXX-XXXX',
                        hintStyle: TextStyle(
                          color: Colors.white30,
                          letterSpacing: 3,
                        ),
                        labelText: _isAmharic ? 'የማግበሪያ ኮድ ያስገቡ' : 'Enter Activation Code',
                        labelStyle: const TextStyle(color: Colors.amber),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.amber),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.amber, width: 2),
                        ),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade400),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade200, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Activate Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleActivation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade600,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              _isAmharic ? 'መተግበሪያውን አግብር' : 'ACTIVATE APP',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Logout Option
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).signOut();
                      },
                      icon: const Icon(Icons.logout, color: Colors.white54, size: 18),
                      label: Text(
                        _isAmharic ? 'ውጣ (Sign Out)' : 'Sign Out',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
