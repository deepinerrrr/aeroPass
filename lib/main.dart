import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/routes.dart';
import 'core/routes/pages.dart';
import 'modules/home/home_controller.dart';
import 'modules/update/app_update_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LicenseApp());
}

class LicenseApp extends StatefulWidget {
  const LicenseApp({super.key});

  @override
  State<LicenseApp> createState() => _LicenseAppState();
}

class _LicenseAppState extends State<LicenseApp> {
  @override
  void initState() {
    super.initState();
    final updateController = Get.put(AppUpdateController(), permanent: true);
    updateController.scheduleStartupCheck();
  }

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.put(SettingsController(), permanent: true);
    return GetMaterialApp(
      title: 'areoPass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.createTheme(
        settingsController.currentThemeColor.color,
        Brightness.light,
      ),
      darkTheme: AppTheme.createTheme(
        settingsController.currentThemeColor.color,
        Brightness.dark,
      ),
      themeMode: settingsController.isDarkMode.value
          ? ThemeMode.dark
          : ThemeMode.light,
      initialRoute: Routes.main,
      getPages: AppPages.pages,
    );
  }
}
