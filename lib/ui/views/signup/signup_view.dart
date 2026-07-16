import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked/stacked_annotations.dart';

import 'package:jennigas_customer/ui/common/app_strings.dart';
import 'package:jennigas_customer/ui/widgets/common/input/text_input.dart';
import 'package:jennigas_customer/ui/views/signup/signup_view.form.dart';

import 'signup_viewmodel.dart';

@FormView(fields: [
  FormTextField(name: 'name'),
  FormTextField(name: 'email'),
  FormTextField(name: 'password'),
  FormTextField(name: 'phone'),
])
class SignupView extends StackedView<SignupViewModel> with $SignupView {
  const SignupView({super.key});

  @override
  Widget builder(
    BuildContext context,
    SignupViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: true,
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
                            child: _buildForm(context, viewModel),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildLoginButton(context, viewModel),
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

  Widget _buildForm(BuildContext context, SignupViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        TextInput(
          controller: nameController,
          focusNode: nameFocusNode,
          enabled: !viewModel.isBusy,
          hintText: signupViewName,
          errorText: viewModel.nameError,
          textInputAction: TextInputAction.next,
          prefixIcon: Icon(Icons.person_outline,
              color: colorScheme.outline.withAlpha(70)),
        ),
        const SizedBox(height: 16),
        TextInput(
          controller: emailController,
          focusNode: emailFocusNode,
          enabled: !viewModel.isBusy,
          hintText: loginViewHintEmail,
          errorText: viewModel.emailError,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icon(Icons.email_outlined,
              color: colorScheme.outline.withAlpha(70)),
        ),
        const SizedBox(height: 16),
        TextInput(
          controller: passwordController,
          focusNode: passwordFocusNode,
          enabled: !viewModel.isBusy,
          hintText: loginViewHintPassword,
          errorText: viewModel.passwordError,
          textInputAction: TextInputAction.next,
          obscureText: !viewModel.isPasswordVisible,
          prefixIcon: Icon(Icons.lock_outline,
              color: colorScheme.outline.withAlpha(70)),
          suffixIcon: IconButton(
            onPressed: viewModel.togglePasswordVisibility,
            icon: Icon(
              viewModel.isPasswordVisible
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: colorScheme.outline.withAlpha(70),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextInput(
          controller: phoneController,
          focusNode: phoneFocusNode,
          enabled: !viewModel.isBusy,
          hintText: signupViewPhoneHint,
          errorText: viewModel.phoneError,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.phone,
          prefixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 12),
              Icon(Icons.phone_outlined,
                  color: colorScheme.outline.withAlpha(70)),
              const SizedBox(width: 8),
              Text('+54',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  )),
              const SizedBox(width: 4),
            ],
          ),
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
                  viewModel.onRegister();
                }
              : null,
          child: const Text(
            signupViewTitle,
          ),
        ),
        const SizedBox(height: 16),
        _buildLegalNotice(context, viewModel),
      ],
    );
  }

  Widget _buildLegalNotice(BuildContext context, SignupViewModel viewModel) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final linkStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.bold,
    );

    return Text.rich(
      TextSpan(
        text: 'Al registrarte, aceptás nuestros ',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withAlpha(170),
        ),
        children: [
          TextSpan(
            text: 'Términos y Condiciones',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = viewModel.navigateToTerms,
          ),
          const TextSpan(text: ' y nuestra '),
          TextSpan(
            text: 'Política de Privacidad',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = viewModel.navigateToPrivacyPolicy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLoginButton(BuildContext context, SignupViewModel viewModel) {
    return TextButton(
      onPressed: !viewModel.isBusy ? viewModel.navigateToLogin : null,
      child: Text.rich(
        TextSpan(
          text:
              "¿Ya tienes cuenta? ", // Generic text, usually in strings but I'll use hardcoded if not found or make it consistent
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
          children: [
            TextSpan(
              text: signupViewLoginButton,
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
  SignupViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      SignupViewModel();

  @override
  void onViewModelReady(SignupViewModel viewModel) {
    syncFormWithViewModel(viewModel);
  }

  @override
  void onDispose(SignupViewModel viewModel) {
    super.onDispose(viewModel);
    disposeForm();
  }
}
