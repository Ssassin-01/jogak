import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 성운(Nebula) 애니메이션 활성화 여부를 관리하는 전역 프로바이더
/// 기기 발열 방지 및 배터리 소모 최적화를 위해 사용됩니다.
final nebulaEnabledProvider = StateProvider<bool>((ref) => true);
