import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/admin/admin_common.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Admin: kelola link survey per semester. Survey yang aktif muncul sebagai
/// pengingat di dashboard PPDS yang semesternya sesuai (atau semua semester).
class AdminSurveyScreen extends StatefulWidget {
  const AdminSurveyScreen({super.key});

  @override
  State<AdminSurveyScreen> createState() => _AdminSurveyScreenState();
}

class _AdminSurveyScreenState extends State<AdminSurveyScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _surveys = [];
  final Set<int> _toggling = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _surveys.isEmpty);
    final data = await _api.adminGetSurveys();
    if (!mounted) return;
    setState(() {
      _surveys = data;
      _loading = false;
    });
  }

  Future<void> _showForm([Map<String, dynamic>? survey]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _SurveyForm(survey: survey));
    if (saved == true && mounted) _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> s, bool value) async {
    final id = s['id'] as int;
    setState(() => _toggling.add(id));
    final error = await _api.adminSaveSurvey(id, {'is_active': value});
    if (!mounted) return;
    setState(() {
      _toggling.remove(id);
      if (error == null) s['is_active'] = value;
    });
    if (error != null) {
      showSnack(context, error, error: true);
    } else {
      showSnack(context, value ? 'Survey diaktifkan' : 'Survey dinonaktifkan');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-survey-add',
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah survey'),
      ),
      body: _loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: AdminListView(
                bottom: 96,
                children: [
                  const Text(
                    'Survey yang aktif tampil sebagai pengingat di dashboard PPDS sesuai semesternya.',
                    style: TextStyle(fontSize: 14, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 12),
                  if (_surveys.isEmpty)
                    EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'Belum ada survey',
                      message: 'Tambahkan link survey per semester. Bila daftar seharusnya berisi, tarik ke bawah untuk memuat ulang.',
                      action: OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Muat ulang')),
                    )
                  else
                    for (final raw in _surveys) _card(raw as Map<String, dynamic>),
                ],
              ),
            ),
    );
  }

  Widget _card(Map<String, dynamic> s) {
    final aktif = s['is_active'] == true;
    final sem = s['semester_target'];
    final busy = _toggling.contains(s['id']);
    return AppCard(
      onTap: () => _showForm(s),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: (aktif ? AppColors.successGreen : AppColors.neutralGrey).withValues(alpha: 0.12),
          child: Icon(Icons.assignment_outlined, color: aktif ? AppColors.successGreen : AppColors.neutralGrey, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(textOf(s['judul']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              TagChip(sem == null ? 'Semua semester' : 'Semester $sem', color: AppColors.primaryPurple),
              TagChip(aktif ? 'Aktif' : 'Nonaktif', color: aktif ? AppColors.successGreen : AppColors.neutralGrey),
            ]),
            const SizedBox(height: 4),
            Text(textOf(s['link_survey']),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            Wrap(spacing: 4, children: [
              LinkButton(label: 'Buka survey', url: s['link_survey'] as String?),
              TextButton.icon(
                onPressed: () => _showForm(s),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ]),
          ]),
        ),
        Column(children: [
          Switch(value: aktif, onChanged: busy ? null : (v) => _toggleActive(s, v)),
          Text(aktif ? 'Tampil' : 'Disembunyikan', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ]),
      ]),
    );
  }
}

class _SurveyForm extends StatefulWidget {
  final Map<String, dynamic>? survey;
  const _SurveyForm({this.survey});

  @override
  State<_SurveyForm> createState() => _SurveyFormState();
}

class _SurveyFormState extends State<_SurveyForm> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _judul = TextEditingController(text: textOf(widget.survey?['judul']));
  late final TextEditingController _link = TextEditingController(text: textOf(widget.survey?['link_survey']));
  late int? _semester = _initialSemester();
  late bool _aktif = widget.survey == null || widget.survey!['is_active'] == true;
  bool _busy = false;
  String? _error;

  int? _initialSemester() {
    final s = (widget.survey?['semester_target'] as num?)?.toInt();
    return (s == null || s < 1 || s > 20) ? null : s;
  }

  @override
  void dispose() {
    _judul.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await _api.adminSaveSurvey(widget.survey?['id'] as int?, {
      'judul': _judul.text.trim(),
      'link_survey': _link.text.trim(),
      'semester_target': _semester,
      'is_active': _aktif,
    });
    if (!mounted) return;
    if (error == null) {
      showSnack(context, 'Survey tersimpan');
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialogFrame(
      title: widget.survey == null ? 'Tambah survey' : 'Edit survey',
      formKey: _formKey,
      busy: _busy,
      error: _error,
      onSubmit: _submit,
      children: [
        TextFormField(
          controller: _judul,
          decoration: const InputDecoration(
              labelText: 'Judul', hintText: 'Mis. Survey Evaluasi Semester 3', prefixIcon: Icon(Icons.title)),
          validator: (v) => validateRequired(v, 'Judul'),
        ),
        formGap,
        TextFormField(
          controller: _link,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
              labelText: 'Link survey (Google Form, dll.)', hintText: 'https://forms.gle/...', prefixIcon: Icon(Icons.link)),
          validator: (v) => validateLink(v),
        ),
        formGap,
        DropdownButtonFormField<int?>(
          initialValue: _semester,
          decoration: const InputDecoration(labelText: 'Untuk semester', prefixIcon: Icon(Icons.school_outlined)),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Semua semester')),
            for (int i = 1; i <= 20; i++) DropdownMenuItem<int?>(value: i, child: Text('Semester $i')),
          ],
          onChanged: (v) => setState(() => _semester = v),
        ),
        formGap,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aktif', style: TextStyle(fontSize: 15)),
          subtitle: const Text('Tampil di dashboard PPDS', style: TextStyle(fontSize: 13)),
          value: _aktif,
          onChanged: (v) => setState(() => _aktif = v),
        ),
      ],
    );
  }
}
