import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Dialog for adding/editing notes for a cart item
class AddNoteDialog extends StatefulWidget {
  final String productName;
  final String? currentNote;

  const AddNoteDialog({
    super.key,
    required this.productName,
    this.currentNote,
  });

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {
  late final TextEditingController _controller;
  final List<String> _quickNotes = [
    'No Ice',
    'Less Sugar',
    'Extra Ice',
    'Hot',
    'No Spicy',
    'Extra Spicy',
    'No Onion',
    'No Garlic',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addQuickNote(String note) {
    final currentText = _controller.text.trim();
    if (currentText.isEmpty) {
      _controller.text = note;
    } else {
      _controller.text = '$currentText, $note';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              const Text('Add Note'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.productName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Note Input
            TextField(
              controller: _controller,
              maxLines: 3,
              maxLength: 200,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g., "Less sugar, no ice"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Notes
            const Text(
              'Quick Notes:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickNotes.map((note) {
                return InkWell(
                  onTap: () => _addQuickNote(note),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 16,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          note,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.currentNote != null && widget.currentNote!.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove Note'),
          ),
        ElevatedButton(
          onPressed: () {
            final note = _controller.text.trim();
            Navigator.of(context).pop(note.isEmpty ? null : note);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
