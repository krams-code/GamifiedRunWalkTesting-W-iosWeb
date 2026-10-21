import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/block_inputs.dart';
import '../../widgets/block_ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  int _cooldown = 0;
  Timer? _timer;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void _snack(String msg) {
    if (!mounted) return;
    blockSnack(context, msg);
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack('Please enter your email.');
      return;
    }
    if (!_emailRe.hasMatch(email)) {
      _snack('Enter a valid email address.');
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _sent = true);
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      _snack(e.code == 'network-request-failed'
          ? 'No internet connection. Try again.'
          : (e.message ?? 'Failed to send reset email.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    super.dispose();
  }

  Widget _bigBtn(String label, VoidCallback? onTap) => PressBlock(
        color: Rb.blue,
        edge: Rb.blueEdge,
        depth: 8,
        radius: 16,
        padding: const EdgeInsets.symmetric(vertical: 16),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Colors.white),
                  )
                : BlockText(label, size: 16, stroke: 4),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Rb.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PressBlock(
                      color: Rb.slot,
                      edge: Rb.slateEdge,
                      depth: 3,
                      radius: 10,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      onTap: () => Navigator.pop(context),
                      child: const BlockText('◀ BACK', size: 11, stroke: 3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AuthBanner(
                    title: 'HAKBANG HERO',
                    subtitle: 'GAMIFIED FITNESS TRACKER',
                  ),
                  const SizedBox(height: 24),
                  Block(
                    color: Rb.panel,
                    edge: Rb.panelEdge,
                    depth: 6,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: BlockText('🔑 RESET PASSWORD',
                              size: 18, stroke: 4.5),
                        ),
                        const SizedBox(height: 10),
                        const Center(
                          child: BlockText(
                            "Enter your email and we'll send you a reset link.",
                            size: 11,
                            stroke: 2.5,
                            color: Color(0xFFB8BDC4),
                            align: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (!_sent) ...[
                          BlockTextField(
                            label: 'EMAIL',
                            hint: 'hero@email.com',
                            icon: '✉️',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            action: TextInputAction.done,
                            onSubmitted: (_) => _loading ? null : _sendReset(),
                          ),
                          const SizedBox(height: 18),
                          _bigBtn('SEND RESET LINK', _loading ? null : _sendReset),
                        ] else ...[
                          Block(
                            color: Rb.hud,
                            edge: Rb.panelEdge,
                            depth: 4,
                            radius: 14,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                const BlockText('✅ RESET EMAIL SENT!',
                                    size: 15, stroke: 4, color: Rb.gold),
                                const SizedBox(height: 8),
                                const BlockText(
                                  'Check your inbox (and Spam) and tap the link to set a new password.',
                                  size: 11,
                                  stroke: 2.5,
                                  align: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          PressBlock(
                            color: Rb.slot,
                            edge: Rb.slateEdge,
                            depth: 4,
                            radius: 12,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onTap: (_cooldown > 0 || _loading) ? null : _sendReset,
                            child: Center(
                              child: BlockText(
                                _cooldown > 0
                                    ? 'RESEND IN ${_cooldown}S'
                                    : 'RESEND EMAIL',
                                size: 12,
                                stroke: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _bigBtn('BACK TO LOGIN', () => Navigator.pop(context)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
