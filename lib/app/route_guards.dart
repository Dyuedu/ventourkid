import '../features/auth/domain/repositories/auth_repository.dart';

class RouteGuards {
  const RouteGuards(this._authRepository);

  final AuthRepository _authRepository;

  Future<bool> get isAuthenticated => _authRepository.isAuthenticated();

  Future<String?> get userRole => _authRepository.getUserRole();
}
