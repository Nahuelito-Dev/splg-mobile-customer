import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/services/app_permissions.dart';
import 'package:splg_lib/permissions/app_permission.dart';
import 'package:splg_lib/permissions/permission_copy.dart';
import 'package:splg_lib/permissions/permission_gateway.dart';
import 'package:splg_lib/permissions/permission_prompter.dart';

class _Gateway implements PermissionGateway {
  @override
  Future<PermissionOutcome> status(AppPermission p) async =>
      PermissionOutcome.denied;

  @override
  Future<PermissionOutcome> request(AppPermission p) async =>
      PermissionOutcome.granted;

  @override
  Future<bool> openSettings() async => true;
}

class _Prompter implements PermissionPrompter {
  final List<String> rationales = [];

  @override
  Future<bool> explain(AppPermission p, PermissionCopy copy) async {
    rationales.add(copy.rationale);
    return true;
  }

  @override
  Future<bool> denied(AppPermission p, PermissionCopy copy) async => false;

  @override
  Future<bool> openSettings(AppPermission p, PermissionCopy copy) async =>
      false;
}

void main() {
  test('el texto de la cámara depende del uso: QR o foto', () async {
    final prompter = _Prompter();
    final perms = AppPermissions(gateway: _Gateway(), prompter: prompter);

    await perms.ensure(AppPermission.camera);
    await perms.ensureCameraForPhoto();

    expect(prompter.rationales, hasLength(2));
    expect(prompter.rationales[0], contains('código QR'));
    expect(prompter.rationales[0], isNot(contains('foto')));
    expect(prompter.rationales[1], contains('foto'));
    expect(prompter.rationales[1], isNot(contains('QR')));
  });
}
