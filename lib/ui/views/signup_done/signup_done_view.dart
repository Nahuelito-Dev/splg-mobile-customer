import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';

class SignupDoneViewModel extends BaseViewModel {
  Future<void> goHome() async {
    await locator<NavigationService>().clearStackAndShow(Routes.homeView);
  }
}

/// "Registro completado" sobre el degradé de marca.
class SignupDoneView extends StackedView<SignupDoneViewModel> {
  const SignupDoneView({super.key});

  @override
  SignupDoneViewModel viewModelBuilder(BuildContext context) =>
      SignupDoneViewModel();

  @override
  Widget builder(
      BuildContext context, SignupDoneViewModel model, Widget? child) {
    final type = SplgType.of(context);
    return Scaffold(
      body: SplgGradientBackground(
        gradient: SplgGradients.splash,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SplgIllustration.success.image(height: context.sp(110)),
                      SizedBox(height: context.sp(14)),
                      Text('¡Registro completado!',
                          textAlign: TextAlign.center,
                          style: type.title.copyWith(
                              color: Colors.white, fontSize: context.sp(18))),
                      const SizedBox(height: 10),
                      Text(
                        'Tu cuenta está lista. Ya podés pedir tus garrafas.',
                        textAlign: TextAlign.center,
                        style: type.body.copyWith(
                            color: Colors.white, fontSize: context.sp(13)),
                      ),
                    ],
                  ),
                ),
                SplgButton(
                  title: 'Ir al inicio',
                  style: SplgButtonStyle.white,
                  onPressed: model.goHome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
