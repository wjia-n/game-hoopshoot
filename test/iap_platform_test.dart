import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopshoot/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS), {'hoopshootstar'});
    expect(StoreService.starId, 'hoopshootstar');
  });
  test('Android maps to coffee + chocolate', () {
    expect(StoreService.productIdsFor(TargetPlatform.android),
        {'hoopshootcoffee', 'hoopshootchocolate'});
  });
  test('iOS and Android product sets do not overlap', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS)
        .intersection(StoreService.productIdsFor(TargetPlatform.android)), isEmpty);
  });
}
