import 'package:flutter/material.dart';

class AuthColors {
  static const navy = Color(0xFF1E3E78);
  static const secondaryDark = Color(0xFF223555);
  static const blue = Color(0xFF2F6FEF);
  static const blueSoft = Color(0xFFEAF3FF);
  static const blueGlow = Color(0xFFCFE4FF);
  static const border = Color(0xFFDCE7F6);
  static const textMuted = Color(0xFF5D6B86);
  static const textSoft = Color(0xFF8A98AD);
  static const errorBg = Color(0xFFFFF1F0);
  static const errorBorder = Color(0xFFF3B4B4);
  static const errorText = Color(0xFFB42318);
  static const button = Color(0xFF2F6FEF);
}

class AuthBackground extends StatelessWidget {
  const AuthBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5FAFF), Color(0xFFEAF4FF), Color(0xFFFDFEFF)],
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 154,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.elliptical(320, 78),
                  bottomRight: Radius.elliptical(320, 78),
                ),
              ),
            ),
          ),
          Positioned(
            top: 108,
            right: -88,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x222A6FDB), width: 28),
              ),
            ),
          ),
          Positioned(
            left: -26,
            top: MediaQuery.of(context).size.height * 0.30,
            child: const _GlowCircle(size: 120, color: Color(0x18359BFF)),
          ),
          const Positioned(top: 170, left: 30, child: _SoftDot(size: 12)),
          const Positioned(top: 214, left: 44, child: _SoftDot(size: 8)),
          const Positioned(top: 372, right: 18, child: _SoftDot(size: 12)),
          const Positioned(top: 430, right: 34, child: _SoftDot(size: 8)),
          const Positioned(bottom: 142, left: 36, child: _SoftDot(size: 14)),
          const Positioned(bottom: 86, right: 26, child: _SoftDot(size: 14)),
          child,
        ],
      ),
    );
  }
}

class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.child,
    this.maxWidth = 460,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    this.scrollable = true,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (!scrollable) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

InputDecoration authInputDecoration({
  required String label,
  required IconData icon,
  String? hint,
  Widget? suffixIcon,
}) {
  const borderRadius = BorderRadius.all(Radius.circular(22));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: AuthColors.textMuted),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    labelStyle: const TextStyle(color: AuthColors.textMuted),
    hintStyle: const TextStyle(color: AuthColors.textMuted),
    enabledBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AuthColors.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AuthColors.blue, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
    ),
  );
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AuthColors.errorBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuthColors.errorBorder),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AuthColors.errorText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    required this.label,
    required this.actionLabel,
    required this.onTap,
    super.key,
  });

  final String label;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AuthColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AuthColors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class AuthLogoMark extends StatelessWidget {
  const AuthLogoMark({
    this.size = 104,
    this.padding = const EdgeInsets.all(22),
    super.key,
  });

  final double size;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Image.asset('assets/branding/dufuth_logo.png'),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            Color.fromARGB(
              ((color.a * 255) * 0.24).round().clamp(0, 255).toInt(),
              (color.r * 255).round().clamp(0, 255).toInt(),
              (color.g * 255).round().clamp(0, 255).toInt(),
              (color.b * 255).round().clamp(0, 255).toInt(),
            ),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _SoftDot extends StatelessWidget {
  const _SoftDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x1F8EC5FF),
      ),
    );
  }
}
