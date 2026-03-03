import 'dart:async';
import 'dart:typed_data';

import 'package:jaspr/server.dart' as jp;
import 'package:serverpod/serverpod.dart' as sp;

/// A [JasprRoute] is the most convenient way to render Jaspr components in your server.
/// Override the [build] method and return a root [jp.Component].
///
/// {@category Setup}
abstract class JasprRoute extends sp.Route {
  late final jp.Handler _handler;

  JasprRoute() {
    _handler = jp.serveApp(_handleRenderCall);
  }

  /// Override this method to build your Jaspr component tree.
  FutureOr<jp.Component> build(sp.Session session, sp.Request request);

  Future<jp.Response> _handleRenderCall(
    jp.Request shelfRequest,
    jp.RenderFunction render,
  ) async {
    // Extract Session and Request from context
    final session = shelfRequest.context['session'] as sp.Session;
    final request = shelfRequest.context['request'] as sp.Request;

    final component = await build(session, request);

    return render(component);
  }

  @override
  Future<sp.Result> handleCall(sp.Session session, sp.Request request) async {
    // 1. Map Serverpod/Relic request to Shelf request
    final shelfHeaders = <String, List<String>>{};
    for (final entry in request.headers.entries) {
      shelfHeaders[entry.key] = entry.value.toList();
    }

    sp.Hijack? hijackResult;

    final shelfRequest = jp.Request(
      request.method.value,
      request.url,
      headers: shelfHeaders,
      body: request.body.read(),
      context: {'session': session, 'request': request},
      onHijack: (callback) {
        hijackResult = sp.Hijack(callback);
      },
    );

    // 2. Execute Jaspr/Shelf handler
    try {
      final shelfResponse = await _handler(shelfRequest);

      // 3. Convert Shelf response back to Serverpod/Relic response
      final contentType = shelfResponse.headers['content-type'];
      sp.MimeType? mimeType;
      if (contentType != null) {
        try {
          mimeType = sp.MimeType.parse(contentType.split(';').first.trim());
        } catch (_) {
          // Fallback to default if parsing fails
        }
      }

      return sp.Response(
        shelfResponse.statusCode,
        body: sp.Body.fromDataStream(
          shelfResponse.read().cast<Uint8List>(),
          mimeType: mimeType,
        ),
        headers: sp.Headers.fromMap(shelfResponse.headersAll),
      );
    } catch (e) {
      if (hijackResult != null) {
        return hijackResult!;
      }
      rethrow;
    }
  }
}
