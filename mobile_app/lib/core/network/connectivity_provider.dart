import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// هل للجهاز اتصال بشبكة ما. لا يضمن وصول الخادم؛ للتلميح في الواجهة فقط
/// (شريط «لا اتصال»)، أما فشل الطلب الفعلي فيمثله `ErrorCode.network`.
bool hasConnection(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield hasConnection(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(hasConnection);
});
