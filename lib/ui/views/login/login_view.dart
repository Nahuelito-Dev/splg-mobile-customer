import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked/stacked_annotations.dart';

import 'package:splg_customer/ui/common/app_strings.dart';
import 'package:splg_customer/ui/common/status_bar.dart';

import 'login_view.form.dart';
import 'login_viewmodel.dart';

@FormView(
  fields: [
    FormTextField(name: 'email'),
    FormTextField(name: 'password'),
  ],
)
class LoginView extends StackedView<LoginViewModel> with $LoginView {
  const LoginView({super.key});

  @override
  Widget builder(
    BuildContext context,
    LoginViewModel viewModel,
    Widget? child,
  ) {
    final type = SplgType.of(context);
    final hasError = viewModel.errorMessage != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) viewModel.onBack();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: StatusBarRegion.surface(
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      key: const Key('login-volver'),
                      tooltip: 'Volver',
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      icon: Icon(
                        SplgIcons.back,
                        size: 26,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: viewModel.isBusy ? null : viewModel.onBack,
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: context.sp(10)),
                      child: Center(
                        child: SplgIllustration.mailSent.image(
                          height: context.sp(150),
                        ),
                      ),
                    ),
                    Text(
                      '¡Hola!',
                      style: type.title.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SplgTextField(
                      controller: emailController,
                      focusNode: emailFocusNode,
                      enabled: !viewModel.isBusy,
                      hint: loginViewHintEmail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 15),
                    SplgTextField(
                      controller: passwordController,
                      focusNode: passwordFocusNode,
                      enabled: !viewModel.isBusy,
                      hint: loginViewHintPassword,
                      obscure: !viewModel.showPassword,
                      textInputAction: TextInputAction.done,
                      suffixIcon: IconButton(
                        tooltip: viewModel.showPassword
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        icon: Icon(
                          viewModel.showPassword
                              ? SplgIcons.eyeOff
                              : SplgIcons.eye,
                          size: 22,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: viewModel.togglePasswordVisibility,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: viewModel.isBusy
                            ? null
                            : viewModel.onForgotPassword,
                        child: Text(
                          loginViewForgotPassword,
                          style: type.action.copyWith(
                            fontSize: context.sp(10),
                          ),
                        ),
                      ),
                    ),
                    if (hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          viewModel.errorMessage!,
                          textAlign: TextAlign.center,
                          style:
                              type.body.copyWith(color: context.brasa.danger),
                        ),
                      ),
                    SplgButton(
                      title: loginViewButton,
                      loading: viewModel.isBusy,
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        viewModel.onLogin();
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(loginViewNoAccount, style: type.caption),
                        InkWell(
                          onTap: viewModel.isBusy ? null : viewModel.onSignup,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              loginViewSignup,
                              style: type.action.copyWith(
                                fontSize: context.sp(10),
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(40)),
                    Center(child: SplgLogo(height: context.sp(14))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  LoginViewModel viewModelBuilder(BuildContext context) => LoginViewModel();

  @override
  void onViewModelReady(LoginViewModel viewModel) {
    syncFormWithViewModel(viewModel);
  }

  @override
  void onDispose(LoginViewModel viewModel) {
    super.onDispose(viewModel);
    disposeForm();
  }
}
