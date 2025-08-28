import 'package:flutter/material.dart';

class SaveRouteDialog extends StatefulWidget {
  const SaveRouteDialog({
    super.key,
    required this.onSave,
    required this.savedRoutesCount,
    required this.maxSavedRoutes,
  });

  final Future<void> Function(String name) onSave;
  final int savedRoutesCount;
  final int maxSavedRoutes;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String name) onSave,
    required int savedRoutesCount,
    required int maxSavedRoutes,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaveRouteDialog(
        onSave: onSave,
        savedRoutesCount: savedRoutesCount,
        maxSavedRoutes: maxSavedRoutes,
      ),
    );
  }

  @override
  State<SaveRouteDialog> createState() => _SaveRouteDialogState();
}

class _SaveRouteDialogState extends State<SaveRouteDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Spara rutt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.savedRoutesCount >= widget.maxSavedRoutes)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Maxantal rutter nått (50). Den äldsta rutten kommer att tas bort.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Ruttnamn',
              border: OutlineInputBorder(),
            ),
            maxLength: 50,
            autofocus: true,
            enabled: !_saving,
            onSubmitted: (value) async => _submit(),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Sparar rutt...'),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Spara'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(name);
      if (mounted && context.mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
