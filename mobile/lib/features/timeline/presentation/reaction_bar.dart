import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/timeline_models.dart';

/// Thanh chọn reaction cho một ảnh. Mỗi người chỉ giữ một reaction cho mỗi
/// ảnh, nên bấm lại đúng reaction đang chọn sẽ gửi `null` để bỏ reaction.
class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.photo,
    required this.currentUserId,
    required this.onSelect,
    this.busy = false,
  });

  final PhotoItem photo;
  final String currentUserId;

  /// `null` nghĩa là bỏ reaction hiện tại.
  final ValueChanged<PhotoReactionType?> onSelect;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final mine = photo.reactionBy(currentUserId);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in PhotoReactionType.values)
          _ReactionChip(
            key: Key('reaction_${photo.id}_${type.wire}'),
            type: type,
            selected: mine == type,
            count: photo.countOf(type),
            onTap: busy ? null : () => onSelect(mine == type ? null : type),
          ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    super.key,
    required this.type,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final PhotoReactionType type;
  final bool selected;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${type.label}${count > 0 ? ' ($count)' : ''}',
    child: Material(
      color: selected ? AppColors.softRose : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? AppColors.rose : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(type.emoji, style: const TextStyle(fontSize: 16)),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.rose : AppColors.ink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
