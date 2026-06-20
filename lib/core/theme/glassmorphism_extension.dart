import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphismThemeExtension
    extends ThemeExtension<GlassmorphismThemeExtension> {
  final Color? color;
  final Color? borderColor;
  final double? blur;

  const GlassmorphismThemeExtension({
    this.color,
    this.borderColor,
    this.blur,
  });

  @override
  GlassmorphismThemeExtension copyWith({
    Color? color,
    Color? borderColor,
    double? blur,
  }) {
    return GlassmorphismThemeExtension(
      color: color ?? this.color,
      borderColor: borderColor ?? this.borderColor,
      blur: blur ?? this.blur,
    );
  }

  @override
  GlassmorphismThemeExtension lerp(
    covariant ThemeExtension<GlassmorphismThemeExtension>? other,
    double t,
  ) {
    if (other is! GlassmorphismThemeExtension) {
      return this;
    }
    return GlassmorphismThemeExtension(
      color: Color.lerp(color, other.color, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      blur: lerpDouble(blur, other.blur, t),
    );
  }

  static const light = GlassmorphismThemeExtension(
    color: Color(0x66FFFFFF),
    borderColor: Color(0x1F000000),
    blur: 15.0,
  );

  static const dark = GlassmorphismThemeExtension(
    color: Color(0x1F000000),
    borderColor: Color(0x1AFFFFFF),
    blur: 20.0,
  );

  static const amoled = GlassmorphismThemeExtension(
    color: Color(0x1F121212),
    borderColor: Color(0x1F888888),
    blur: 10.0,
  );
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassContainer({
    required this.child,
    super.key,
    this.width,
    this.height,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final glassTheme = Theme.of(context).extension<GlassmorphismThemeExtension>() ??
        GlassmorphismThemeExtension.dark;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: glassTheme.blur ?? 20.0,
            sigmaY: glassTheme.blur ?? 20.0,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: glassTheme.color,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: glassTheme.borderColor ?? Colors.white.withAlpha(20),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
