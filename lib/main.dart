import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'providers/punch_provider.dart';
import 'screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.provider});

  final PunchProvider? provider;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => provider ?? PunchProvider(),
        child: MaterialApp(
          title: '打卡记',
          debugShowCheckedModeBanner: false,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildAppTheme(),
          home: const HomePage(),
        ),
      );
}