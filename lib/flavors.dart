enum Flavor {
  devfoss,
  prodfoss,
  devfull,
  prodfull,
}

class F {
  static late final Flavor appFlavor;

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
      case Flavor.devfoss:
        return 'Melodrift Dev FOSS';
      case Flavor.prodfoss:
        return 'Melodrift FOSS';
      case Flavor.devfull:
        return 'Melodrift Dev';
      case Flavor.prodfull:
        return 'Melodrift';
    }
  }

  static bool get isFoss => appFlavor == Flavor.devfoss || appFlavor == Flavor.prodfoss;
  static bool get isFull => appFlavor == Flavor.devfull || appFlavor == Flavor.prodfull;
}
