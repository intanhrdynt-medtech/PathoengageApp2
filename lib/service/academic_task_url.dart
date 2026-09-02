bool isUsableEvidenceUrl(String? value) {
  if (value == null) return false;

  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  if (!uri.hasScheme || !uri.hasAuthority) return false;

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;

  if (uri.host.isEmpty) return false;

  return true;
}
