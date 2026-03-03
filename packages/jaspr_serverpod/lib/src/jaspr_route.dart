import 'dart:async';
import 'dart:io';

import 'package:jaspr/server.dart';
import 'package:serverpod/serverpod.dart' hide Handler, Response, Request;
import 'package:serverpod/serverpod.dart' as sp show Request, Response, Result;
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../jaspr_serverpod.dart';

/// A [JasprRoute] is the most convenient way to render Jaspr components in your server.
/// Override the [build] method and return a root [Component].
///
/// {@category Setup}
abstract class JasprRoute extends Route {
  JasprRoute() {
    handler = serveApp(_handleRenderCall);
  }

  late Handler handler;

  /// Override this method to build your root [Component] from the current [session] and [request].
  Future<Component> build(Session session, HttpRequest request);

  Future<Response> _handleRenderCall(
    Request request,
    FutureOr<Response> Function(Component) render,
  ) async {
    final session = request.context['session'] as Session;
    final req = request.context['request'] as HttpRequest;
    final component = await build(session, req);
    return render(InheritedSession(session: session, child: component));
  }

  @override
  Future<sp.Result> handleCall(Session session, sp.Request request) async {
    final ioRequest = (request as dynamic).token as HttpRequest;
    await shelf_io.handleRequest(ioRequest, (req) {
      return handler(
        req.change(context: {'session': session, 'request': ioRequest}),
      );
    }, poweredByHeader: null);
    // Needed to flush hijacked requests before returning.
    await Future(() {});
    return sp.Response.ok();
  }
}
