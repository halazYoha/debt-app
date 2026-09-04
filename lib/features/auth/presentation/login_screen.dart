import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading    = false;
  bool _obscurePass  = true;
  String? _errorMessage;
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final email    = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception('ኢሜይልና የይለፍ ቃል ባዶ መሆን አይችልም።');
      }
      if (_isLogin) {
        await authRepo.signIn(email, password);
      } else {
        await authRepo.signUp(email, password);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll(RegExp(r'^\[.*?\] '), '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo ────────────────────────────────────────────────────
                Container(
                  width: 90,
                  height: 90,
                  margin: const EdgeInsets.only(bottom: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      size: 46, color: Colors.white),
                ),

                // ── Title ────────────────────────────────────────────────────
                Text(
                  'DebtTracker',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  _isLogin ? 'ይግቡ እና ዕዳዎን ያስተዳድሩ' : 'አዲስ መለያ ይፍጠሩ',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),

                // ── Error banner ─────────────────────────────────────────────
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Email ────────────────────────────────────────────────────
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'ኢሜይል',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // ── Password ─────────────────────────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'የይለፍ ቃል',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Primary button ────────────────────────────────────────────
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _isLogin ? 'ግባ' : 'ተመዝገብ',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // ── Toggle ────────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin ? 'መለያ የለዎትም?' : 'መለያ አለዎት?',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = null;
                      }),
                      style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8)),
                      child: Text(
                        _isLogin ? 'ተመዝገቡ' : 'ይግቡ',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B), // amber — different colour
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
