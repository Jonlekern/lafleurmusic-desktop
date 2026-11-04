import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

/// Avant que l'appli quitte (Cmd + Q, dernière fenêtre fermée) : on arrête ce qui tourne et on ferme la base.
/// Sans ça, la base était fermée par son isolate de fond pendant l'arrêt de Dart, et sqlite plantait
/// (sqlite3Close, rapports du 17.10.2026). Chaque étape a [timeout] ; une erreur ou un retard n'empêche pas de quitter.
Future<AppExitResponse> closeBeforeExit(
  List<Future<void> Function()> steps, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  for (final step in steps) {
    try {
      await step().timeout(timeout);
    } catch (_) {
      // on quitte quand même
    }
  }
  stderr.writeln('LAFLEURMUSIC: closed before quit');
  return AppExitResponse.exit;
}
