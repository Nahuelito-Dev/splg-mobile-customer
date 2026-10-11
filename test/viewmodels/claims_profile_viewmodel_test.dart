import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/my_claim.dart';
import 'package:splg_customer/services/claim_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/session_service.dart';
import 'package:splg_customer/ui/views/claims/claims_viewmodel.dart';
import 'package:splg_customer/ui/views/edit_profile/edit_profile_viewmodel.dart';
import 'package:splg_customer/ui/views/profile/profile_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

MyClaim claim(String id) => MyClaim(
      claimId: id,
      status: ClaimStatus.pending,
      reason: 'No llegó el pedido',
      description: 'd',
      createdAt: DateTime(2026, 10, 10),
      orderId: 'o1',
    );

void main() {
  late MockClaimService claims;
  late MockCustomerService customers;
  late MockNavigationService nav;

  setUp(() {
    registerServices();
    claims = locator<ClaimService>() as MockClaimService;
    customers = locator<CustomerService>() as MockCustomerService;
    nav = locator<NavigationService>() as MockNavigationService;
    when(customers.customer).thenReturn(customerWith());
  });
  tearDown(() => locator.reset());

  group('ClaimsViewModel', () {
    test('carga la primera página y sabe si hay más', () async {
      when(claims.fetchMine(limit: 20, offset: 0)).thenAnswer((_) async =>
          ApiResult.ok(ClaimsPage(claims: [claim('1'), claim('2')], total: 3)));
      final m = ClaimsViewModel();
      await m.load();
      expect(m.claims, hasLength(2));
      expect(m.hasMore, isTrue);
    });

    test('ver más agrega con el offset de lo ya cargado', () async {
      when(claims.fetchMine(limit: 20, offset: 0)).thenAnswer((_) async =>
          ApiResult.ok(ClaimsPage(claims: [claim('1'), claim('2')], total: 3)));
      when(claims.fetchMine(limit: 20, offset: 2)).thenAnswer((_) async =>
          ApiResult.ok(ClaimsPage(claims: [claim('3')], total: 3)));
      final m = ClaimsViewModel();
      await m.load();
      await m.loadMore();
      expect(m.claims.map((c) => c.claimId), ['1', '2', '3']);
      expect(m.hasMore, isFalse);
    });

    test('si falla traer más conserva la lista y muestra el error', () async {
      when(claims.fetchMine(limit: 20, offset: 0)).thenAnswer((_) async =>
          ApiResult.ok(ClaimsPage(claims: [claim('1')], total: 5)));
      when(claims.fetchMine(limit: 20, offset: 1)).thenAnswer((_) async =>
          const ApiResult.fail('Sin conexión. Revisá tu internet.'));
      final m = ClaimsViewModel();
      await m.load();
      await m.loadMore();
      expect(m.claims, hasLength(1));
      expect(m.moreError, 'Sin conexión. Revisá tu internet.');
    });

    test('si falla la primera carga ofrece reintentar con el texto del error',
        () async {
      when(claims.fetchMine(limit: 20, offset: 0)).thenAnswer((_) async =>
          const ApiResult.fail('No tenés permiso para hacer esto.'));
      final m = ClaimsViewModel();
      await m.load();
      expect(m.loadError, 'No tenés permiso para hacer esto.');
    });
  });

  group('MyClaim.fromJson', () {
    test('lee el contrato de GET /claims/mine', () {
      final c = MyClaim.fromJson({
        'claimId': 'c1',
        'status': 'in_process',
        'reason': 'Fuga',
        'description': 'Huele a gas',
        'createdAt': '2026-10-10T20:00:00.000Z',
        'order': {'orderId': 'o9', 'totalAmount': 14900},
        'photoUrl': null,
        'resolutionNote': null,
      });
      expect(c.status, ClaimStatus.inProcess);
      expect(c.orderId, 'o9');
      expect(c.orderTotal, 14900);
      expect(ClaimStatus.parse('resolved'), ClaimStatus.resolved);
      expect(ClaimStatus.parse('rejected'), ClaimStatus.rejected);
      expect(ClaimStatus.parse('lo que sea'), ClaimStatus.pending);
    });
  });

  group('ProfileViewModel - eliminar cuenta', () {
    test('con pedido en curso (409) muestra el motivo y no sale de la app',
        () async {
      when(customers.deleteAccount()).thenAnswer((_) async =>
          const ApiResult.fail(
              'Tenés un pedido en curso. Esperá o cancelalo.'));
      final m = ProfileViewModel();

      final deleted = await m.deleteAccount();

      expect(deleted, isFalse);
      expect(m.deleteError, 'Tenés un pedido en curso. Esperá o cancelalo.');
      verifyNever(nav.clearStackAndShow(any));
      expect(m.isBusy, isFalse);
    });

    test('si se elimina, limpia la sesión y vuelve a la bienvenida', () async {
      when(customers.deleteAccount())
          .thenAnswer((_) async => const ApiResult.ok());
      final session = locator<SessionService>() as MockSessionService;
      final deleted = await ProfileViewModel().deleteAccount();
      expect(deleted, isTrue);
      verify(session.endSession()).called(1);
      verify(nav.clearStackAndShow(Routes.welcomeView)).called(1);
    });

    test(
        'un 401 al eliminar (la baja pudo haberse hecho) cierra la sesión '
        'con un mensaje claro', () async {
      when(customers.deleteAccount()).thenAnswer(
          (_) async => const ApiResult.fail('Tu sesión venció.', status: 401));
      final session = locator<SessionService>() as MockSessionService;
      final deleted = await ProfileViewModel().deleteAccount();
      expect(deleted, isFalse);
      final msg = verify(session.expire(message: captureAnyNamed('message')))
          .captured
          .single as String;
      expect(msg, contains('Si tu cuenta ya se había eliminado'));
      verifyNever(nav.clearStackAndShow(any));
    });

    test('las iniciales salen del nombre', () {
      expect(ProfileViewModel().initials, 'AP');
    });
  });

  group('EditProfileViewModel', () {
    test('precarga el nombre y el teléfono sin el +54', () {
      final m = EditProfileViewModel();
      expect(m.name.text, 'Ana Pérez');
      expect(m.phone.text, '93815550003');
    });

    test('valida y guarda con el teléfono en E.164', () async {
      when(customers.updateProfile(
              fullName: anyNamed('fullName'),
              phoneNumber: anyNamed('phoneNumber')))
          .thenAnswer((_) async => const ApiResult.ok());
      final m = EditProfileViewModel();
      m.name.text = 'A';
      await m.save();
      expect(m.nameError, isNotNull);

      m.name.text = 'Ana Gómez';
      m.phone.text = '381 555 0004';
      await m.save();
      verify(customers.updateProfile(
              fullName: 'Ana Gómez', phoneNumber: '+543815550004'))
          .called(1);
      verify(nav.back(result: true)).called(1);
    });

    test('un error del back queda visible', () async {
      when(customers.updateProfile(
              fullName: anyNamed('fullName'),
              phoneNumber: anyNamed('phoneNumber')))
          .thenAnswer((_) async =>
              const ApiResult.fail('Ese teléfono ya está en uso.'));
      final m = EditProfileViewModel();
      await m.save();
      expect(m.errorMessage, 'Ese teléfono ya está en uso.');
      verifyNever(nav.back(result: anyNamed('result')));
    });
  });
}
