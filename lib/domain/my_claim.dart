/// Estado de un reclamo, como lo devuelve `GET /claims/mine`.
enum ClaimStatus {
  pending('Pendiente'),
  inProcess('En proceso'),
  resolved('Resuelto'),
  rejected('Rechazado');

  const ClaimStatus(this.label);
  final String label;

  static ClaimStatus parse(Object? raw) => switch (raw) {
    'in_process' => ClaimStatus.inProcess,
    'resolved' => ClaimStatus.resolved,
    'rejected' => ClaimStatus.rejected,
    _ => ClaimStatus.pending,
  };
}

/// Un reclamo propio (`GET /claims/mine`, camelCase).
class MyClaim {
  const MyClaim({
    required this.claimId,
    required this.status,
    required this.reason,
    required this.description,
    required this.createdAt,
    required this.orderId,
    this.orderTotal,
    this.resolutionNote,
  });

  final String claimId;
  final ClaimStatus status;
  final String reason;
  final String description;
  final DateTime createdAt;
  final String orderId;
  final double? orderTotal;
  final String? resolutionNote;

  factory MyClaim.fromJson(Map<String, dynamic> json) {
    final order = json['order'];
    return MyClaim(
      claimId: json['claimId']?.toString() ?? '',
      status: ClaimStatus.parse(json['status']),
      reason: json['reason']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      orderId: order is Map ? order['orderId']?.toString() ?? '' : '',
      orderTotal: order is Map && order['totalAmount'] is num
          ? (order['totalAmount'] as num).toDouble()
          : null,
      resolutionNote: json['resolutionNote']?.toString(),
    );
  }
}

/// Una página de reclamos con el total sin paginar (`X-Total-Count`).
class ClaimsPage {
  const ClaimsPage({required this.claims, required this.total});

  final List<MyClaim> claims;
  final int total;
}
