import 'package:dio/dio.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/parent_link_api_models.dart';
import '../../domain/repositories/parent_link_repository.dart';
import '../datasources/parent_link_remote_data_source.dart';

class ParentLinkRepositoryImpl implements ParentLinkRepository {
  ParentLinkRepositoryImpl(this._remoteDataSource);

  final ParentLinkRemoteDataSource _remoteDataSource;

  @override
  Future<ParentLinkPrerequisitesModel> getPrerequisites() {
    return _guard(_remoteDataSource.getPrerequisites);
  }

  @override
  Future<List<TripLinkActivityModel>> getTripLinkCandidates() {
    return _guard(_remoteDataSource.getTripLinkCandidates);
  }

  @override
  Future<TripLinkOtpResultModel> sendTripLinkOtp({
    required String operationPlanId,
    required TripLinkStudentMatchRequest request,
  }) {
    return _guard(
      () => _remoteDataSource.sendTripLinkOtp(
        operationPlanId: operationPlanId,
        request: request,
      ),
    );
  }

  @override
  Future<void> verifyTripLinkOtp({
    required String rosterStudentId,
    required String otpCode,
  }) {
    return _guard(
      () => _remoteDataSource.verifyTripLinkOtp(
        rosterStudentId: rosterStudentId,
        otpCode: otpCode,
      ),
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      final apiException = ApiException.maybeFrom(error);
      throw AppFailure(apiException?.message ?? error.message ?? 'Không thể xử lý yêu cầu.');
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure('Không thể xử lý yêu cầu.', cause: error);
    }
  }
}
