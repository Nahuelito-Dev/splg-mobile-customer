import 'package:splg_lib/network/api_error_text.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/data/datasource/order_remote_datasource.dart';
import 'package:splg_customer/data/datasource/repurchase_remote_datasource.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/repurchase.dart';
import 'package:splg_customer/services/customer_service.dart';

/// Recompra anticipada (M3): mi fecha estimada, cómo quiero el aviso y las
/// invitaciones a reponer. Con el módulo apagado no hay invitaciones y la app
/// no muestra nada.
class RepurchaseService {
  /// [datasource], [tokenReader] y [keys] sólo se inyectan en los tests.
  RepurchaseService({
    RepurchaseRemoteDatasource? datasource,
    OrderRemoteDatasource? orders,
    Future<String?> Function()? tokenReader,
    IdempotencyKeys? keys,
  })  : _remote = datasource ?? RepurchaseRemoteDatasource(),
        _orders = orders ?? OrderRemoteDatasource(),
        _tokenReader = tokenReader,
        _keys = keys ?? IdempotencyKeys();

  final RepurchaseRemoteDatasource _remote;
  final OrderRemoteDatasource _orders;
  final Future<String?> Function()? _tokenReader;
  final IdempotencyKeys _keys;

  Future<String?> _token() {
    final read = _tokenReader;
    return read != null ? read() : locator<CustomerService>().token;
  }

  Future<ApiResult<T>> _withToken<T>(
    Future<ApiResult<dynamic>> Function(String token) call,
    T? Function(dynamic data) parse,
  ) async {
    final token = await _token();
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final r = await call(token);
    if (!r.ok) return ApiResult.fail(r.message!, status: r.status, body: r.body);
    final parsed = parse(r.data);
    return parsed == null
        ? const ApiResult.fail(ApiErrorText.generic)
        : ApiResult.ok(parsed);
  }

  /// `GET /customers/me/repurchase`: fecha estimada, aviso e invitación abierta.
  Future<ApiResult<RepurchaseForecast>> forecast() =>
      _withToken(_remote.forecast, RepurchaseForecast.fromJson);

  /// `GET .../notice`.
  Future<ApiResult<RepurchaseNotice>> notice() =>
      _withToken(_remote.notice, RepurchaseNotice.fromJson);

  /// `PATCH .../notice`: [enabled] activa o apaga el aviso; [days] (1 a 30) son
  /// los días de anticipación y [useDistributorDays] vuelve al valor de la
  /// distribuidora. Al menos uno. Un 400 del back llega como mensaje.
  Future<ApiResult<RepurchaseNotice>> saveNotice({
    bool? enabled,
    int? days,
    bool useDistributorDays = false,
  }) =>
      _withToken(
        (t) => _remote.updateNotice({
          if (enabled != null) 'enabled': enabled,
          if (useDistributorDays) 'days': null else if (days != null) 'days': days,
        }, t),
        RepurchaseNotice.fromJson,
      );

  /// Mis invitaciones abiertas y vigentes (`GET .../invitations`).
  Future<ApiResult<List<RepurchaseInvitation>>> openInvitations() =>
      _withToken(_remote.invitations, (data) {
        if (data is! List) return null;
        return [
          for (final i in data)
            if (RepurchaseInvitation.fromJson(i) case final inv?) inv
        ];
      });

  /// Acepta la invitación: el back crea el pedido. Con [addressId] lo entrega
  /// en esa dirección del cliente; sin ella, en la de la invitación.
  /// Idempotente por invitación y dirección: el reintento sin respuesta reusa
  /// la clave y no lo duplica.
  ///
  /// Un 404 trae el motivo del back («No encontramos esa dirección entre las
  /// tuyas»), que se muestra tal cual; fuera de cobertura llega como 400.
  Future<ApiResult<RepurchaseAccepted>> accept(String invitationId,
      {String? addressId}) async {
    final token = await _token();
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final intention = '$invitationId:${addressId ?? ''}';
    final r = await _remote.accept(
        invitationId,
        {if (addressId != null) 'addressId': addressId},
        token,
        _keys.keyFor(intention));
    _keys.settle(intention, keep: r.ok ? false : r.keepKey);
    if (!r.ok) {
      return ApiResult.fail(_reason(r), status: r.status, body: r.body);
    }
    final accepted = RepurchaseAccepted.fromJson(r.data);
    return accepted == null
        ? const ApiResult.fail(ApiErrorText.generic)
        : ApiResult.ok(accepted);
  }

  /// Cotiza la invitación con otra dirección del cliente ([addressId]) por el
  /// mismo `POST /orders/quote` del checkout: las garrafas sugeridas y el medio
  /// de pago de la invitación, en su distribuidora (`X-Distributor`). El back
  /// valida que la dirección sea suya y esté en cobertura; ese rechazo llega
  /// con su texto. Los precios los pone el back (`unitPrice` va en 0, como al
  /// aceptar).
  Future<ApiResult<OrderQuote>> quote(
      RepurchaseInvitation invitation, String addressId) async {
    final token = await _token();
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final r = await _orders.quoteOrder(
      {
        'addressId': addressId,
        if (invitation.paymentMethod != null)
          'paymentMethod': invitation.paymentMethod,
        'items': [
          for (final i in invitation.items)
            {
              'gasCylinderId': i.gasCylinderId,
              'quantity': i.quantity,
              'unitPrice': 0,
            }
        ],
      },
      token,
      distributorId: invitation.distributorId,
    );
    if (!r.ok) {
      return ApiResult.fail(_reason(r), status: r.status, body: r.body);
    }
    final quote = OrderQuote.fromJson(r.data);
    return quote == null
        ? const ApiResult.fail(ApiErrorText.generic)
        : ApiResult.ok(quote);
  }

  /// El texto del rechazo. El filtro de negocio de la lib sólo mira 400/409:
  /// a un 404 (dirección que no es suya) se le pasa el cuerpo como si fuera un
  /// 400 para quedarse con el texto en castellano del back.
  static String _reason(ApiResult<dynamic> r) =>
      (r.status == 404 ? ApiErrorText.businessMessage(400, r.body) : null) ??
      r.message ??
      ApiErrorText.generic;

  /// Descarta la invitación (`POST .../dismiss`).
  Future<ApiResult<void>> dismiss(String invitationId) async {
    final token = await _token();
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final r = await _remote.dismiss(invitationId, token);
    return r.ok
        ? const ApiResult.ok()
        : ApiResult.fail(r.message!, status: r.status, body: r.body);
  }
}
