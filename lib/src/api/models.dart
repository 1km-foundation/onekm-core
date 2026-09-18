/// Hand-written API models mirroring the server OpenAPI spec
/// (`GET /api-docs/openapi.json`).
///
/// Kept dependency-free (no codegen) for Phase 0; every `fromJson` is
/// lenient (`num → double`, missing → null/default) so additive server
/// changes never crash older builds. A generated client replaces this
/// file when the spec stabilizes.
library;

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

double? _dOpt(dynamic v) => (v as num?)?.toDouble();

String _s(dynamic v, [String fallback = '']) =>
    v is String ? v : fallback;

enum BookingStatus {
  requested,
  assigned,
  enRoute,
  completed,
  canceled,
  unknown;

  static BookingStatus parse(Object? v) => BookingStatus.values.firstWhere(
        (e) => e.name == _snake(v),
        orElse: () => BookingStatus.unknown,
      );

  static String _snake(Object? v) {
    final s = '$v';
    if (s == 'en_route') return 'enRoute';
    return s;
  }

  String get wire => this == BookingStatus.enRoute ? 'en_route' : name;
}

enum BookingKind { passenger, goods }

enum VehicleType { auto, cab, tempo, bike }

class Booking {
  Booking({
    required this.id,
    required this.customerPhone,
    required this.kind,
    required this.pickup,
    required this.dropoff,
    required this.vehicleType,
    required this.status,
    this.customerName,
    this.estimatedFare,
    this.finalFare,
    this.weightKg,
    this.goodsDescription,
    this.scheduledAt,
    this.providerId,
    this.pickupCode,
    this.cancelReason,
    this.consumerConfirmed = false,
  });

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: _s(j['id']),
        customerPhone: _s(j['customer_phone']),
        kind: j['kind'] == 'goods' ? BookingKind.goods : BookingKind.passenger,
        pickup: _s(j['pickup']),
        dropoff: _s(j['dropoff']),
        vehicleType: VehicleType.values.firstWhere(
          (e) => e.name == j['vehicle_type'],
          orElse: () => VehicleType.auto,
        ),
        status: BookingStatus.parse(j['status']),
        customerName: j['customer_name'] as String?,
        estimatedFare: _dOpt(j['estimated_fare']),
        finalFare: _dOpt(j['final_fare']),
        weightKg: _dOpt(j['weight_kg']),
        goodsDescription: j['goods_description'] as String?,
        scheduledAt: j['scheduled_at'] == null
            ? null
            : DateTime.tryParse('${j['scheduled_at']}'),
        providerId: j['provider_id'] as String?,
        pickupCode: j['pickup_code'] as String?,
        cancelReason: j['cancel_reason'] as String?,
        consumerConfirmed: j['consumer_confirmed'] == true,
      );

  final String id;
  final String customerPhone;
  final BookingKind kind;
  final String pickup;
  final String dropoff;
  final VehicleType vehicleType;
  final BookingStatus status;
  final String? customerName;
  final double? estimatedFare;
  final double? finalFare;
  final double? weightKg;
  final String? goodsDescription;
  final DateTime? scheduledAt;
  final String? providerId;
  final String? pickupCode;
  final String? cancelReason;
  final bool consumerConfirmed;

  double? get fare => finalFare ?? estimatedFare;
  bool get isGoods => kind == BookingKind.goods;
}

class Provider {
  Provider({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.registration,
    required this.status,
    this.goodsCapable = false,
    this.verified = false,
    this.online = false,
  });

  factory Provider.fromJson(Map<String, dynamic> j) => Provider(
        id: _s(j['id']),
        name: _s(j['name']),
        phone: _s(j['phone']),
        vehicleType: VehicleType.values.firstWhere(
          (e) => e.name == j['vehicle_type'],
          orElse: () => VehicleType.auto,
        ),
        registration: _s(j['registration']),
        status: _s(j['status'], 'inactive'),
        goodsCapable: j['goods_capable'] == true,
        verified: j['verified'] == true,
        online: j['online'] == true,
      );

  final String id;
  final String name;
  final String phone;
  final VehicleType vehicleType;
  final String registration;
  final String status;
  final bool goodsCapable;
  final bool verified;
  final bool online;

  bool get isActive => status == 'active';
}

class Invoice {
  Invoice({
    required this.providerId,
    required this.providerName,
    required this.rides,
    required this.totalFare,
    required this.commissionDue,
    required this.collected,
    required this.balance,
    this.methods = const {},
    this.unpaidWeeks = 0,
  });

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        providerId: _s(j['provider_id']),
        providerName: _s(j['provider_name']),
        rides: (j['rides'] as num?)?.toInt() ?? 0,
        totalFare: _d(j['total_fare']),
        commissionDue: _d(j['commission_due']),
        collected: _d(j['collected']),
        balance: _d(j['balance']),
        methods: (j['methods'] as Map?)?.map(
              (k, v) => MapEntry('$k', _d(v)),
            ) ??
            const {},
        unpaidWeeks: (j['unpaid_weeks'] as num?)?.toInt() ?? 0,
      );

  final String providerId;
  final String providerName;
  final int rides;
  final double totalFare;
  final double commissionDue;
  final double collected;
  final double balance;
  final Map<String, double> methods;
  final int unpaidWeeks;
}

class Earnings {
  Earnings({
    required this.todayRides,
    required this.todayFare,
    required this.weekRides,
    required this.weekFare,
    required this.commissionDue,
    required this.balance,
  });

  factory Earnings.fromJson(Map<String, dynamic> j) => Earnings(
        todayRides: (j['today_rides'] as num?)?.toInt() ?? 0,
        todayFare: _d(j['today_fare']),
        weekRides: (j['week_rides'] as num?)?.toInt() ?? 0,
        weekFare: _d(j['week_fare']),
        commissionDue: _d(j['commission_due']),
        balance: _d(j['balance']),
      );

  final int todayRides;
  final double todayFare;
  final int weekRides;
  final double weekFare;
  final double commissionDue;
  final double balance;
}

class Dispute {
  Dispute({
    required this.id,
    required this.bookingId,
    required this.reporter,
    required this.description,
    required this.status,
    this.urgent = false,
  });

  factory Dispute.fromJson(Map<String, dynamic> j) => Dispute(
        id: _s(j['id']),
        bookingId: _s(j['booking_id']),
        reporter: _s(j['reporter']),
        description: _s(j['description']),
        status: _s(j['status'], 'open'),
        urgent: j['urgent'] == true,
      );

  final String id;
  final String bookingId;
  final String reporter;
  final String description;
  final String status;
  final bool urgent;
}

class Review {
  Review({
    required this.id,
    required this.bookingId,
    required this.rating,
    this.providerId,
    this.comment,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: _s(j['id']),
        bookingId: _s(j['booking_id']),
        rating: _s(j['rating'], 'good'),
        providerId: j['provider_id'] as String?,
        comment: j['comment'] as String?,
      );

  final String id;
  final String bookingId;
  final String rating;
  final String? providerId;
  final String? comment;

  bool get isIssue => rating == 'issue';
}

class RateEntry {
  RateEntry({
    required this.kind,
    required this.vehicle,
    required this.base,
    required this.perKm,
    required this.perKg,
  });

  factory RateEntry.fromJson(Map<String, dynamic> j) => RateEntry(
        kind: j['kind'] == 'goods' ? BookingKind.goods : BookingKind.passenger,
        vehicle: VehicleType.values.firstWhere(
          (e) => e.name == j['vehicle_type'],
          orElse: () => VehicleType.auto,
        ),
        base: _d(j['base']),
        perKm: _d(j['per_km']),
        perKg: _d(j['per_kg']),
      );

  final BookingKind kind;
  final VehicleType vehicle;
  final double base;
  final double perKm;
  final double perKg;
}

class StatusEvent {
  StatusEvent({
    required this.id,
    required this.bookingId,
    required this.at,
    required this.by,
    required this.from,
    required this.to,
    this.note,
  });

  factory StatusEvent.fromJson(Map<String, dynamic> j) => StatusEvent(
        id: _s(j['id']),
        bookingId: _s(j['booking_id']),
        at: DateTime.tryParse('${j['at']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        by: _s(j['by']),
        from: BookingStatus.parse(j['from']),
        to: BookingStatus.parse(j['to']),
        note: j['note'] as String?,
      );

  final String id;
  final String bookingId;
  final DateTime at;
  final String by;
  final BookingStatus from;
  final BookingStatus to;
  final String? note;
}
