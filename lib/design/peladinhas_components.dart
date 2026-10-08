import 'package:flutter/material.dart';

import 'peladinhas_tokens.dart';

enum PeladinhasButtonTone { primary, secondary }

class PeladinhasButton extends StatelessWidget {
  const PeladinhasButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = PeladinhasButtonTone.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PeladinhasButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final foreground = tone == PeladinhasButtonTone.primary
        ? PeladinhasColors.onDark
        : PeladinhasColors.brand;
    final background = tone == PeladinhasButtonTone.primary
        ? PeladinhasColors.brandDark
        : PeladinhasColors.surface;
    final border = tone == PeladinhasButtonTone.primary
        ? Colors.transparent
        : PeladinhasColors.border;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PeladinhasRadii.sm),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(PeladinhasRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: PeladinhasSpacing.sm),
              ],
              Text(
                label,
                style: PeladinhasTypography.label.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PeladinhasCard extends StatelessWidget {
  const PeladinhasCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = PeladinhasColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: PeladinhasColors.border),
        borderRadius: BorderRadius.circular(PeladinhasRadii.md),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class PeladinhasStatusLabel extends StatelessWidget {
  const PeladinhasStatusLabel({
    super.key,
    required this.label,
    this.color = PeladinhasColors.success,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: PeladinhasTypography.eyebrow.copyWith(color: color),
    );
  }
}

class PeladinhasInputShell extends StatelessWidget {
  const PeladinhasInputShell({
    super.key,
    required this.child,
    this.active = false,
  });

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? PeladinhasColors.brandSoft : PeladinhasColors.surface,
        border: Border.all(
          color: active ? PeladinhasColors.brand : PeladinhasColors.border,
        ),
        borderRadius: BorderRadius.circular(PeladinhasRadii.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: child,
      ),
    );
  }
}

class PeladinhasTabs extends StatelessWidget {
  const PeladinhasTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PeladinhasColors.surface,
        border: Border(bottom: BorderSide(color: PeladinhasColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < tabs.length; index += 1)
              _TabButton(
                label: tabs[index],
                selected: selectedIndex == index,
                onTap: () => onChanged(index),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 190,
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: PeladinhasTypography.label.copyWith(
                color: selected
                    ? PeladinhasColors.brand
                    : PeladinhasColors.inkSecondary,
              ),
            ),
            const SizedBox(height: 11),
            SizedBox(
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? PeladinhasColors.brand : Colors.transparent,
                ),
                child: const SizedBox(width: 190),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SquareNavIcon extends StatelessWidget {
  const SquareNavIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const SizedBox.square(dimension: 16),
    );
  }
}
