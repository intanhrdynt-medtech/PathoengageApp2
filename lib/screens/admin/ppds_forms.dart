import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/admin/admin_common.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

// ── Tugas akademik ────────────────────────────────────────────────────────────

const List<String> taskTypes = [
  'Tugas Ilmiah',
  'Textbook Reading',
  'Journal Reading',
  'Penelitian',
  'Publikasi',
  'Etik',
];

const List<String> _taskStatuses = ['not_started', 'in_progress', 'pending_verification', 'completed'];

/// Tambah (task == null) atau edit tugas akademik. true bila tersimpan.
Future<bool> showTaskForm(BuildContext context, {required int userId, Map<String, dynamic>? task}) async {
  final saved = await showDialog<bool>(context: context, builder: (_) => _TaskForm(userId: userId, task: task));
  return saved == true;
}

class _TaskForm extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? task;
  const _TaskForm({required this.userId, this.task});

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  late final Map<String, dynamic> _t = widget.task ?? const {};
  late final TextEditingController _title = TextEditingController(text: textOf(_t['title']));
  late final TextEditingController _desc = TextEditingController(text: textOf(_t['description']));
  late final TextEditingController _link = TextEditingController(text: textOf(_t['link_url']));
  late String _type = textOf(_t['task_type']).isEmpty ? taskTypes.first : textOf(_t['task_type']);
  late int _semester = ((_t['target_semester'] as num?)?.toInt() ?? 1).clamp(1, 20);
  late DateTime? _deadline = parseDate(_t['deadline']);
  late final String _origStatus =
      _t['is_completed'] == true ? 'completed' : (_taskStatuses.contains(_t['status']) ? _t['status'] as String : 'not_started');
  late String _status = _origStatus;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.task != null;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final statusChanged = _isEdit && _status != _origStatus;
    if (statusChanged && _status == 'completed') {
      final ok = await confirmDialog(
        context,
        title: 'Tandai selesai tanpa verifikasi?',
        message: 'Tugas "${_title.text.trim()}" akan langsung tercatat selesai tanpa memeriksa bukti PPDS. '
            'Biasanya tugas diselesaikan lewat menu Verifikasi.',
        confirmText: 'Ya, tandai selesai',
      );
      if (!ok || !mounted) return;
    } else if (statusChanged && _origStatus == 'completed') {
      final ok = await confirmDialog(
        context,
        title: 'Batalkan status selesai?',
        message: 'Tugas ini sudah tercatat selesai. Mengubah statusnya membuat PPDS perlu mengirim ulang bukti.',
        confirmText: 'Ubah status',
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final data = <String, dynamic>{
      'task_type': _type,
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'target_semester': _semester,
      'link_url': _link.text.trim().isEmpty ? null : _link.text.trim(),
      'deadline': _deadline == null ? null : isoDateOnly(_deadline!),
      if (statusChanged) 'status': _status,
      if (statusChanged) 'is_completed': _status == 'completed',
    };
    final ok = _isEdit
        ? await _api.adminUpdateAcademicTask(_t['id'] as int, data)
        : await _api.adminAddTask({'user_id': widget.userId, ...data});
    if (!mounted) return;
    if (ok) {
      showSnack(context, _isEdit ? 'Tugas diperbarui' : 'Tugas ditambahkan');
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Gagal menyimpan tugas. Periksa isian dan koneksi, lalu coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = [...taskTypes, if (!taskTypes.contains(_type)) _type];
    return FormDialogFrame(
      title: _isEdit ? 'Edit tugas akademik' : 'Tambah tugas akademik',
      formKey: _formKey,
      busy: _busy,
      error: _error,
      submitText: _isEdit ? 'Simpan' : 'Tambah',
      onSubmit: _submit,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Jenis tugas', prefixIcon: Icon(Icons.category_outlined)),
          items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t))],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        formGap,
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Judul / nama tugas', prefixIcon: Icon(Icons.title)),
          validator: (v) => validateRequired(v, 'Judul'),
        ),
        formGap,
        TextFormField(
          controller: _desc,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(labelText: 'Deskripsi (opsional)', alignLabelWithHint: true),
        ),
        formGap,
        DropdownButtonFormField<int>(
          initialValue: _semester,
          decoration: const InputDecoration(labelText: 'Target semester', prefixIcon: Icon(Icons.school_outlined)),
          items: [for (int i = 1; i <= 20; i++) DropdownMenuItem(value: i, child: Text('Semester $i'))],
          onChanged: (v) => setState(() => _semester = v ?? _semester),
        ),
        formGap,
        DateField(label: 'Tenggat (opsional)', value: _deadline, onChanged: (d) => setState(() => _deadline = d)),
        formGap,
        TextFormField(
          controller: _link,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Link referensi (opsional)', prefixIcon: Icon(Icons.link)),
          validator: (v) => validateLink(v, required: false),
        ),
        if (_isEdit) ...[
          formGap,
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.flag_outlined)),
            items: [
              for (final s in _taskStatuses)
                DropdownMenuItem(value: s, child: Text(progressStatus(s).label)),
            ],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          if (_status == 'completed' && _origStatus != 'completed')
            const NoteBox(
              title: 'Tanpa verifikasi bukti',
              text: 'Anda akan diminta konfirmasi sebelum tugas ditandai selesai.',
              color: AppColors.warningOrange,
              icon: Icons.warning_amber,
            ),
        ],
      ],
    );
  }
}

// ── Ujian organ ───────────────────────────────────────────────────────────────

const List<String> organResults = ['terjadwal', 'lulus', 'tidak_lulus'];

/// Tambah (exam == null) atau edit ujian organ. [penilai] = daftar akun penilai
/// untuk memilih penguji. true bila tersimpan.
Future<bool> showOrganExamForm(BuildContext context,
    {required int userId, Map<String, dynamic>? exam, required List<dynamic> penilai}) async {
  final saved = await showDialog<bool>(
      context: context, builder: (_) => _OrganExamForm(userId: userId, exam: exam, penilai: penilai));
  return saved == true;
}

class _OrganExamForm extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? exam;
  final List<dynamic> penilai;
  const _OrganExamForm({required this.userId, this.exam, required this.penilai});

  @override
  State<_OrganExamForm> createState() => _OrganExamFormState();
}

class _OrganExamFormState extends State<_OrganExamForm> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  late final Map<String, dynamic> _e = widget.exam ?? const {};
  late final TextEditingController _nama = TextEditingController(text: textOf(_e['nama_ujian']));
  late final TextEditingController _organ = TextEditingController(text: textOf(_e['organ']));
  late final TextEditingController _nilai =
      TextEditingController(text: _e['nilai'] == null ? '' : formatNilai(_e['nilai']));
  late final TextEditingController _catatan = TextEditingController(text: textOf(_e['catatan']));
  late int? _pengujiId = _e['penguji_id'] as int?;
  late DateTime? _tanggal = parseDate(_e['tanggal']);
  late String _hasil = organResults.contains(_e['hasil']) ? _e['hasil'] as String : 'terjadwal';
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.exam != null;

  @override
  void dispose() {
    _nama.dispose();
    _organ.dispose();
    _nilai.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final data = <String, dynamic>{
      'nama_ujian': _nama.text.trim(),
      'organ': _organ.text.trim(),
      'penguji_id': _pengujiId,
      'tanggal': _tanggal == null ? null : isoDateOnly(_tanggal!),
      'hasil': _hasil,
      'nilai': parseScore(_nilai.text),
      'catatan': _catatan.text.trim(),
    };
    final ok = _isEdit
        ? await _api.adminUpdateOrganExam(_e['id'] as int, data)
        : await _api.adminAddOrganExam({'user_id': widget.userId, ...data});
    if (!mounted) return;
    if (ok) {
      showSnack(context, _isEdit ? 'Ujian organ diperbarui' : 'Ujian organ ditambahkan');
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Gagal menyimpan ujian organ. Periksa isian dan koneksi, lalu coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final legacyPenguji = textOf(_e['penguji']);
    return FormDialogFrame(
      title: _isEdit ? 'Edit ujian organ' : 'Tambah ujian organ',
      formKey: _formKey,
      busy: _busy,
      error: _error,
      submitText: _isEdit ? 'Simpan' : 'Tambah',
      onSubmit: _submit,
      children: [
        TextFormField(
          controller: _nama,
          decoration: const InputDecoration(
              labelText: 'Nama ujian', hintText: 'Mis. Ujian Organ Payudara', prefixIcon: Icon(Icons.medical_services_outlined)),
          validator: (v) => validateRequired(v, 'Nama ujian'),
        ),
        formGap,
        TextFormField(
          controller: _organ,
          decoration: const InputDecoration(labelText: 'Organ (opsional)', prefixIcon: Icon(Icons.biotech_outlined)),
        ),
        formGap,
        if (widget.penilai.isEmpty)
          const NoteBox(
            title: 'Belum ada akun penilai',
            text: 'Tambahkan akun Penilai / Dosen dari menu Pengguna agar penguji dapat dipilih.',
            color: AppColors.warningOrange,
            icon: Icons.person_off_outlined,
          )
        else
          PenilaiDropdown(
            label: 'Penguji',
            value: _pengujiId,
            penilai: widget.penilai,
            icon: Icons.how_to_reg_outlined,
            onChanged: (v) => setState(() => _pengujiId = v),
          ),
        if (_pengujiId == null && legacyPenguji.isNotEmpty)
          NoteBox(
            title: 'Penguji tercatat (teks)',
            text: '$legacyPenguji belum terhubung ke akun penilai, sehingga belum bisa mengisi hasil sendiri.',
            icon: Icons.info_outline,
          ),
        if (_pengujiId != null)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text('Penguji dapat mengisi hasil ujian ini dari akunnya sendiri.',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ),
        formGap,
        DateField(label: 'Tanggal ujian', value: _tanggal, onChanged: (d) => setState(() => _tanggal = d)),
        formGap,
        DropdownButtonFormField<String>(
          initialValue: _hasil,
          decoration: const InputDecoration(labelText: 'Hasil', prefixIcon: Icon(Icons.fact_check_outlined)),
          items: [for (final h in organResults) DropdownMenuItem(value: h, child: Text(examStatus(h).label))],
          onChanged: (v) => setState(() => _hasil = v ?? _hasil),
        ),
        formGap,
        TextFormField(
          controller: _nilai,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Nilai (opsional, 0-100)', prefixIcon: Icon(Icons.grade_outlined)),
          validator: (v) => validateScore(v),
        ),
        formGap,
        TextFormField(
          controller: _catatan,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(labelText: 'Catatan (opsional)', alignLabelWithHint: true),
        ),
      ],
    );
  }
}

// ── Stase / rotasi luar ───────────────────────────────────────────────────────

const List<String> rotationStatuses = ['terjadwal', 'berlangsung', 'selesai'];

/// Tambah (rotation == null) atau edit stase. true bila tersimpan.
Future<bool> showRotationForm(BuildContext context, {required int userId, Map<String, dynamic>? rotation}) async {
  final saved = await showDialog<bool>(
      context: context, builder: (_) => _RotationForm(userId: userId, rotation: rotation));
  return saved == true;
}

class _RotationForm extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? rotation;
  const _RotationForm({required this.userId, this.rotation});

  @override
  State<_RotationForm> createState() => _RotationFormState();
}

class _RotationFormState extends State<_RotationForm> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  late final Map<String, dynamic> _r = widget.rotation ?? const {};
  late final TextEditingController _hospital = TextEditingController(text: textOf(_r['hospital_name']));
  late final TextEditingController _dept = TextEditingController(text: textOf(_r['department']));
  late final TextEditingController _city = TextEditingController(text: textOf(_r['city']));
  late final TextEditingController _supervisor = TextEditingController(text: textOf(_r['supervisor']));
  late final TextEditingController _notes = TextEditingController(text: textOf(_r['notes']));
  late DateTime? _start = parseDate(_r['start_date']);
  late DateTime? _end = parseDate(_r['end_date']);
  late String _status = _initialStatus(_r['status']);
  bool _busy = false;
  String? _error;
  String? _dateError;

  bool get _isEdit => widget.rotation != null;

  static String _initialStatus(dynamic s) {
    if (s == 'aktif') return 'berlangsung';
    return rotationStatuses.contains(s) ? s as String : 'terjadwal';
  }

  @override
  void dispose() {
    _hospital.dispose();
    _dept.dispose();
    _city.dispose();
    _supervisor.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final datesOk = _start == null || _end == null || !_end!.isBefore(_start!);
    setState(() => _dateError = datesOk ? null : 'Tanggal selesai tidak boleh sebelum tanggal mulai');
    if (!_formKey.currentState!.validate() || !datesOk) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final data = <String, dynamic>{
      'hospital_name': _hospital.text.trim(),
      'department': _dept.text.trim(),
      'city': _city.text.trim(),
      'supervisor': _supervisor.text.trim(),
      'start_date': _start == null ? null : isoDateOnly(_start!),
      'end_date': _end == null ? null : isoDateOnly(_end!),
      'status': _status,
      'notes': _notes.text.trim(),
    };
    final ok = _isEdit
        ? await _api.adminSaveRotation(_r['id'] as int, data)
        : await _api.adminCreateRotation({'user_id': widget.userId, ...data});
    if (!mounted) return;
    if (ok) {
      showSnack(context, _isEdit ? 'Stase diperbarui' : 'Stase ditambahkan');
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = _api.lastError ?? 'Gagal menyimpan stase.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialogFrame(
      title: _isEdit ? 'Edit stase' : 'Tambah stase',
      formKey: _formKey,
      busy: _busy,
      error: _error,
      submitText: _isEdit ? 'Simpan' : 'Tambah',
      onSubmit: _submit,
      children: [
        TextFormField(
          controller: _hospital,
          decoration: const InputDecoration(labelText: 'Nama rumah sakit', prefixIcon: Icon(Icons.local_hospital_outlined)),
          validator: (v) => validateRequired(v, 'Nama rumah sakit'),
        ),
        formGap,
        TextFormField(
          controller: _dept,
          decoration: const InputDecoration(labelText: 'Departemen / bagian', prefixIcon: Icon(Icons.apartment_outlined)),
        ),
        formGap,
        TextFormField(
          controller: _city,
          decoration: const InputDecoration(labelText: 'Kota', prefixIcon: Icon(Icons.location_city_outlined)),
        ),
        formGap,
        TextFormField(
          controller: _supervisor,
          decoration: const InputDecoration(labelText: 'Supervisor', prefixIcon: Icon(Icons.supervisor_account_outlined)),
        ),
        formGap,
        DateField(label: 'Tanggal mulai', value: _start, onChanged: (d) => setState(() => _start = d)),
        formGap,
        DateField(
          label: 'Tanggal selesai',
          value: _end,
          errorText: _dateError,
          onChanged: (d) => setState(() {
            _end = d;
            _dateError = null;
          }),
        ),
        formGap,
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.flag_outlined)),
          items: [
            for (final s in rotationStatuses) DropdownMenuItem(value: s, child: Text(rotationStatus(s).label)),
          ],
          onChanged: (v) => setState(() => _status = v ?? _status),
        ),
        formGap,
        TextFormField(
          controller: _notes,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(labelText: 'Catatan (opsional)', alignLabelWithHint: true),
        ),
      ],
    );
  }
}
