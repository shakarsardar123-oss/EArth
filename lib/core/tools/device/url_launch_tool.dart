import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../device/device_channel.dart';
import '../../../core/errors/result.dart';

/// Allowed URL schemes. Only http and https are permitted.
const List<String> _allowedSchemes = ['http', 'https'];

/// Forbidden URL schemes that must be rejected to prevent
/// security vulnerabilities (XSS, data exfiltration, local file access).
const List<String> _forbiddenSchemes = [
  'javascript',
  'data',
  'file',
  'intent',
  'about',
];

/// Shell metacharacters and patterns that must never appear anywhere
/// in a URL. These characters are not valid in normal URL paths
/// and indicate injection attempts.
const List<String> _forbiddenPatterns = [
  ';', // shell command separator
  '|', // shell pipe
  '`', // shell command substitution
  r'$', // shell variable expansion
  '(', // shell subshell
  ')', // shell subshell
  '{', // shell brace expansion
  '}', // shell brace expansion
  '>', // shell redirection
  '<', // shell redirection / HTML tag injection
  '!', // shell history expansion
  '&&', // shell AND operator
  '..', // path traversal
  '\n', // newline injection
  '\r', // carriage return injection
];

/// Regular expression to detect remaining control characters
/// (U+0000–U+0008, U+0009 TAB, U+000B–U+000C, U+000E–U+001F, U+007F).
/// Excludes \n (\x0A) and \r (\x0D) which are handled by
/// [_forbiddenPatterns] with a 'forbidden' error message.
/// Tab (\x09) IS included here so its error says 'control characters'.
final RegExp _controlCharPattern =
    RegExp(r'[\x00-\x09\x0B\x0C\x0E-\x1F\x7F]');

/// Maximum allowed length for a URL.
const int _maxUrlLength = 2048;

/// Regular expression for a valid host segment (label):
/// alphanumeric, hyphens (not at start/end), and dots between labels.
final RegExp _validHostPattern = RegExp(
  r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$',
);

/// Tool to open a URL in the default browser.
///
/// This is a **controlled** action — it opens a URL via the
/// [DeviceChannel] abstraction using Android's Intent system.
///
/// **Security guarantees:**
/// - Only `http` and `https` schemes are allowed.
/// - Forbidden schemes are explicitly rejected: `javascript`, `data`,
///   `file`, `intent`, `about`.
/// - Shell metacharacters are forbidden anywhere in the URL to
///   prevent injection attacks (even though DeviceChannel does not
///   use shell execution, this is a defence-in-depth measure).
/// - URLs containing control characters are rejected.
/// - The host is validated against a valid hostname pattern.
/// - No `Runtime.exec`, `ProcessBuilder`, or shell commands are used.
/// - The native side uses `ACTION_VIEW` Intent with the URI — if
///   the URL is malformed, Android will fail to resolve it.
/// - The URL is passed through [ToolRegistry.sanitizeArguments]
///   at the registry level as an additional defence-in-depth layer.
///
/// **Risk level:** [ToolRiskLevel.low] — the tool has a visible side
/// effect (opening a browser) but is not destructive or irreversible.
/// No user confirmation is required by default.
///
/// **Permission:** [ToolPermission.system] — launching URLs is a
/// system-level capability.
class UrlLaunchTool extends Tool {
  final DeviceChannel _deviceChannel;

  UrlLaunchTool(this._deviceChannel);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'url_launch',
        description:
            'بەستەرێک بکەرەوە لە وێبگەرەکەدا (تەنها http/https). '
            '— '
            'Open a URL in the default browser '
            '(only http and https schemes are allowed).',
        category: 'device',
        parameters: [
          ToolArgumentDef(
            name: 'url',
            type: 'string',
            description:
                'بەستەری تەواو (https://example.com). تەنها http و https ڕێگەپێدراون. '
                '— '
                'Full URL to open (https://example.com). '
                'Only http and https schemes are allowed.',
            isRequired: true,
            example: 'https://example.com',
            label: 'بەستەر',
            hintText: 'https://example.com',
            keyboardType: 'url',
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.system,
            isRequired: true,
            rationale:
                'پێویستە ڕێگەی سیستەم بۆ کردنەوەی بەستەر. '
                '— '
                'System permission is required to launch URLs.',
          ),
        ],
        isDangerous: false,
        requiresConfirmation: false,
        tags: [
          'device',
          'url',
          'browser',
          'open',
          'بەستەر',
          'وێبگەر',
          'بکەرەوە',
        ],
        icon: 'open_in_browser',
        timeout: Duration(seconds: 15),
        riskLevel: ToolRiskLevel.low,
      );

  @override
  String? validateArguments(ToolArguments arguments) {
    final url = arguments.getString('url');

    // 1. Must not be null or empty
    if (url == null || url.isEmpty) {
      return 'url is required and cannot be empty. '
          '— بەستەر پێویستە و نابێت بەتاڵ بێت.';
    }

    // 2. Must not be just whitespace
    if (url.trim().isEmpty) {
      return 'url cannot be whitespace only. '
          '— بەستەر نابێت تەنها بۆشایی سپێیس بێت.';
    }

    // 3. Must not exceed maximum length
    if (url.length > _maxUrlLength) {
      return 'url exceeds maximum length of $_maxUrlLength characters. '
          '— بەستەر لە $_maxUrlLength پیت زیاترە.';
    }

    // 4. Extract and validate scheme FIRST (before pattern checks,
    //    so that forbidden-scheme errors take priority over
    //    character-level errors like '(' in javascript:alert(1))
    final scheme = _extractScheme(url);
    if (scheme == null || scheme.isEmpty) {
      return 'url must include a scheme (http:// or https://). '
          '— بەستەر دەبێت شێوەکاری لەخۆ بگرێت (http:// یان https://).';
    }

    final lowerScheme = scheme.toLowerCase();

    // 5. Reject forbidden schemes (javascript, data, file, intent, about)
    if (_forbiddenSchemes.contains(lowerScheme)) {
      return 'url scheme "$lowerScheme" is not allowed. '
          'Only http and https are permitted. '
          '— شێوەکاری "$lowerScheme" ڕێگەپێدراو نییە. '
          'تەنها http و https ڕێگەپێدراون.';
    }

    // 6. Only http and https are allowed
    if (!_allowedSchemes.contains(lowerScheme)) {
      return 'url scheme must be http or https. Got "$lowerScheme". '
          '— شێوەکاری بەستەر دەبێت http یان https بێت. '
          '"$lowerScheme" نادروستە.';
    }

    // 7. Must not contain forbidden patterns (shell metacharacters,
    //    injection patterns, newlines)
    for (final pattern in _forbiddenPatterns) {
      if (url.contains(pattern)) {
        return 'url contains forbidden pattern "$pattern". '
            '— بەستەر شێوەکاری نادروست "$pattern" لەخۆ دەگرێت.';
      }
    }

    // 8. Must not contain control characters
    if (_controlCharPattern.hasMatch(url)) {
      return 'url contains control characters which are not allowed. '
          '— بەستەر پیتی کۆنترۆڵی تێدایە کە ڕێگەپێدراو نین.';
    }

    // 9. Extract and validate the host part
    final host = _extractHost(url);
    if (host == null || host.isEmpty || host.trim().isEmpty) {
      return 'url must have a host after the scheme. '
          '— بەستەر دەبێت ناوی خزمەتگوزاری لەدوای شێوەکاری هەبێت.';
    }

    // 10. Host must be a valid hostname (letters, digits, hyphens, dots)
    final hostForValidation = _stripPort(host);
    if (!_validHostPattern.hasMatch(hostForValidation)) {
      return 'url host is not a valid hostname. '
          '— ناوی خزمەتگوزاری دروست نییە.';
    }

    return null; // Valid
  }

  /// Extracts the scheme from a URL string by splitting on the first `:`.
  ///
  /// This handles both `scheme://host` (e.g. `https://`) and
  /// `scheme:value` (e.g. `about:blank`, `mailto:user@host`) formats.
  String? _extractScheme(String url) {
    final colonIndex = url.indexOf(':');
    if (colonIndex <= 0) return null;
    return url.substring(0, colonIndex);
  }

  /// Extracts the host (including optional port) from a URL string.
  ///
  /// Returns everything between `://` and the first `/`, `?`, or `#`
  /// after the scheme separator. Returns null if no `://` is found
  /// or the host part is empty.
  String? _extractHost(String url) {
    final schemeEnd = url.indexOf('://');
    if (schemeEnd < 0) return null;

    final afterScheme = url.substring(schemeEnd + 3);
    if (afterScheme.isEmpty) return null;

    // Host ends at the first /, ?, or # (path/query/fragment start)
    final endIndex = afterScheme.indexOf(RegExp(r'[/?#]'));
    if (endIndex < 0) return afterScheme;
    return afterScheme.substring(0, endIndex);
  }

  /// Strips a port number from a host string.
  ///
  /// `example.com:8080` → `example.com`
  /// `example.com` → `example.com`
  String _stripPort(String host) {
    final colonIndex = host.lastIndexOf(':');
    if (colonIndex < 0) return host;
    // Only strip if the part after colon is numeric (port)
    final afterColon = host.substring(colonIndex + 1);
    if (RegExp(r'^\d+$').hasMatch(afterColon)) {
      return host.substring(0, colonIndex);
    }
    return host; // IPv6 or other — keep as-is
  }

  @override
  Future<ToolResult> execute(ToolArguments arguments) async {
    // Validate arguments first
    final validationError = validateArguments(arguments);
    if (validationError != null) {
      return ToolResult.failure(
        validationError,
        errorCode: 'invalidArguments',
      );
    }

    final url = arguments.getString('url')!;

    try {
      final result = await _deviceChannel.launchUrl(url);

      if (!result.isSuccess) {
        return ToolResult.failure(
          result.errorMessage ?? 'URL launch failed',
          errorCode: result.errorCode,
        );
      }

      // Enrich success result with the URL for traceability
      final data = Map<String, dynamic>.from(result.data ?? {});
      data['url'] = url;

      return ToolResult.success(data);
    } catch (e) {
      return ToolResult.failure(
        'URL launch error: $e',
        errorCode: 'internalError',
      );
    }
  }
}
