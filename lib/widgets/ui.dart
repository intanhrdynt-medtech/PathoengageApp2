import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/login_screen.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/service/auth_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:url_launcher/url_launcher.dart';

/// Komponen UI bersama. Semua layar memakai komponen ini supaya tampilan,
/// istilah, dan perilaku (konfirmasi, pesan sukses/gagal) seragam.

// ── Teks & tata letak ─────────────────────────────────────────────────────────

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Kartu standar: putih, sudut 16, garis tipis.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap,
      this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor ?? AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Membatasi lebar konten di layar lebar (web/desktop) supaya tetap enak dibaca.
class MaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const MaxWidth({super.key, required this.child, this.maxWidth = 900});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

// ── Status & kalung ───────────────────────────────────────────────────────────

class StatusChip extends StatelessWidget {
  final StatusInfo info;
  final bool dense;
  const StatusChip(this.info, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: dense ? 13 : 15, color: info.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(info.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: info.color, fontWeight: FontWeight.w600, fontSize: dense ? 11 : 12)),
          ),
        ],
      ),
    );
  }
}

class PhaseBadge extends StatelessWidget {
  final String? phase;
  final bool onDark;
  const PhaseBadge(this.phase, {super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final color = phaseColor(phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(phaseLabel(phase), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

/// Kotak pesan berwarna (alasan penolakan, catatan penilai, info).
class NoteBox extends StatelessWidget {
  final String title;
  final String text;
  final Color color;
  final IconData icon;
  const NoteBox({super.key, required this.title, required this.text, this.color = AppColors.infoBlue,
      this.icon = Icons.info_outline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
          ]),
        ),
      ]),
    );
  }
}

// ── State: memuat / kosong / gagal ───────────────────────────────────────────

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: AppColors.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, this.message = 'Gagal memuat data. Periksa koneksi internet.', required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off,
      title: 'Terjadi kendala',
      message: message,
      action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
    );
  }
}

// ── Umpan balik & dialog ─────────────────────────────────────────────────────

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.errorRed : AppColors.textDark,
      behavior: SnackBarBehavior.floating,
    ));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirmText = 'Ya, lanjutkan', bool danger = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: danger ? AppColors.errorRed : AppColors.primaryPurple,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result == true;
}

/// Validasi link bukti/dokumen. Link tanpa "https://" diterima (server
/// melengkapinya).
String? validateLink(String? value, {bool required = true}) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return required ? 'Link wajib diisi' : null;
  if (v.contains(' ')) return 'Link tidak boleh mengandung spasi';
  final withScheme = v.contains('://') ? v : 'https://$v';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || !uri.host.contains('.')) {
    return 'Masukkan link yang valid, mis. https://drive.google.com/...';
  }
  return null;
}

Future<void> openLink(BuildContext context, String? url) async {
  final v = (url ?? '').trim();
  if (v.isEmpty) return;
  try {
    final ok = await launchUrl(Uri.parse(v.contains('://') ? v : 'https://$v'), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showSnack(context, 'Link tidak bisa dibuka', error: true);
  } catch (_) {
    if (context.mounted) showSnack(context, 'Link tidak bisa dibuka', error: true);
  }
}

class LinkButton extends StatelessWidget {
  final String label;
  final String? url;
  const LinkButton({super.key, required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    if ((url ?? '').isEmpty) return const SizedBox.shrink();
    return TextButton.icon(
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
      onPressed: () => openLink(context, url),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(label),
    );
  }
}

/// Dialog standar untuk mengirim link bukti (+ catatan opsional).
/// Mengembalikan {link, catatan} atau null bila dibatalkan.
Future<Map<String, String>?> showSubmitLinkDialog(
  BuildContext context, {
  required String title,
  String? description,
  String linkLabel = 'Link bukti (Google Drive, dll.)',
  String? initialLink,
  bool withNotes = false,
  bool notesRequired = false,
  String notesLabel = 'Catatan / resume',
  String? initialNotes,
  String submitText = 'Kirim untuk diverifikasi',
}) {
  final linkCtrl = TextEditingController(text: initialLink ?? '');
  final notesCtrl = TextEditingController(text: initialNotes ?? '');
  final formKey = GlobalKey<FormState>();
  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      content: SizedBox(
        width: 440,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (description != null) ...[
                Text(description, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                const SizedBox(height: 12),
              ],
              if (withNotes) ...[
                TextFormField(
                  controller: notesCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: notesLabel, alignLabelWithHint: true),
                  validator: (v) => notesRequired && (v ?? '').trim().isEmpty ? '$notesLabel wajib diisi' : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: linkCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: linkLabel, hintText: 'https://drive.google.com/...',
                    prefixIcon: const Icon(Icons.link)),
                // Dengan catatan/resume, link bersifat opsional.
                validator: (v) => validateLink(v, required: !withNotes),
              ),
              const SizedBox(height: 6),
              const Text('Pastikan link bisa dibuka oleh admin/penilai (akses "Siapa saja yang memiliki link").',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx, {'link': linkCtrl.text.trim(), 'catatan': notesCtrl.text.trim()});
          },
          child: Text(submitText),
        ),
      ],
    ),
  );
}

// ── Akun: logout & notifikasi ─────────────────────────────────────────────────

Future<void> logoutWithConfirm(BuildContext context) async {
  final ok = await confirmDialog(context, title: 'Keluar dari akun?', message: 'Anda perlu login lagi untuk masuk.',
      confirmText: 'Keluar', danger: true);
  if (!ok) return;
  await AuthService().signOut();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
}

/// Ikon lonceng dengan jumlah notifikasi belum dibaca. Mengetuknya membuka
/// daftar notifikasi. [onChanged] dipanggil setelah notifikasi dibuka supaya
/// layar induk bisa memuat ulang datanya.
class NotificationBell extends StatefulWidget {
  final VoidCallback? onChanged;
  final Color color;
  const NotificationBell({super.key, this.onChanged, this.color = Colors.white});

  @override
  State<NotificationBell> createState() => NotificationBellState();
}

class NotificationBellState extends State<NotificationBell> {
  final ApiService _api = ApiService();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final data = await _api.getNotifications();
    if (!mounted || data == null) return;
    setState(() => _unread = (data['unread'] as num?)?.toInt() ?? 0);
  }

  Future<void> _open() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NotificationSheet(),
    );
    await refresh();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifikasi',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: Icon(Icons.notifications_outlined, color: widget.color),
      ),
    );
  }
}

class _NotificationSheet extends StatefulWidget {
  const _NotificationSheet();
  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  final ApiService _api = ApiService();
  List<dynamic>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _api.getNotifications();
    if (!mounted) return;
    setState(() {
      _error = data == null;
      _items = data?['items'] as List<dynamic>? ?? [];
    });
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'verifikasi':
        return Icons.fact_check;
      case 'journal':
        return Icons.article;
      case 'penelitian':
        return Icons.science;
      case 'penilaian':
        return Icons.grade;
      case 'ujian':
        return Icons.assignment_turned_in;
      case 'kalung':
        return Icons.military_tech;
      case 'peringatan':
        return Icons.warning_amber;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(children: [
              const Expanded(child: Text('Notifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              TextButton(
                onPressed: () async {
                  await _api.markAllNotificationsRead();
                  _load();
                },
                child: const Text('Tandai semua dibaca'),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _items == null
                ? const LoadingView()
                : _error
                    ? ErrorState(onRetry: _load)
                    : _items!.isEmpty
                        ? const EmptyState(icon: Icons.notifications_none, title: 'Belum ada notifikasi')
                        : ListView.separated(
                            itemCount: _items!.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final n = _items![i] as Map<String, dynamic>;
                              final unread = n['is_read'] != true;
                              return ListTile(
                                tileColor: unread ? AppColors.lightPurpleAccent.withValues(alpha: 0.35) : null,
                                leading: Icon(_icon(n['type']), color: AppColors.primaryPurple),
                                title: Text(n['title'] ?? '-',
                                    style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500, fontSize: 14)),
                                subtitle: Text(
                                    '${n['message'] ?? ''}\n${formatTanggal(n['created_at'], withTime: true, serverTimestamp: true)}',
                                    style: const TextStyle(fontSize: 12)),
                                isThreeLine: true,
                                onTap: unread
                                    ? () async {
                                        await _api.markNotificationRead(n['id']);
                                        _load();
                                      }
                                    : null,
                              );
                            },
                          ),
          ),
        ]),
      ),
    );
  }
}
