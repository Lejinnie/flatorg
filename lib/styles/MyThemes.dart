import 'package:flatorg/styles/Colors.dart';
import 'package:flutter/material.dart';

class Mythemes {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    // primaryColor: Colors.blue,
    fontFamily: 'Montserrat',
    colorScheme: ColorScheme.fromSwatch(
      backgroundColor: MyColors.background,
      brightness: Brightness.light,
      accentColor: MyColors.highlight,
    ),
    // Define additional light theme properties here
  );
  static final ThemeData darkTheme = ThemeData(
    // brightness: Brightness.dark,
    // primaryColor: Colors.grey[900],
    fontFamily: 'Montserrat',
    colorScheme: ColorScheme.fromSwatch(
      backgroundColor: MyColors.background,
      brightness: Brightness.dark,
      accentColor: MyColors.highlight,
    ),
    // Define additional dark theme properties here
  );
}
