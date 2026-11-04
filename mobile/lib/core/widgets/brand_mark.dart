import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.favorite, color: AppColors.rose, size: 28),
      const SizedBox(width: 8),
      Text('ourspace', style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
