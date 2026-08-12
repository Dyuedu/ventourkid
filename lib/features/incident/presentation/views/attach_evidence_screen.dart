import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';

class AttachEvidenceScreen extends ConsumerStatefulWidget {
  const AttachEvidenceScreen({
    super.key,
    required this.incidentId,
    required this.tourId,
  });

  final String incidentId;
  final String tourId;

  @override
  ConsumerState<AttachEvidenceScreen> createState() =>
      _AttachEvidenceScreenState();
}

class _AttachEvidenceScreenState extends ConsumerState<AttachEvidenceScreen> {
  final _noteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _selectedFile;
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;
    setState(() => _selectedFile = file);
  }

  Future<void> _submit() async {
    final note = _noteController.text.trim();
    final description = _descriptionController.text.trim();
    if (_selectedFile == null && note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn ảnh hoặc nhập ghi chú bằng chứng.')),
      );
      return;
    }
    if (_selectedFile != null && widget.tourId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiếu tourId để tải ảnh bằng chứng.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repository = ref.read(incidentRepositoryProvider);
      if (_selectedFile != null) {
        final file = _selectedFile!;
        final uploaded = await repository.uploadEvidenceFile(
          tourId: widget.tourId,
          path: file.path,
          filename: file.name,
        );
        await repository.attachEvidence(
          incidentId: widget.incidentId,
          evidenceType: 'IMAGE',
          fileUrl: uploaded.fileUrl,
          description: description.isEmpty ? null : description,
        );
      }
      if (note.isNotEmpty) {
        await repository.attachEvidence(
          incidentId: widget.incidentId,
          evidenceType: 'NOTE',
          noteContent: note,
          description: description.isEmpty ? null : description,
        );
      }
      if (!mounted) return;
      await ref
          .read(incidentViewModelProvider.notifier)
          .loadIncidentDetail(widget.incidentId);
      if (!mounted) return;
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _selectedFile;
    return ParentPageScaffold(
      title: 'Đính kèm bằng chứng',
      leading: buildAppBackLeading(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          ParentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(file == null ? 'Chọn ảnh' : 'Đổi ảnh'),
                ),
                if (file != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Image.file(
                      File(file.path),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    file.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          ParentCard(
            child: Column(
              children: [
                TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    hintText:
                        'Mô tả thêm tình huống hoặc xác nhận từ hiện trường',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả ngắn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('Lưu bằng chứng'),
          ),
        ],
      ),
    );
  }
}
