import 'package:flatorg/HomepageWrapper.dart';
import 'package:flutter/material.dart';

import 'styles/Colors.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlatOrg',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: MyColors.background),
        fontFamily: 'Montserrat',
      ),
      home: HomepageWrapper(title: "todo: title"),
    );
  }
}
