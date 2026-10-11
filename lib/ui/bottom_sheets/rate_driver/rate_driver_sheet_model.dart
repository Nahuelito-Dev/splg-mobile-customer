import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/rating_service.dart';

class RateDriverSheetModel extends BaseViewModel {
  final _ratingService = locator<RatingService>();

  final TextEditingController commentController = TextEditingController();

  int _stars = 0;
  int get stars => _stars;

  String? errorMessage;

  void setStars(int value) {
    _stars = value;
    errorMessage = null;
    notifyListeners();
  }

  /// Envía la calificación del chofer. Devuelve `true` si se registró.
  Future<bool> submit(String orderId) async {
    if (isBusy) return false;
    if (_stars == 0) {
      errorMessage = 'Elegí una puntuación de 1 a 5.';
      notifyListeners();
      return false;
    }

    setBusy(true);
    errorMessage = null;
    final result = await _ratingService.rateDriver(
      orderId: orderId,
      stars: _stars,
      comment: commentController.text,
    );
    setBusy(false);

    if (!result.ok) {
      errorMessage = result.message;
      notifyListeners();
    }
    return result.ok;
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }
}
