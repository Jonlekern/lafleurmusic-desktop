import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scope.dart';
import '../artists/artist_store.dart';
import '../theme/colors.dart';
import 'artist_avatar.dart';

/// Petit résumé de l'artiste (maquette 6b), sous « En cours » : tiré de Wikipédia, source citée.
class ArtistSummary extends StatefulWidget {
  const ArtistSummary({super.key, required this.name});
  final String name;
  @override
  State<ArtistSummary> createState() => _ArtistSummaryState();
}

class _ArtistSummaryState extends State<ArtistSummary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    final store = app.artists;
    if (store == null) return const SizedBox.shrink();
    return FutureBuilder<ArtistEntry>(
      key: ValueKey(widget.name),
      future: store.get(widget.name),
      builder: (_, snap) {
        final info = snap.data?.info;
        final text = info?.summary;
        if (info == null || text == null || text.isEmpty) {
          return const SizedBox.shrink();
        }
        final line = [
          if (info.kind != null) s.artistKind(info.kind!),
          if (info.place != null) info.place!,
          if (info.since != null) s.since(info.since!),
        ].join(' · ');
        return Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.only(top: 22),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: LafleurColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.theArtist,
                style: const TextStyle(
                  color: LafleurColors.sub,
                  fontSize: 11,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ArtistAvatar(name: widget.name, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (line.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            line,
                            style: const TextStyle(
                              color: LafleurColors.sub,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                text,
                maxLines: _open ? null : 6,
                overflow: _open ? null : TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFFCFCFCF),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => _open = !_open),
                child: Text(
                  _open ? s.showLess : s.readMore,
                  style: const TextStyle(
                    color: LafleurColors.pink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: info.pageUrl == null
                    ? null
                    : () => launchUrl(Uri.parse(info.pageUrl!)),
                child: Text(
                  s.wikiSource,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
