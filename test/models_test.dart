import 'package:flutter_test/flutter_test.dart';
import 'package:onekm_core/onekm_core.dart';

void main() {
  test('booking parses leniently', () {
    final b = Booking.fromJson({
      'id': '1',
      'customer_phone': '9876543210',
      'kind': 'goods',
      'pickup': 'a',
      'dropoff': 'b',
      'vehicle_type': 'tempo',
      'status': 'en_route',
      'weight_kg': 10,
    });
    expect(b.isGoods, isTrue);
    expect(b.status, BookingStatus.enRoute);
    expect(b.fare, isNull);
    expect(b.pickupCode, isNull);
  });

  test('unknown statuses never crash', () {
    final b = Booking.fromJson({'status': 'flying'});
    expect(b.status, BookingStatus.unknown);
    expect(b.id, '');
  });

  test('invoice math fields default to zero', () {
    final i = Invoice.fromJson({'provider_id': 'p'});
    expect(i.rides, 0);
    expect(i.balance, 0.0);
    expect(i.methods, isEmpty);
  });

  test('status event parses lifecycle history', () {
    final e = StatusEvent.fromJson({
      'id': 'e1',
      'booking_id': 'b1',
      'at': '2026-09-18T10:00:00Z',
      'by': 'desk',
      'from': 'requested',
      'to': 'assigned',
    });
    expect(e.from, BookingStatus.requested);
    expect(e.to, BookingStatus.assigned);
    expect(e.note, isNull);
  });
}
