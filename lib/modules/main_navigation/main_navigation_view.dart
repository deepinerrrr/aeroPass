import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../home/home_view.dart';
import '../tools/tools_view.dart';
import '../settings/settings_view.dart';

class MainNavigationController extends GetxController {
  final currentIndex = 0.obs;

  void changePage(int index) {
    currentIndex.value = index;
  }
}

class MainNavigationView extends StatelessWidget {
  const MainNavigationView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MainNavigationController());

    final pages = [
      const HomeView(),
      const ToolsView(),
      const SettingsView(),
    ];

    final items = <Widget>[
      Icon(Icons.home_rounded, size: 26, color: Colors.white),
      Icon(Icons.apps_rounded, size: 26, color: Colors.white),
      Icon(Icons.settings_rounded, size: 26, color: Colors.white),
    ];

    return Obx(() => Scaffold(
      extendBody: true,
      body: pages[controller.currentIndex.value],
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          iconTheme: IconThemeData(color: Colors.white),
        ),
        child: CurvedNavigationBar(
          index: controller.currentIndex.value,
          height: 60,
          items: items,
          color: Get.theme.colorScheme.primary,
          buttonBackgroundColor: Get.theme.colorScheme.primary,
          backgroundColor: Colors.transparent,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 400),
          onTap: (index) => controller.changePage(index),
          letIndexChange: (index) => true,
        ),
      ),
    ));
  }
}
