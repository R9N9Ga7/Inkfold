import 'package:flutter/material.dart';

enum ReaderPalette { day, paper, night }
enum AppAppearance { system, light, dark }

final class ReadingPreferences {
  const ReadingPreferences({
    this.palette = ReaderPalette.paper,
    this.appAppearance = AppAppearance.system,
    this.fontSize = 19,
    this.lineHeight = 1.65,
    this.pageWidth = 720,
    this.textAlign = TextAlign.left,
  });

  final ReaderPalette palette;
  final AppAppearance appAppearance;
  final double fontSize;
  final double lineHeight;
  final double pageWidth;
  final TextAlign textAlign;

  ReadingPreferences copyWith({
    ReaderPalette? palette,
    AppAppearance? appAppearance,
    double? fontSize,
    double? lineHeight,
    double? pageWidth,
    TextAlign? textAlign,
  }) => ReadingPreferences(
    palette: palette ?? this.palette,
    appAppearance: appAppearance ?? this.appAppearance,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    pageWidth: pageWidth ?? this.pageWidth,
    textAlign: textAlign ?? this.textAlign,
  );
}
