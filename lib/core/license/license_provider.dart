import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import 'license_model.dart';
import 'license_service.dart';

final licenseServiceProvider = Provider<LicenseService>((ref) {
  return LicenseService();
});

final licenseStatusProvider = AsyncNotifierProvider<LicenseStatusNotifier, LicenseModel>(() {
  return LicenseStatusNotifier();
});

class LicenseStatusNotifier extends AsyncNotifier<LicenseModel> {
  @override
  Future<LicenseModel> build() async {
    final authUser = ref.watch(authStateChangesProvider).value;
    final service = ref.read(licenseServiceProvider);
    return await service.loadLicenseStatus(userEmail: authUser?.email);
  }

  Future<void> refreshStatus() async {
    state = const AsyncValue.loading();
    final authUser = ref.read(authStateChangesProvider).value;
    final service = ref.read(licenseServiceProvider);
    final status = await service.loadLicenseStatus(userEmail: authUser?.email);
    state = AsyncValue.data(status);
  }

  Future<bool> activate(String code) async {
    final service = ref.read(licenseServiceProvider);
    final authUser = ref.read(authStateChangesProvider).value;
    final success = await service.activateWithCode(code, userEmail: authUser?.email);
    if (success) {
      await refreshStatus();
    }
    return success;
  }
}
