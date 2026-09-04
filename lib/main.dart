import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/pdf_font_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledPdfFontLicense();
  runApp(const ProviderScope(child: InkfoldApp()));
}
