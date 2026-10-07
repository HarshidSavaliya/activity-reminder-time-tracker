import 'package:flutter/material.dart';

/// AppDimensions implements a consistent 8px grid spacing system
/// and predictable border radii across the application.
class AppDimensions {
  AppDimensions._();

  // Spacing (8px grid scale)
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // Insets
  static const EdgeInsets padding4 = EdgeInsets.all(space4);
  static const EdgeInsets padding8 = EdgeInsets.all(space8);
  static const EdgeInsets padding12 = EdgeInsets.all(space12);
  static const EdgeInsets padding16 = EdgeInsets.all(space16);
  static const EdgeInsets padding20 = EdgeInsets.all(space20);
  static const EdgeInsets padding24 = EdgeInsets.all(space24);
  static const EdgeInsets padding32 = EdgeInsets.all(space32);

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: space20,
    vertical: space16,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(space16);
  static const EdgeInsets dialogPadding = EdgeInsets.all(space24);

  // Border Radii (Curved Organic Shapes from Mockup)
  static const double radiusSm = 10.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 22.0;
  static const double radiusXl = 28.0;
  static const double radiusFull = 999.0;

  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius borderRadiusFull = BorderRadius.all(Radius.circular(radiusFull));

  // Component Sizes
  static const double buttonHeight = 50.0;
  static const double inputHeight = 52.0;
  static const double avatarSizeSm = 36.0;
  static const double avatarSizeMd = 48.0;
  static const double avatarSizeLg = 80.0;
  static const double iconSizeSm = 18.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;

  // Max content width for responsive desktop/tablet layouts
  static const double maxContentWidth = 600.0;
}
