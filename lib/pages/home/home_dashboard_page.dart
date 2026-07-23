// 文件说明：首页路由标记，并复用统一的响应式首页实现。

import 'package:flutter/material.dart';

import 'home_mobile_dashboard_page.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key, this.controller});

  final HomeDashboardController? controller;

  @override
  Widget build(BuildContext context) =>
      HomeMobileDashboardPage(controller: controller);
}
