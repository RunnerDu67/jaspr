import 'dart:async';
import 'dart:io';

import 'package:jaspr/server.dart' as jp;
import 'package:serverpod/serverpod.dart' as sp;
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../jaspr_serverpod.dart';

/// A [JasprRoute] is the most convenient way to render Jaspr components in your server.
/// Override the [build] method and return a root [Component].
///
/// {@category Setup}
abstract class JasprRoute extends sp.Route {
  JasprRoute() {
    handler = jp.serveApp(_handleRenderCall as jp.AppHandler);
  }

  late jp.Handler handler;

  /// Override this method to build your root [Component] from the current [session] and [request].
  Future<jp.Component> build(sp.Session session, sp.Request request);

  FutureOr<jp.Response> _handleRenderCall(
    sp.Request request,
    FutureOr<jp.Response> Function(jp.Component) render,
  ) async {
    final session = await request.session;
    final component = await build(session, request);
    return render(InheritedSession(session: session, child: component));
  }

  @override
  Future<sp.Result> handleCall(sp.Session session, sp.Request request) async {
    final ioRequest = request.token as HttpRequest;
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
