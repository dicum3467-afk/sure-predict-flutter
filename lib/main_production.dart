import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const k = String.fromEnvironment('APIFOOTBALL_KEY');
  // ignore: avoid_print
  print('APIFOOTBALL_KEY prefix: ${k.isEmpty ? "EMPTY" : k.substring(0, 4)}');

  runApp(const SurePredictApp());
}import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SurePredictApp());
}
