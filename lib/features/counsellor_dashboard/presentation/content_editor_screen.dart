import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../learning_hub/data/learning_repository.dart';
import '../../learning_hub/domain/learning_resource.dart';

/// Create (resourceId == null) or edit a Learning Hub resource.
class ContentEditorScreen extends ConsumerWidget {
  const ContentEditorScreen({super.key, this.resourceId});

  final String? resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (resourceId == null) return const _Editor();
    final res = ref.watch(resourceDetailProvider(resourceId!));
    return res.when(
      data: (r) => _Editor(existing: r),
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e, onRetry: () => ref.invalidate(resourceDetailProvider(resourceId!))),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({this.existing});

  final LearningResource? existing;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _content = TextEditingController(text: widget.existing?.content);
  late final _media = TextEditingController(text: widget.existing?.mediaUrl);
  late final _minutes = TextEditingController(text: widget.existing?.readMinutes?.toString());
  late ResourceCategory _category = widget.existing?.category ?? ResourceCategory.understanding;
  late ResourceFormat _format = widget.existing?.format ?? ResourceFormat.article;
  late bool _published = widget.existing?.published ?? false;
  late String? _imageUrl = widget.existing?.imageUrl;
  bool _saving = false;
  bool _uploading = false;

  LearningRepository get _repo => ref.read(learningRepositoryProvider);

  @override
  void dispose() {
    for (final c in [_title, _description, _content, _media, _minutes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      setState(() => _uploading = true);
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final url = await _repo.uploadImage(bytes, ext);
      if (mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final draft = ResourceDraft(
      title: _title.text,
      description: _description.text,
      category: _category,
      format: _format,
      published: _published,
      content: _content.text,
      imageUrl: _imageUrl,
      mediaUrl: _media.text,
      readMinutes: int.tryParse(_minutes.text.trim()),
    );
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await _repo.create(draft);
      } else {
        await _repo.update(widget.existing!.id, draft);
        ref.invalidate(resourceDetailProvider(widget.existing!.id));
      }
      ref.invalidate(managedResourcesProvider);
      if (!mounted) return;
      showAppSnack(context, _published ? 'Resource published.' : 'Saved as draft.');
      context.pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(context,
        title: 'Delete resource?', message: 'Students will no longer see it. This cannot be undone.', confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    try {
      await _repo.delete(widget.existing!.id);
      ref.invalidate(managedResourcesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New resource' : 'Edit resource'),
        actions: [
          if (widget.existing != null)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            AppTextField(
              controller: _title,
              label: 'Title',
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => Validators.requiredText(v, field: 'Title', minLength: 3, maxLength: 150),
            ),
            AppSpacing.gapSm,
            AppTextField(
              controller: _description,
              label: 'Short description',
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => Validators.requiredText(v, field: 'Description', minLength: 10, maxLength: 300),
            ),
            AppSpacing.gapSm,
            DropdownButtonFormField<ResourceCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in ResourceCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            AppSpacing.gapMd,
            DropdownButtonFormField<ResourceFormat>(
              initialValue: _format,
              decoration: const InputDecoration(labelText: 'Format'),
              items: [for (final f in ResourceFormat.values) DropdownMenuItem(value: f, child: Text(f.label))],
              onChanged: (v) => setState(() => _format = v ?? _format),
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _content,
              label: _format == ResourceFormat.faq ? 'Questions & answers' : 'Content',
              hint: _format == ResourceFormat.faq ? 'Q: …\nA: …' : null,
              maxLines: 14,
              minLines: 6,
              maxLength: 20000,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (_format.needsLink) return Validators.optionalText(v, maxLength: 20000);
                return Validators.requiredText(v, field: 'Content', minLength: 20, maxLength: 20000);
              },
            ),
            AppSpacing.gapSm,
            AppTextField(
              controller: _media,
              label: _format.needsLink ? 'Approved media link (https)' : 'Media link (optional)',
              keyboardType: TextInputType.url,
              validator: (v) {
                final base = Validators.url(v, required: _format.needsLink);
                if (base != null) return base;
                if ((v?.trim().isNotEmpty ?? false) && !v!.trim().startsWith('https://')) {
                  return 'Please use a secure https:// link.';
                }
                return null;
              },
            ),
            AppSpacing.gapSm,
            AppTextField(
              controller: _minutes,
              label: 'Reading / viewing time in minutes (optional)',
              keyboardType: TextInputType.number,
              validator: (v) => (v?.trim().isEmpty ?? true) ? null : Validators.positiveInt(v, field: 'Minutes', max: 120),
            ),
            const SectionHeader(title: 'Image'),
            if (_imageUrl != null)
              ClipRRect(
                borderRadius: AppRadius.lgAll,
                child: Image.network(_imageUrl!, height: 160, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(height: 40)),
              ),
            AppSpacing.gapSm,
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    label: _imageUrl == null ? 'Upload image' : 'Replace image',
                    icon: Icons.image_outlined,
                    isLoading: _uploading,
                    onPressed: _pickImage,
                  ),
                ),
                if (_imageUrl != null) ...[
                  AppSpacing.gapSm,
                  IconButton(tooltip: 'Remove image', onPressed: () => setState(() => _imageUrl = null), icon: const Icon(Icons.close_rounded)),
                ],
              ],
            ),
            Text('JPG, PNG or WebP, up to 5 MB. Use only images you have rights to.', style: context.text.bodySmall),
            AppSpacing.gapSm,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Published'),
              subtitle: const Text('Visible to students in the Learning Hub'),
              value: _published,
              onChanged: (v) => setState(() => _published = v),
            ),
            AppSpacing.gapLg,
            AppButton(label: 'Save', isLoading: _saving, onPressed: _uploading ? null : _save),
          ],
        ),
      ),
    );
  }
}
