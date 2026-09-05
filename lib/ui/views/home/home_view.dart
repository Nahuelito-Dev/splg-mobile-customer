import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stacked/stacked.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

import 'home_viewmodel.dart';
import 'package:splg_customer/ui/widgets/common/order/order.dart';
import 'package:splg_customer/ui/widgets/common/history/history.dart';
import 'package:splg_customer/ui/widgets/common/account/account.dart';

class HomeView extends StackedView<HomeViewModel> {
  const HomeView({super.key});

  @override
  Widget builder(BuildContext context, HomeViewModel viewModel, Widget? child) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: IndexedStack(
            index: viewModel.currentIndex,
            sizing: StackFit.expand,
            children: const [
              History(),
              Order(),
              Account(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: viewModel.currentIndex,
        elevation: 4,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          HapticFeedback.lightImpact();
          viewModel.setIndex(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(BootstrapIcons.person_gear),
            label: '',
          ),
        ],
      ),
    );
  }

  @override
  HomeViewModel viewModelBuilder(BuildContext context) => HomeViewModel();
}
