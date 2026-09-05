import 'dart:developer';

import 'package:splg_lib/domain/order.dart';
import 'package:splg_customer/data/datasource/order_remote_datasource.dart';
import 'package:splg_customer/data/mappers/order_api_mapper.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';

class OrderRepositoryImp implements OrderRepository {
  OrderRepositoryImp(this._remoteDatasource);

  final OrderRemoteDatasource _remoteDatasource;

  @override
  Future<CreateOrderResult> createOrder(
    Map<String, dynamic> orderData,
    String token,
  ) async {
    try {
      final (success, data) = await _remoteDatasource.createOrder(
        orderData,
        token,
      );
      if (!success || data == null) {
        return const CreateOrderResult(success: false);
      }

      // Fallback for APIs that do not return the full created order payload.
      final order =
          OrderApiMapper.parseOrder(data) ?? OrderApiMapper.parseOrder(orderData);
      final paymentUrl = OrderApiMapper.extractPaymentUrl(data);

      return CreateOrderResult(
        success: order != null,
        order: order,
        paymentUrl: paymentUrl,
      );
    } catch (e) {
      log('e in createOrder repository: ${e.toString()}');
    }

    return const CreateOrderResult(success: false);
  }

  @override
  Future<Order?> updateOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String token,
  ) async {
    try {
      final (success, data) = await _remoteDatasource.updateOrder(
        orderId,
        orderData,
        token,
      );
      if (!success || data == null) return null;

      final order = OrderApiMapper.parseOrder(data);
      if (order != null) return order;

      return OrderApiMapper.parseOrder({
        ...orderData,
        'order_id': orderId,
      });
    } catch (e) {
      log('e in updateOrder repository: ${e.toString()}');
    }

    return null;
  }

  @override
  Future<List<Order>> fetchCustomerHistory(
    String customerId,
    String token, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final (success, data) = await _remoteDatasource.fetchCustomerHistory(
        customerId,
        token,
        limit: limit,
        offset: offset,
      );
      if (!success || data == null) return [];

      return OrderApiMapper.parseOrders(data);
    } catch (e) {
      log('e in fetchCustomerHistory repository: ${e.toString()}');
    }

    return [];
  }

  @override
  Future<bool> updateOrderStatus(
    String orderId,
    String status,
    String token,
  ) async {
    try {
      return await _remoteDatasource.updateOrderStatus(orderId, status, token);
    } catch (e) {
      log('e in updateOrderStatus repository: ${e.toString()}');
    }

    return false;
  }
}
