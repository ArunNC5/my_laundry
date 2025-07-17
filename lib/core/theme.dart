import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  primarySwatch: Colors.indigo,
  scaffoldBackgroundColor: Colors.grey[100],
  fontFamily: 'DMSans',
  visualDensity: VisualDensity.adaptivePlatformDensity,

  appBarTheme: AppBarTheme(
    elevation: 0,
    backgroundColor: Colors.transparent,
    centerTitle: true,
    iconTheme: IconThemeData(color: Colors.white),
    // white back button
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      fontFamily: 'DMSans',
    ),
  ),

  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 6,
    shadowColor: Colors.black12,
    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    labelStyle: TextStyle(fontWeight: FontWeight.w500),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
      elevation: 3,
      padding: EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    ),
  ),

  textTheme: TextTheme(
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  ),
);
