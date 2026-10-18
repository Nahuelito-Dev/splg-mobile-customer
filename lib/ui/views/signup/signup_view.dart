import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'signup_viewmodel.dart';

class SignupView extends StackedView<SignupViewModel> {
  const SignupView({super.key});

  @override
  SignupViewModel viewModelBuilder(BuildContext context) => SignupViewModel();

  @override
  Widget builder(BuildContext context, SignupViewModel model, Widget? child) {
    final type = SplgType.of(context);
    final brasa = context.brasa;

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(t, style: type.label.copyWith(fontSize: context.sp(11))),
        );

    final step1 = [
      label('Nombre y apellido'),
      SplgTextField(
        key: const Key('signup-name'),
        controller: model.name,
        enabled: !model.isBusy,
        hint: 'Ingresá tu nombre y apellido',
        errorText: model.nameError,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
      ),
      label('Teléfono'),
      SplgPhoneField(
        key: const Key('signup-phone'),
        controller: model.phone,
        enabled: !model.isBusy,
        errorText: model.phoneError,
      ),
      const SizedBox(height: 14),
      Text('*Todos los campos son obligatorios', style: type.caption),
    ];

    final step2 = [
      label('Correo electrónico'),
      SplgTextField(
        key: const Key('signup-email'),
        controller: model.email,
        enabled: !model.isBusy,
        hint: 'Ingresá tu email',
        errorText: model.emailError,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
      ),
      const SizedBox(height: 10),
      KeyedSubtree(
        key: const Key('signup-password'),
        child: SplgPasswordField(
          label: 'Contraseña',
          controller: model.password,
          enabled: !model.isBusy,
          errorText: model.passwordError,
          status: model.passwordError == null
              ? SplgFieldStatus.neutral
              : SplgFieldStatus.invalid,
          textInputAction: TextInputAction.next,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('Usá al menos 8 caracteres, una mayúscula y un número.',
            style: type.caption),
      ),
      const SizedBox(height: 10),
      KeyedSubtree(
        key: const Key('signup-repeat'),
        child: SplgPasswordField(
          label: 'Repetir contraseña',
          controller: model.repeat,
          enabled: !model.isBusy,
          errorText: model.repeatError,
          status: model.repeatError == null
              ? SplgFieldStatus.neutral
              : SplgFieldStatus.invalid,
        ),
      ),
      const SizedBox(height: 8),
      SplgCheckboxLink(
        label: 'Aceptar Términos y condiciones',
        value: model.acceptedTerms,
        onChanged: model.setTerms,
        onLink: model.openTerms,
      ),
      SplgCheckboxLink(
        label: 'Aceptar Política de privacidad',
        value: model.acceptedPrivacy,
        onChanged: model.setPrivacy,
        onLink: model.openPrivacy,
      ),
      if (model.generalError != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(model.generalError!,
              key: const Key('signup-error'),
              style: type.body.copyWith(color: brasa.danger)),
        ),
    ];

    final step3 = [
      label('Garrafa habitual (opcional)'),
      if (model.loadingCylinders)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SplgLoader(),
        )
      else if (model.cylinders.isEmpty)
        Text('No pudimos traer las garrafas. Podés omitir este paso.',
            style: type.caption)
      else
        SplgChoiceChips(
          labels: [for (final g in model.cylinders) g.label],
          selected: model.cylinders
              .indexWhere((g) => g.id == model.consumptionCylinderId),
          onSelected: (i) =>
              model.selectConsumptionCylinder(model.cylinders[i].id),
        ),
      label('Garrafas por mes'),
      SplgTextField(
        key: const Key('signup-consumption'),
        controller: model.consumptionQuantity,
        enabled: !model.isBusy,
        hint: 'Ej.: 2',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      if (model.consumptionError != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(model.consumptionError!,
              key: const Key('signup-consumption-error'),
              style: type.body.copyWith(color: brasa.danger)),
        ),
      if (model.generalError != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(model.generalError!,
              key: const Key('signup-error'),
              style: type.body.copyWith(color: brasa.danger)),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
            'Con esto estimamos cuándo se te termina el gas. Podés cambiarlo '
            'después en tu perfil.',
            style: type.caption),
      ),
    ];

    return PopScope(
      canPop: model.step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) model.back();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Column(
            children: [
              Stack(
                children: [
                  const SplgIllustrationHeader(
                      illustration: SplgIllustration.recoverPassword),
                  SafeArea(
                    child: IconButton(
                      tooltip: 'Volver',
                      icon: const Icon(SplgIcons.back,
                          size: 24, color: Colors.white),
                      onPressed: model.back,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Registro',
                          style: type.title.copyWith(fontSize: context.sp(16))),
                      const SizedBox(height: 4),
                      Text(
                          switch (model.step) {
                            0 => '1. Tus datos',
                            1 => '2. Tu cuenta',
                            _ => '3. Tu consumo (opcional)',
                          },
                          style: type.subtitle),
                      ...switch (model.step) {
                        0 => step1,
                        1 => step2,
                        _ => step3,
                      },
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SplgStepDots(
                          count: SignupViewModel.stepCount,
                          current: model.step),
                      const SizedBox(height: 12),
                      SplgButton(
                        title: model.step < SignupViewModel.stepCount - 1
                            ? 'Siguiente'
                            : 'Registrarme',
                        loading: model.isBusy,
                        onPressed: model.next,
                      ),
                      if (model.step == SignupViewModel.stepCount - 1)
                        TextButton(
                          key: const Key('signup-skip-consumption'),
                          onPressed:
                              model.isBusy ? null : model.skipConsumption,
                          child: const Text('Omitir y registrarme'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
