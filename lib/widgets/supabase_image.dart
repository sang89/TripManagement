import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Signed URL cache: original URL → (signedUrl, expiry). Cleared on hot restart.
final _cache = <String, (String url, DateTime expiry)>{};

// Extracts (bucket, path) from a Supabase public URL, stripping any query params.
// URL format: .../storage/v1/object/public/{bucket}/{path}
(String bucket, String path)? _parseStorageUrl(String url) {
  final match = RegExp(r'/object/public/([^/]+)/([^?]+)').firstMatch(url);
  if (match == null) return null;
  return (match.group(1)!, match.group(2)!);
}

Future<String?> _getSignedUrl(String storedUrl) async {
  final parsed = _parseStorageUrl(storedUrl);
  if (parsed == null) return storedUrl; // not a storage URL — use as-is

  final (bucket, path) = parsed;
  // Use full URL (including any ?v= suffix) as cache key so version increments
  // force a fresh signed URL fetch.
  final cacheKey = storedUrl;

  final cached = _cache[cacheKey];
  if (cached != null && DateTime.now().isBefore(cached.$2)) {
    return cached.$1;
  }

  try {
    const ttlSeconds = 3600;
    final signedUrl = await Supabase.instance.client.storage
        .from(bucket)
        .createSignedUrl(path, ttlSeconds);
    _cache[cacheKey] = (signedUrl, DateTime.now().add(
      const Duration(minutes: 50), // refresh 10 min before expiry
    ));
    return signedUrl;
  } catch (_) {
    return null;
  }
}

/// Drop-in replacement for [Image.network] that works with private Supabase
/// storage buckets by generating a signed URL before displaying.
class SupabaseImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  const SupabaseImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  State<SupabaseImage> createState() => _SupabaseImageState();
}

class _SupabaseImageState extends State<SupabaseImage> {
  late Future<String?> _future;

  @override
  void initState() {
    super.initState();
    _future = _getSignedUrl(widget.url);
  }

  @override
  void didUpdateWidget(SupabaseImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _future = _getSignedUrl(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        // Signed URL unavailable — delegate to errorBuilder so initials show.
        if (snap.data == null) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(
                context, 'signed_url_unavailable', null);
          }
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: Icon(Icons.broken_image_outlined,
                color: Colors.grey[400], size: 28),
          );
        }
        return Image.network(
          snap.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: widget.errorBuilder,
          loadingBuilder: widget.loadingBuilder,
        );
      },
    );
  }
}

/// A [CircleAvatar] that securely loads a Supabase storage avatar via signed URL.
///
/// Pass [url] as null/empty to skip the network fetch and show [fallback]
/// immediately. On fetch failure the [fallback] is also shown.
class SupabaseAvatar extends StatefulWidget {
  final String? url;
  final double radius;
  final Color? backgroundColor;
  final Widget fallback;

  const SupabaseAvatar({
    super.key,
    required this.url,
    required this.fallback,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  State<SupabaseAvatar> createState() => _SupabaseAvatarState();
}

class _SupabaseAvatarState extends State<SupabaseAvatar> {
  late Future<String?> _future;

  @override
  void initState() {
    super.initState();
    _future = (widget.url?.isNotEmpty == true)
        ? _getSignedUrl(widget.url!)
        : Future.value(null);
  }

  @override
  void didUpdateWidget(SupabaseAvatar old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _future = (widget.url?.isNotEmpty == true)
          ? _getSignedUrl(widget.url!)
          : Future.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snap) {
        final signedUrl = snap.data;
        final hasImage =
            snap.connectionState == ConnectionState.done && signedUrl != null;

        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.backgroundColor,
          backgroundImage: hasImage ? NetworkImage(signedUrl) : null,
          child: !hasImage ? widget.fallback : null,
        );
      },
    );
  }
}
