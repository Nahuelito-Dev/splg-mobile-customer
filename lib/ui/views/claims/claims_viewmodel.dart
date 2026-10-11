import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/my_claim.dart';
import 'package:splg_customer/services/claim_service.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';

/// Mis reclamos: lista paginada de `GET /claims/mine`.
class ClaimsViewModel extends LoadViewModel {
  static const pageSize = 20;

  final _claims = locator<ClaimService>();
  final _nav = locator<NavigationService>();

  final List<MyClaim> claims = [];
  int total = 0;

  /// Error al traer más (la lista ya cargada se conserva).
  String? moreError;
  bool loadingMore = false;

  bool get hasMore => claims.length < total;

  @override
  Future<void> fetch() async {
    final r = await _claims.fetchMine(limit: pageSize, offset: 0);
    if (!r.ok) throw LoadFailure(r.message!);
    claims
      ..clear()
      ..addAll(r.data!.claims);
    total = r.data!.total;
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    moreError = null;
    notifyListeners();
    final r = await _claims.fetchMine(limit: pageSize, offset: claims.length);
    if (r.ok) {
      claims.addAll(r.data!.claims);
      // Una página vacía con total mayor es un desfase del back: no se deja
      // "Ver más" para siempre.
      total = r.data!.claims.isEmpty ? claims.length : r.data!.total;
    } else {
      moreError = r.message;
    }
    loadingMore = false;
    notifyListeners();
  }

  Future<void> open(MyClaim claim) =>
      _nav.navigateToClaimDetailView(claim: claim);
}
