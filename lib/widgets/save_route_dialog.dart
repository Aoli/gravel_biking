import 'package:flutter/material.dart';

class SaveRouteDialog extends StatefulWidget {
  const SaveRouteDialog({
    super.key,
    required this.onSave,
    required this.savedRoutesCount,
    required this.maxSavedRoutes,
    required this.isAuthenticated,
  });

  final Future<void> Function(String name, bool isPublic) onSave;
  final int savedRoutesCount;
  final int maxSavedRoutes;
  final bool isAuthenticated;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String name, bool isPublic) onSave,
    required int savedRoutesCount,
    required int maxSavedRoutes,
    required bool isAuthenticated,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaveRouteDialog(
        onSave: onSave,
        savedRoutesCount: savedRoutesCount,
        maxSavedRoutes: maxSavedRoutes,
        isAuthenticated: isAuthenticated,
      ),
    );
  }

  @override
  State<SaveRouteDialog> createState() => _SaveRouteDialogState();
}

class _SaveRouteDialogState extends State<SaveRouteDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _saving = false;
  bool _isPublic = false;

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

          // Public/Private visibility option (only for authenticated users)
          if (widget.isAuthenticated) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Synlighet',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Privat'),
                          icon: Icon(Icons.lock),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Offentlig'),
                          icon: Icon(Icons.public),
                        ),
                      ],
                      selected: {_isPublic},
                      onSelectionChanged: _saving
                          ? null
                          : (selection) {
                              if (selection.isNotEmpty) {
                                setState(() => _isPublic = selection.first);
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isPublic
                          ? 'Alla användare kan se denna rutt'
                          : 'Bara du kan se denna rutt',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rutten sparas lokalt på din enhet. Logga in för molnsynkronisering och delning.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
      await widget.onSave(name, _isPublic);
      if (mounted && context.mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
