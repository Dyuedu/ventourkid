import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';

/// Post-tour feedback (BR-107) — rating 1–5 + comment after plan COMPLETED.
/// Used by parent and accompanying teacher.
class ParentPostTourFeedbackPage extends ConsumerStatefulWidget {
  const ParentPostTourFeedbackPage({
    super.key,
    required this.tourId,
    this.tourName,
    this.actorRole = 'PARENT',
  });

  final String tourId;
  final String? tourName;

  /// JWT role used when loading existing feedback: PARENT | TEACHER | HOMEROOM_TEACHER
  final String actorRole;

  @override
  ConsumerState<ParentPostTourFeedbackPage> createState() =>
      _ParentPostTourFeedbackPageState();
}

class _ParentPostTourFeedbackPageState
    extends ConsumerState<ParentPostTourFeedbackPage> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  bool _alreadySubmitted = false;

  bool get _isTeacher {
    final role = widget.actorRole.trim().toUpperCase();
    return role == 'TEACHER' || role == 'HOMEROOM_TEACHER';
  }

  bool _matchesMyRole(String? raw) {
    final role = (raw ?? '').trim().toUpperCase();
    final expected = widget.actorRole.trim().toUpperCase();
    if (expected == 'TEACHER' || expected == 'HOMEROOM_TEACHER') {
      return role == 'TEACHER' || role == 'HOMEROOM_TEACHER';
    }
    return role == expected;
  }

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final checklist = await ref
          .read(tourClosingRemoteDataSourceProvider)
          .getChecklist(widget.tourId);
      final feedbacks = checklist['feedbacks'];
      if (feedbacks is List) {
        final mine = feedbacks.whereType<Map>().cast<Map>().where((f) {
          return _matchesMyRole(f['actorRole']?.toString());
        }).toList();
        if (mine.isNotEmpty) {
          final latest = mine.last;
          final rating = latest['rating'];
          _rating = rating is int
              ? rating
              : int.tryParse(rating?.toString() ?? '') ?? 5;
          _commentController.text = latest['comment']?.toString() ?? '';
          _alreadySubmitted = true;
        }
      }
    } on DioException catch (e) {
      final code = e.response?.data is Map
          ? (e.response!.data as Map)['code']?.toString()
          : null;
      if (code == 'CLS-011') {
        _error =
            'Chuyến đi chưa hoàn tất — chỉ đánh giá sau khi tour COMPLETED.';
      } else {
        _error = e.response?.data is Map
            ? ((e.response!.data as Map)['message']?.toString() ??
                'Không tải được thông tin đánh giá.')
            : 'Không tải được thông tin đánh giá.';
      }
    } catch (_) {
      _error = 'Không tải được thông tin đánh giá.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(tourClosingRemoteDataSourceProvider).submitFeedback(
            widget.tourId,
            rating: _rating,
            comment: _commentController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _alreadySubmitted
                ? 'Đã cập nhật đánh giá sau tour.'
                : 'Đã gửi đánh giá sau tour. Cảm ơn bạn!',
          ),
        ),
      );
      setState(() => _alreadySubmitted = true);
      Navigator.of(context).maybePop();
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? ((e.response!.data as Map)['message']?.toString() ??
              'Không gửi được đánh giá.')
          : 'Không gửi được đánh giá.';
      if (mounted) {
        setState(() => _error = message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không gửi được đánh giá.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.tourName?.trim().isNotEmpty == true
        ? widget.tourName!.trim()
        : 'Đánh giá sau tour';
    final helper = _isTeacher
        ? 'Chia sẻ mức hài lòng về tổ chức và trải nghiệm chuyến đi của lớp (1–5 sao).'
        : 'Chia sẻ mức hài lòng về chuyến tham quan của con (1–5 sao).';
    final commentHint = _isTeacher
        ? 'Tổ chức, an toàn, hỗ trợ học sinh, phối hợp hướng dẫn viên…'
        : 'Tổ chức, hướng dẫn viên, an toàn, trải nghiệm của con…';

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: const AppBackLeading(),
        title: const Text('Đánh giá sau tour'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  helper,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Mức hài lòng',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    final selected = _rating >= value;
                    return IconButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _rating = value),
                      icon: Icon(
                        selected
                            ? Iconsax.star_1
                            : Iconsax.star,
                        color: selected
                            ? AppTheme.accentOrange
                            : AppTheme.neutral400,
                        size: 32,
                      ),
                    );
                  }),
                ),
                Text(
                  '$_rating / 5',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nhận xét',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  enabled: !_submitting,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hintText: commentHint,
                    filled: true,
                    fillColor: Colors.white,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.accentRed),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ||
                          (_error != null &&
                              !_alreadySubmitted &&
                              _error!.contains('hoàn tất'))
                      ? null
                      : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _alreadySubmitted
                              ? 'Cập nhật đánh giá'
                              : 'Gửi đánh giá',
                        ),
                ),
              ],
            ),
    );
  }
}
