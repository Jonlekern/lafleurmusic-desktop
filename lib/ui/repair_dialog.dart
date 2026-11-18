import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import '../library/models.dart';
import '../repair/musicbrainz.dart';
import '../repair/proposal.dart';
import '../theme/colors.dart';
import '../theme/widgets.dart';
import 'cover_image.dart';
import 'track_list.dart' show writeEdits;

/// « Réparer » (maquette 5) : cherche l'album sur MusicBrainz, montre avant / après, écrit si on valide.
class RepairDialog extends StatefulWidget {
  const RepairDialog({super.key, required this.tracks});
  final List<Track> tracks;
  @override
  State<RepairDialog> createState() => _RepairDialogState();
}

class _RepairDialogState extends State<RepairDialog> {
  List<ReleaseCandidate>? _candidates;
  int _i = 0;
  Proposal? _proposal;
  String? _message;
  bool _busy = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_candidates == null && _busy) _search();
  }

  MusicBrainz get _mb => AppScope.of(context).musicbrainz!;

  Future<void> _search() async {
    final s = AppScope.of(context).strings;
    final first = widget.tracks.first;
    try {
      final c = await _mb.searchRelease(first.artist, first.album);
      if (!mounted) return;
      if (c.isEmpty) {
        setState(() {
          _message = s.nothingFound;
          _busy = false;
        });
        return;
      }
      _candidates = c;
      await _load();
    } on RepairError catch (e) {
      if (mounted) {
        setState(() {
          _message = e.offline || e.busy ? s.offline : s.nothingFound;
          _busy = false;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    final c = _candidates![_i];
    try {
      final list = await _mb.tracklist(c.id);
      final p = Proposal.build(widget.tracks, c, list);
      try {
        p.cover = await _mb.cover(c.id);
      } on RepairError {
        p.cover = null; // pochette injoignable : on garde les titres
      }
      if (mounted) {
        setState(() {
          _proposal = p;
          _busy = false;
        });
      }
    } on RepairError catch (e) {
      if (mounted) {
        setState(() {
          _message = e.offline || e.busy
              ? AppScope.of(context).strings.offline
              : AppScope.of(context).strings.nothingFound;
          _busy = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final p = _proposal;
    if (p == null) return;
    await writeEdits(context, p.edits());
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    final p = _proposal;
    final albumName = widget.tracks.first.album;
    return Dialog(
      backgroundColor: LafleurColors.p.sheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: LafleurColors.p.sheetLine),
      ),
      child: SizedBox(
        width: 1000,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 30, 36, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_fix_high_rounded,
                    size: 26,
                    color: LafleurColors.text,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.repairTitle(albumName),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.repairSource,
                style: TextStyle(color: LafleurColors.sub, fontSize: 14),
              ),
              const SizedBox(height: 24),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      s.searching,
                      style: TextStyle(color: LafleurColors.sub),
                    ),
                  ),
                )
              else if (_message != null)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      _message!,
                      style: const TextStyle(
                        color: LafleurColors.pink,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else if (p != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _card(s.before, false, p, s)),
                        const SizedBox(
                          width: 60,
                          child: Padding(
                            padding: EdgeInsets.only(top: 150),
                            child: Center(
                              child: Text(
                                '→',
                                style: TextStyle(
                                  fontSize: 30,
                                  color: LafleurColors.pink,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: _card(s.after, true, p, s)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PillButton(
                    label: s.cancel,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 14),
                  PillButton(
                    label: s.otherResult,
                    onPressed: _busy || (_candidates?.length ?? 0) < 2
                        ? null
                        : () {
                            _i = (_i + 1) % _candidates!.length;
                            _load();
                          },
                  ),
                  const SizedBox(width: 14),
                  PillButton(
                    label: s.saveIn(widget.tracks.length),
                    primary: true,
                    onPressed: _busy || p == null ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String label, bool after, Proposal p, Strings s) {
    Widget field(String name, String before, String afterV) {
      final changed = after && before != afterV;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: LafleurColors.p.rowLine)),
        ),
        child: Row(
          children: [
            Text(
              name,
              style: TextStyle(color: LafleurColors.sub, fontSize: 14),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                after ? afterV : (before.isEmpty ? '—' : before),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: changed ? LafleurColors.pink : LafleurColors.text,
                  fontWeight: changed ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final cover = after && p.cover != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              p.cover!,
              width: 180,
              height: 180,
              fit: BoxFit.cover,
            ),
          )
        : !after && widget.tracks.first.hasCover
        ? CoverImage(trackPath: widget.tracks.first.path, size: 180, radius: 6)
        : Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: LafleurColors.p.rowLine,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              s.noCover,
              style: TextStyle(color: LafleurColors.p.faintest, fontSize: 13),
            ),
          );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LafleurColors.p.well,
        border: Border.all(
          color: after ? LafleurColors.pink : LafleurColors.line,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: after ? LafleurColors.pink : LafleurColors.sub,
              fontSize: 12,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          cover,
          const SizedBox(height: 14),
          field(s.artistLabel, p.artist.before, p.artist.after),
          field(s.albumLabel, p.album.before, p.album.after),
          for (final r in p.rows)
            field(
              s.trackLabel(
                after
                    ? (r.trackNo ?? r.track.trackNo ?? 0)
                    : (r.track.trackNo ?? 0),
              ),
              r.track.title,
              r.after,
            ),
        ],
      ),
    );
  }
}

Future<void> openRepair(BuildContext context, List<Track> tracks) async {
  if (tracks.isEmpty || AppScope.of(context).musicbrainz == null) return;
  await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (_) => RepairDialog(tracks: tracks),
  );
}
