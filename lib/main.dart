import 'package:flutter/material.dart';
import 'prayertime.dart';

void main() {
  runApp(PrayerTimesApp());
}

class PrayerTimesApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prayer Times',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: PrayerTimesScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}