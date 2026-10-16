import 'package:flutter/material.dart';

/// Widget thương hiệu dùng chung cho app.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'OurSpace',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      );
}
