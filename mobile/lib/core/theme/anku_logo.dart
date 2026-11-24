import 'package:flutter/widgets.dart';

class AnkuLogo extends StatelessWidget {
  const AnkuLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/anku_logo.png',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}
