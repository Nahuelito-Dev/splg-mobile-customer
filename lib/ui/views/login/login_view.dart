import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked/stacked_annotations.dart';

import 'package:splg_customer/ui/common/app_strings.dart';
import 'package:splg_customer/ui/views/login/login_view.form.dart';

import 'login_viewmodel.dart';

@FormView(fields: [
  FormTextField(
    name: 'email',
  ),
  FormTextField(
    name: 'password',
  ),
])
class LoginView extends StackedView<LoginViewModel> with $LoginView {
  const LoginView({super.key});

  @override
  Widget builder(
    BuildContext context,
    LoginViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 78,
                        ),
                        const SizedBox(height: 46),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(
                                top: 36, bottom: 28, left: 24, right: 24),
                            child: _buildEmailAndPassword(context, viewModel),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSignUpButton(context, viewModel),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailAndPassword(
      BuildContext context, LoginViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;

    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.outline.withAlpha(70),
        ));

    return Column(
      children: [
        TextFormField(
          controller: emailController,
          focusNode: emailFocusNode,
          enabled: !viewModel.isBusy,
          decoration: InputDecoration(
              fillColor: Theme.of(context).colorScheme.surface,
              prefixIcon: Icon(Icons.email_outlined,
                  color: colorScheme.outline.withAlpha(70)),
              hintText: loginViewHintEmail,
              hintStyle: TextStyle(color: colorScheme.outline.withAlpha(70)),
              border: border,
              enabledBorder: border,
              disabledBorder: border,
              errorText: viewModel.emaileError),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: passwordController,
          focusNode: passwordFocusNode,
          enabled: !viewModel.isBusy,
          decoration: InputDecoration(
              fillColor: Theme.of(context).colorScheme.surface,
              prefixIcon: Icon(Icons.lock_outline,
                  color: colorScheme.outline.withAlpha(70)),
              hintText: loginViewHintPassword,
              hintStyle: TextStyle(color: colorScheme.outline.withAlpha(70)),
              border: border,
              enabledBorder: border,
              disabledBorder: border,
              errorText: viewModel.passwordError,
              suffixIcon: IconButton(
                onPressed: viewModel.togglePasswordVisibility,
                icon: Icon(
                    viewModel.isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: colorScheme.outline.withAlpha(70)),
              )),
          obscureText: !viewModel.isPasswordVisible,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 42),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: !viewModel.isBusy
              ? () {
                  FocusScope.of(context).unfocus();
                  viewModel.onLogin();
                }
              : null,
          child: const Text(
            loginViewButton,
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton(BuildContext context, LoginViewModel viewModel) {
    return TextButton(
      onPressed: !viewModel.isBusy ? viewModel.navigateToSignup : null,
      child: Text.rich(
        TextSpan(
          text: loginViewNoAccount,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
          children: [
            TextSpan(
              text: loginViewSignup,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  LoginViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      LoginViewModel();

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
