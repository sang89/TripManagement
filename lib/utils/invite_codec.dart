import 'dart:convert';
import 'dart:typed_data';

/// Converts UUID invite codes to/from compact 22-char Base64url strings.
///
/// Raw UUID:  25b282ec-8cfc-4a7b-b8e9-1234567890ab  (36 chars)
/// Encoded:   JbKC7Iz8Snu46RIzVniQqw                (22 chars)
///
/// The encoding is purely cosmetic — it makes URLs shorter and QR codes
/// denser without changing the underlying security properties of the UUID.
/// All DB operations always use the raw UUID form.
class InviteCodec {
  static final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// UUID string → 22-char Base64url code (no padding).
  static String encode(String uuid) {
    final hex = uuid.replaceAll('-', '');
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Accepts either a 22-char encoded code or a raw UUID and returns a UUID.
  /// Throws [FormatException] if the input is neither.
  static String decode(String code) {
    final trimmed = code.trim();
    if (_uuidRe.hasMatch(trimmed)) return trimmed; // already a UUID
    // Add Base64 padding back (must be a multiple of 4)
    final padded = trimmed.padRight((trimmed.length + 3) ~/ 4 * 4, '=');
    final bytes = base64Url.decode(padded);
    if (bytes.length != 16) throw const FormatException('Invalid invite code');
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Extracts and decodes an invite code from any of these inputs:
  ///   • Full URL:        https://tripmanagement.app/session/invite/JbKC7Iz8Snu…
  ///   • 22-char code:   JbKC7Iz8Snu46RIzVniQqw
  ///   • Raw UUID:        25b282ec-8cfc-4a7b-b8e9-1234567890ab
  ///
  /// Returns the raw UUID, or null if nothing recognisable is found.
  static String? extract(String raw) {
    // 1. URL with /invite/<code> path segment
    final urlMatch =
        RegExp(r'/invite/([A-Za-z0-9_-]{22,36})').firstMatch(raw);
    if (urlMatch != null) {
      try {
        return decode(urlMatch.group(1)!);
      } catch (_) {}
    }
    // 2. Standalone 22-char encoded code
    if (RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(raw.trim())) {
      try {
        return decode(raw.trim());
      } catch (_) {}
    }
    // 3. Raw UUID anywhere in the string
    final uuidMatch = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    ).firstMatch(raw);
    if (uuidMatch != null) return uuidMatch.group(0)!;
    return null;
  }
}
