import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme.dart';

/// Asks for the 6-digit code emailed to [email] and confirms it.
///
/// Opens as a bottom sheet so the profile form underneath keeps every field
/// the customer already typed — coming back from a full screen would mean
/// rebuilding the form, and a half-filled form is exactly what nobody wants
/// to lose to a detour.
///
/// Returns true once the address is verified, false if they backed out. The
/// address is saved on the account by the verify call itself, so a true here
/// means the server already knows about it.
Future<bool> showEmailOtpSheet(BuildContext context, String email) async {
  final verified = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Dismissing by tapping outside would look like success while nothing was
    // verified, so the only ways out are Cancel and a confirmed code.
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _EmailOtpSheet(email: email),
  );
  return verified == true;
}

class _EmailOtpSheet extends StatefulWidget {
  const _EmailOtpSheet({required this.email});

  final String email;

  @override
  State<_EmailOtpSheet> createState() => _EmailOtpSheetState();
}

class _EmailOtpSheetState extends State<_EmailOtpSheet> {
  final _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  /// Mirrors the server's OTP_RESEND_COOLDOWN_SECONDS. Asking again sooner
  /// only earns a "please wait" from the backend, so the button stays off.
  static const _cooldownSeconds = 60;
  int _resendCooldown = _cooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _resendCooldown = _cooldownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await ApiService.verifyEmailOtp(email: widget.email, code: code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });
    try {
      await ApiService.sendEmailOtp(widget.email);
      _codeController.clear();
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code is on its way.')),
        );
      }
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The keyboard covers the sheet otherwise, and the code field is the one
    // thing on it that has to stay visible.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Icon(
                Icons.mark_email_read_outlined,
                size: 40,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),

              const Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'We sent a 6-digit code to',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 24),

              TextField(
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                textAlign: TextAlign.center,
                onSubmitted: (_) => _verify(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: '------',
                  hintStyle: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 10,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              Center(
                child: TextButton(
                  onPressed: (_resendCooldown == 0 && !_isResending)
                      ? _resend
                      : null,
                  child: _isResending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _resendCooldown > 0
                              ? 'Resend code in ${_resendCooldown}s'
                              : 'Resend code',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _resendCooldown > 0
                                ? Colors.grey[400]
                                : AppColors.primary,
                          ),
                        ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify Email'),
                ),
              ),
              TextButton(
                onPressed: _isVerifying
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
