import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/admin/admin_common.dart';
import 'package:fp_pemrograman/screens/admin/ppds_forms.dart';
import 'package:fp_pemrograman/screens/admin/verification_sheet.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Isi tab Kompetensi / Ujian / Tugas di halaman detail PPDS (admin).
/// Data berasal dari GET /admin/progress/<uid>.

List<Map<String, dynamic>> _itemsOf(Map<String, dynamic> progress, String key) {
  final section = progress[key];
  final items = section is Map ? section['items'] : null;
  if (items is! List) return [];
  return [for (final i in items) Map<String, dynamic>.from(i as Map)];
}

/// Membuka lembar verifikasi untuk item milik PPDS ini; [onChanged] dipanggil
/// bila pengajuan diproses.
Future<void> _verify(BuildContext context, Map<String, dynamic> raw, String category, String ppdsName,
    VoidCallback onChanged) async {
  final item = VerifItem.fromPending({...raw, 'type_category': category}, userName: ppdsName);
  final msg = await showVerificationSheet(context, item);
  if (!context.mounted || msg == null) return;
  showSnack(context, msg);
  onChanged();
}

class _TabList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  const _TabList({required this.onRefresh, required this.children});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AdminListView(maxWidth: 1000, children: children),
    );
  }
}

class _PendingButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _PendingButton({required this.onPressed});

  @override
  Widget build(BuildContext context) =>
      FilledButton.tonalIcon(onPressed: onPressed, icon: const Icon(Icons.fact_check_outlined, size: 18), label: const Text('Periksa'));
}

// ── Kompetensi ────────────────────────────────────────────────────────────────

class AdminCompetencyTab extends StatelessWidget {
  final Map<String, dynamic> progress;
  final String ppdsName;
  final String? currentPhase;
  final Future<void> Function() onRefresh;
  final VoidCallback onChanged;
  const AdminCompetencyTab({super.key, required this.progress, required this.ppdsName, required this.currentPhase,
      required this.onRefresh, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = _itemsOf(progress, 'competencies');
    if (items.isEmpty) {
      return _TabList(onRefresh: onRefresh, children: const [
        EmptyState(icon: Icons.star_outline, title: 'Belum ada kompetensi', message: 'Kurikulum kompetensi PPDS ini kosong.'),
      ]);
    }
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final c in items) {
      grouped.putIfAbsent(textOf(c['phase_category']).isEmpty ? 'lainnya' : textOf(c['phase_category']), () => []).add(c);
    }
    final order = [...phaseOrder.where(grouped.containsKey), ...grouped.keys.where((k) => !phaseOrder.contains(k))];
    final pending = items.where((c) => c['status'] == 'pending_verification').length;
    final done = items.where((c) => c['status'] == 'completed').length;

    return _TabList(onRefresh: onRefresh, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProgressLine(label: 'Kompetensi selesai', done: done, total: items.length, color: AppColors.successGreen),
          Text(pending == 0 ? 'Tidak ada yang menunggu verifikasi.' : '$pending kompetensi menunggu verifikasi.',
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
        ]),
      ),
      for (final phase in order) _phaseGroup(context, phase, grouped[phase]!),
    ]);
  }

  Widget _phaseGroup(BuildContext context, String phase, List<Map<String, dynamic>> list) {
    final done = list.where((c) => c['status'] == 'completed').length;
    final pending = list.where((c) => c['status'] == 'pending_verification').length;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: phase == currentPhase || pending > 0,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            phase == 'lainnya' ? const TagChip('Lainnya', color: AppColors.neutralGrey) : PhaseBadge(phase),
            Text('$done / ${list.length} selesai',
                style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
            if (pending > 0) TagChip('$pending menunggu', color: AppColors.infoBlue),
          ]),
          children: [
            for (final c in list) ...[
              const Divider(height: 1, color: AppColors.cardBorder),
              _competencyRow(context, c),
            ],
          ],
        ),
      ),
    );
  }

  Widget _competencyRow(BuildContext context, Map<String, dynamic> c) {
    final status = progressStatus(c['status'], alasanTolak: c['alasan_tolak'] as String?);
    final isPending = c['status'] == 'pending_verification';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(textOf(c['competency_name']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              if (textOf(c['organ_system']).isNotEmpty)
                Text(textOf(c['organ_system']), style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              if (c['completed_at'] != null)
                Text('Selesai ${formatTanggal(c['completed_at'], serverTimestamp: true)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ]),
          ),
          const SizedBox(width: 8),
          StatusChip(status),
        ]),
        if (textOf(c['alasan_tolak']).isNotEmpty && !isPending)
          NoteBox(title: 'Alasan penolakan', text: textOf(c['alasan_tolak']), color: AppColors.errorRed, icon: Icons.error_outline),
        if (textOf(c['evidence_url']).isNotEmpty || isPending)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              LinkButton(label: 'Buka bukti', url: c['evidence_url'] as String?),
              const Spacer(),
              if (isPending) _PendingButton(onPressed: () => _verify(context, c, 'competency', ppdsName, onChanged)),
            ]),
          ),
      ]),
    );
  }
}

// ── Ujian (lokal / nasional) ──────────────────────────────────────────────────

class AdminExamTab extends StatelessWidget {
  final Map<String, dynamic> progress;
  final String ppdsName;
  final Future<void> Function() onRefresh;
  final VoidCallback onChanged;
  const AdminExamTab({super.key, required this.progress, required this.ppdsName, required this.onRefresh,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = _itemsOf(progress, 'exams');
    int rank(Map<String, dynamic> e) {
      final i = phaseOrder.indexOf(textOf(e['phase_category']));
      return i < 0 ? 99 : i;
    }

    items.sort((a, b) => rank(a).compareTo(rank(b)));
    final passed = items.where((e) => e['result'] == 'lulus').length;

    return _TabList(onRefresh: onRefresh, children: [
      if (items.isEmpty)
        const EmptyState(icon: Icons.assignment_turned_in_outlined, title: 'Belum ada ujian')
      else ...[
        AppCard(child: ProgressLine(label: 'Ujian lulus', done: passed, total: items.length, color: AppColors.infoBlue)),
        for (final e in items) _examCard(context, e),
      ],
    ]);
  }

  Widget _examCard(BuildContext context, Map<String, dynamic> e) {
    final isPending = e['result'] == 'pending_verification';
    final meta = [
      if (textOf(e['exam_type']).isNotEmpty) textOf(e['exam_type']),
      if (textOf(e['phase_category']).isNotEmpty) phaseLabel(e['phase_category']),
      if (textOf(e['scheduled_date']).isNotEmpty) 'Jadwal ${formatTanggal(e['scheduled_date'])}',
      if (e['score'] != null) 'Nilai ${formatNilai(e['score'])}',
    ];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(textOf(e['exam_name']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (meta.isNotEmpty)
                Text(meta.join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ]),
          ),
          const SizedBox(width: 8),
          StatusChip(examStatus(e['result'], alasanTolak: e['alasan_tolak'] as String?)),
        ]),
        if (textOf(e['notes']).isNotEmpty)
          NoteBox(
            title: 'Syarat',
            text: _syaratText(textOf(e['notes'])),
            icon: Icons.rule,
          ),
        if (textOf(e['alasan_tolak']).isNotEmpty && !isPending)
          NoteBox(
              title: e['result'] == 'tidak_lulus' ? 'Keterangan' : 'Alasan penolakan',
              text: textOf(e['alasan_tolak']),
              color: AppColors.errorRed,
              icon: Icons.error_outline),
        if (textOf(e['evidence_url']).isNotEmpty || isPending)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              LinkButton(label: 'Buka bukti', url: e['evidence_url'] as String?),
              const Spacer(),
              if (isPending) _PendingButton(onPressed: () => _verify(context, e, 'exam', ppdsName, onChanged)),
            ]),
          ),
      ]),
    );
  }
}

// ── Tugas akademik ────────────────────────────────────────────────────────────

class AdminTaskTab extends StatelessWidget {
  final Map<String, dynamic> progress;
  final int ppdsId;
  final String ppdsName;
  final Future<void> Function() onRefresh;
  final VoidCallback onChanged;
  const AdminTaskTab({super.key, required this.progress, required this.ppdsId, required this.ppdsName,
      required this.onRefresh, required this.onChanged});

  Future<void> _edit(BuildContext context, [Map<String, dynamic>? task]) async {
    final saved = await showTaskForm(context, userId: ppdsId, task: task);
    if (saved) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final items = _itemsOf(progress, 'academic_tasks');
    final bySemester = <int, List<Map<String, dynamic>>>{};
    for (final t in items) {
      bySemester.putIfAbsent((t['target_semester'] as num?)?.toInt() ?? 0, () => []).add(t);
    }
    final semesters = bySemester.keys.toList()..sort();
    final done = items.where((t) => t['is_completed'] == true).length;

    return _TabList(onRefresh: onRefresh, children: [
      SectionTitle(
        'Tugas akademik',
        trailing: FilledButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah tugas'),
        ),
      ),
      if (items.isEmpty)
        const EmptyState(icon: Icons.task_outlined, title: 'Belum ada tugas akademik')
      else ...[
        AppCard(
            child: ProgressLine(label: 'Tugas selesai', done: done, total: items.length, color: AppColors.primaryPurple)),
        for (final s in semesters) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(s == 0 ? 'Tanpa target semester' : 'Target semester $s',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textGrey)),
          ),
          for (final t in bySemester[s]!) _taskCard(context, t),
        ],
      ],
    ]);
  }

  Widget _taskCard(BuildContext context, Map<String, dynamic> t) {
    final isPending = t['status'] == 'pending_verification';
    final meta = [
      if (textOf(t['task_type']).isNotEmpty) textOf(t['task_type']),
      if (textOf(t['deadline']).isNotEmpty) 'Tenggat ${formatTanggal(t['deadline'])}',
    ];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(textOf(t['title']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (meta.isNotEmpty) Text(meta.join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ]),
          ),
          const SizedBox(width: 8),
          StatusChip(progressStatus(t['status'],
              isCompleted: t['is_completed'] == true, alasanTolak: t['alasan_tolak'] as String?)),
        ]),
        if (textOf(t['description']).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(textOf(t['description']), style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
        ],
        if (textOf(t['notes']).isNotEmpty)
          NoteBox(title: 'Resume PPDS', text: textOf(t['notes']), color: AppColors.primaryPurple, icon: Icons.notes),
        if (textOf(t['alasan_tolak']).isNotEmpty && !isPending)
          NoteBox(title: 'Alasan penolakan', text: textOf(t['alasan_tolak']), color: AppColors.errorRed, icon: Icons.error_outline),
        const SizedBox(height: 6),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 4, children: [
          LinkButton(label: 'Referensi', url: t['link_url'] as String?),
          LinkButton(label: 'Bukti', url: t['document_proof_url'] as String?),
          TextButton.icon(
            onPressed: () => _edit(context, t),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
          if (isPending) _PendingButton(onPressed: () => _verify(context, t, 'academic', ppdsName, onChanged)),
        ]),
      ]),
    );
  }
}

/// Teks syarat bawaan diawali "Syarat ..." — label "Syarat" sudah ditampilkan.
String _syaratText(String s) {
  final cleaned = s.replaceFirst(RegExp(r'^syarat\b\s*:?\s*', caseSensitive: false), '');
  if (cleaned.isEmpty) return s;
  return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
}
