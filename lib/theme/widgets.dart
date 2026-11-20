import 'package:flutter/material.dart';

import 'colors.dart';

/// Bouton pilule des maquettes : rose plein (primary) ou contour gris.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.primary = false,
    this.onPressed,
    this.palette,
  });
  final String label;
  final IconData? icon;
  final bool primary;
  final VoidCallback? onPressed;
  final LafleurPalette?
  palette; // écran toujours noir (Cover Flow) : la palette de nuit

  @override
  Widget build(BuildContext context) {
    final p = palette ?? LafleurColors.p;
    final fg = primary ? LafleurColors.ink : p.text;
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: primary ? LafleurColors.pink : null,
            border: primary ? null : Border.all(color: p.outline),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puce des maquettes (EQ, préréglages) : contour rose quand elle est active.
class LafleurChip extends StatelessWidget {
  const LafleurChip({
    super.key,
    required this.label,
    this.on = false,
    this.onPressed,
  });
  final String label;
  final bool on;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: on ? LafleurColors.pink : LafleurColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: on ? LafleurColors.pink : LafleurColors.text,
        ),
      ),
    ),
  );
}

/// Barre du haut : logo texte LAFLEURMUSIC centré, contenu optionnel à droite (recherche).
class TitleBar extends StatelessWidget {
  const TitleBar({super.key, this.trailing});
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // fenêtre étroite (taille moyenne) : logo plus petit
    final h = MediaQuery.sizeOf(context).width < 880 ? 16.0 : 20.0;
    final logo = Image.asset(
      'assets/logo-texte-grand.png',
      key: const Key('logo'),
      height: h,
      width: h * 20, // le logo fait 900 × 45
      // logo blanc la nuit, noir le jour
      color: LafleurColors.p.brightness == Brightness.light
          ? LafleurColors.text
          : null,
    );
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: LafleurColors.bar,
        border: Border(bottom: BorderSide(color: LafleurColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: CustomMultiChildLayout(
        delegate: _TitleBarLayout(),
        children: [
          LayoutId(
            id: _TitleBarLayout.logo,
            child: FittedBox(fit: BoxFit.scaleDown, child: logo),
          ),
          if (trailing != null)
            LayoutId(id: _TitleBarLayout.trailing, child: trailing!),
        ],
      ),
    );
  }
}

/// Logo au milieu de la fenêtre s'il y a la place ; sinon centré dans la place à gauche
/// de la recherche, et rétréci si même ça ne suffit pas. Jamais sous la recherche.
class _TitleBarLayout extends MultiChildLayoutDelegate {
  static const logo = 'logo', trailing = 'trailing', gap = 12.0;

  @override
  void performLayout(Size size) {
    var right = size.width; // bord droit de la place du logo
    if (hasChild(trailing)) {
      final t = layoutChild(trailing, BoxConstraints.loose(size));
      positionChild(
        trailing,
        Offset(size.width - t.width, (size.height - t.height) / 2),
      );
      right = size.width - t.width - gap;
    }
    final l = layoutChild(
      logo,
      BoxConstraints(
        maxWidth: right.clamp(0, size.width),
        maxHeight: size.height,
      ),
    );
    var x = (size.width - l.width) / 2; // au milieu de la fenêtre
    if (x + l.width > right) {
      x = (right - l.width) / 2; // au milieu de la place libre
    }
    positionChild(
      logo,
      Offset(x.clamp(0, size.width), (size.height - l.height) / 2),
    );
  }

  @override
  bool shouldRelayout(_TitleBarLayout oldDelegate) => false;
}

/// Contour en pointillés arrondi (zone de dépôt de la maquette 1).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    this.radius = 18,
    this.dash = 7,
    this.gap = 5,
    this.width = 2,
  });
  final Color color;
  final double radius, dash, gap, width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color;
}

/// Champ qui prend le clavier dès qu'il apparaît. `autofocus` ne le fait pas quand l'écran a déjà le clavier
/// (raccourcis espace, flèches), et l'espace mettait alors la musique en pause au lieu de s'écrire.
class FocusOnShow extends StatefulWidget {
  const FocusOnShow({super.key, required this.builder});
  final Widget Function(FocusNode node) builder;
  @override
  State<FocusOnShow> createState() => _FocusOnShowState();
}

class _FocusOnShowState extends State<FocusOnShow> {
  final _node = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _node.requestFocus();
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_node);
}

/// Pochette absente : fleur rose sur carré sombre la nuit, sur carré beige le jour (maquette iPhone).
Widget fleurTile(double size) => LafleurColors.p.brightness == Brightness.light
    ? Container(
        width: size,
        height: size,
        color: const Color(0xFFEDE8DE),
        alignment: Alignment.center,
        child: Image.asset('assets/fleur.png', width: size * 0.62),
      )
    : Image.asset(
        'assets/fleur-tile.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      );

/// Bouton rond d'un curseur : blanc, avec un fin contour gris le jour (sinon invisible sur le blanc).
BoxDecoration knobDecoration() {
  final edge = LafleurColors.p.knobEdge;
  return BoxDecoration(
    color: const Color(0xFFFFFFFF),
    shape: BoxShape.circle,
    border: edge == null ? null : Border.all(color: edge),
  );
}
