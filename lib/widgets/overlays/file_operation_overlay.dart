import 'package:flutter/material.dart';

class FileOperationOverlay extends StatelessWidget {
  const FileOperationOverlay({
    super.key,
    required this.isImporting,
    required this.isExporting,
  });

  final bool isImporting;
  final bool isExporting;

  @override
  Widget build(BuildContext context) {
    if (!isImporting && !isExporting) return const SizedBox.shrink();

    final message = isImporting ? 'Importerar...' : 'Exporterar...';

    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
