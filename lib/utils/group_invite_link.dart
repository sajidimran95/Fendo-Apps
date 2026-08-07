/// Helpers for group invite tokens / share links.
///
/// Backend `invite_link` is often the raw API route:
///   POST /api/v1/groups/join/{token}
/// Opening that in a browser does a **GET** → Laravel:
///   "The GET method is not supported..."
///
/// Share a human link + code; join always happens inside the app via POST.
class GroupInviteLink {
  GroupInviteLink._();

  /// Public website host used for shareable join links (not the API host).
  static const String websiteHost = 'https://fendo.posquickcart.com';

  static String extractToken(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    // Full URL / path → last non-empty segment.
    if (s.contains('/')) {
      final parts = s.split('/').where((p) {
        final t = p.trim();
        return t.isNotEmpty && !t.contains('?');
      }).toList();
      if (parts.isEmpty) return s;
      var last = parts.last;
      // strip query
      final q = last.indexOf('?');
      if (q >= 0) last = last.substring(0, q);
      return last.trim();
    }
    return s;
  }

  /// True if this is the raw API join endpoint (must not be opened in a browser).
  static bool isApiJoinUrl(String link) {
    final lower = link.toLowerCase();
    return lower.contains('/api/') && lower.contains('/groups/join/');
  }

  /// Shareable HTTPS link (opens website or app deep link intent).
  /// Never returns a POST-only API URL.
  static String shareableLink(String token) {
    final t = extractToken(token);
    if (t.isEmpty) return websiteHost;
    return '$websiteHost/join/$t';
  }

  /// Simple share text: download app + register only.
  static String shareMessage({
    required String token,
    String? inviteLink,
    List<String> contactNames = const [],
    List<String> contactNumbers = const [],
    List<String> contactEmails = const [],
  }) {
    // Keep signature for callers; we don't put codes/links/join steps.
    return 'Hi! Download the Fendo app and register.\n'
        'Website: $websiteHost';
  }

  /// Normalize API invite result into token + safe share link.
  static ({String token, String shareLink, String? expiresAt}) normalize({
    required String inviteToken,
    required String inviteLink,
    String? expiresAt,
  }) {
    var token = inviteToken.trim();
    if (token.isEmpty) {
      token = extractToken(inviteLink);
    }
    final shareLink = isApiJoinUrl(inviteLink) || inviteLink.trim().isEmpty
        ? shareableLink(token)
        : (inviteLink.contains('/groups/join/')
            ? shareableLink(extractToken(inviteLink))
            : inviteLink.trim());
    return (token: token, shareLink: shareLink, expiresAt: expiresAt);
  }
}
