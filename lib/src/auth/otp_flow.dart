import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../onekm_core.dart';

/// Shared phone-OTP login flow (user + provider apps): phone step →
/// code step, single screen, no router needed inside. The host app shows
/// this on its login route and navigates on [SessionController] changes.
///
/// [title] is optional: when null no app bar renders — the per-app
/// wordmark above the form already says which app this is, so an
/// explicit "Sign in" label would just repeat it.
///
/// A 401 on verify means a wrong code *or* (providers) an account still
/// under verification — the server answers identically by design, so
/// [pendingNote] surfaces that hint where relevant.
class OtpFlow extends StatefulWidget {
  const OtpFlow({
    super.key,
    required this.session,
    required this.controller,
    this.title,
    this.pendingNote,
    this.logoVariant = OneKmLogoVariant.user,
  });

  final Session session;
  final SessionController controller;
  final String? title;
  final String? pendingNote;

  /// Per-app wordmark shown above the form.
  final OneKmLogoVariant logoVariant;

  @override
  State<OtpFlow> createState() => _OtpFlowState();
}

class _OtpFlowState extends State<OtpFlow> {
  var _codeStep = false;
  var _phone = '';
  var _busy = false;
  String? _error;
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  Timer? _cooldownTimer;

  /// Seconds until resend is allowed (matches the server resend gap).
  var _cooldown = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Mirrors the server's `normalize_phone`: bare 10-digit mobiles,
  /// `0`-trunk (11) and `91`-prefixed (12) forms all pass; anything
  /// else gets an inline error instead of a server round trip.
  String? _validPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final local = digits.length == 12 && digits.startsWith('91')
        ? digits.substring(2)
        : digits.length == 11 && digits.startsWith('0')
            ? digits.substring(1)
            : digits;
    if (local.length != 10 || !'6789'.contains(local[0])) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  Future<void> _request() async {
    final problem = _validPhone(_phoneCtrl.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _phone = _phoneCtrl.text.trim();
      await withRetry(() => widget.session.requestOtp(_phone));
      if (!mounted) return;
      setState(() {
        _codeStep = true;
        _busy = false;
      });
      _startCooldown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.rateLimited
            ? 'Too many tries — wait a bit, then retry.'
            : CoreStrings.of('tryAgain', Localizations.localeOf(context));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = CoreStrings.of('tryAgain', Localizations.localeOf(context));
      });
    }
  }

  /// Resend uses the same endpoint (the server enforces its cooldown
  /// with 429, surfaced as the rate-limit message on early taps).
  Future<void> _resend() async {
    if (_busy || _cooldown > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await withRetry(() => widget.session.requestOtp(_phone));
      if (!mounted) return;
      setState(() => _busy = false);
      _startCooldown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.rateLimited
            ? 'Too many tries — wait a bit, then retry.'
            : CoreStrings.of('tryAgain', Localizations.localeOf(context));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = CoreStrings.of('tryAgain', Localizations.localeOf(context));
      });
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown = _cooldown - 1);
      }
    });
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (_busy || code.length != 6) {
      if (code.length != 6) setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await withRetry(() => widget.session.verifyOtp(_phone, code));
      await widget.controller.adoptedSignIn();
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = CoreStrings.of('tryAgain', Localizations.localeOf(context));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = CoreStrings.of('tryAgain', Localizations.localeOf(context));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final title = widget.title;
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: kPaddingPage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_codeStep) ...[
                Center(
                    child: OneKmLogo(
                        height: 44, variant: widget.logoVariant)),
                const SizedBox(height: 16),
                const Text(
                  'Enter your mobile number. We will text you a login code.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[+\d\s]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '98765 43210',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _request(),
                ),
              ] else ...[
                Text('Code sent to $_phone.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '6-digit code',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onChanged: (_) {
                    // Auto-submit a complete code (Belya pattern); the
                    // button stays for pastes that need a nudge.
                    if (_codeCtrl.text.trim().length == 6) _verify();
                  },
                  onSubmitted: (_) => _verify(),
                ),
                TextButton(
                  onPressed:
                      _busy || _cooldown > 0 ? null : () => _resend(),
                  child: Text(_cooldown > 0
                      ? 'Resend code in $_cooldown s'
                      : 'Resend code'),
                ),
                if (widget.pendingNote != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.pendingNote!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _codeStep = false),
                  child: const Text('Use a different number'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : (_codeStep ? _verify : _request),
                child: _busy
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_codeStep
                        ? CoreStrings.of('verify', locale)
                        : CoreStrings.of('sendCode', locale)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
