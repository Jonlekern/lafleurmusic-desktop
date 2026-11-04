import '../../player/equalizer.dart';

/// Curseurs Winamp → égaliseur de l'appli : les 10 bandes dans l'ordre (60 Hz… 16 kHz → 31 Hz… 16 kHz),
/// le préampli ajouté à chacune, borné à ±12 dB. [bands] null = les bandes de [base] sans changement.
Equalizer withWinamp(
  Equalizer current, {
  required List<double> base,
  required double preamp,
  List<double>? bands,
}) {
  final src = bands ?? base;
  return current.copyWith(
    gains: [
      for (var i = 0; i < Equalizer.bands.length; i++)
        (src[i] + preamp).clamp(-Equalizer.maxDb, Equalizer.maxDb),
    ],
    preset: 'custom',
  );
}

/// Bandes pendant un glisser du préampli : celles du début du glisser + le déplacement (from → to),
/// bornées à ±12 dB. Ainsi un 2e glisser ne rajoute pas le préampli déjà appliqué.
List<double> preampGains(
  List<double> base, {
  required double from,
  required double to,
}) => [
  for (final g in base)
    (g + to - from).clamp(-Equalizer.maxDb, Equalizer.maxDb),
];
