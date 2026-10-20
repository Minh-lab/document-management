import 'package:flutter/material.dart';

import '../colors.dart';

class EmptyComponent extends StatelessWidget {
  final String message;

  const EmptyComponent({Key? key, this.message = 'Không có dữ liệu'})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 64, color: AppColors.secondary),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
