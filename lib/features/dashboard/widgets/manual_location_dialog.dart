import 'package:flutter/material.dart';

Future<String?> showManualLocationDialog(
    BuildContext context, {
      String? initialValue,
    }) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ManualLocationDialog(initialValue: initialValue),
  );
}

class _ManualLocationDialog extends StatefulWidget {
  const _ManualLocationDialog({this.initialValue});

  final String? initialValue;

  @override
  State<_ManualLocationDialog> createState() => _ManualLocationDialogState();
}

class _ManualLocationDialogState extends State<_ManualLocationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    final value = _controller.text.trim();
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nhập vị trí'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'VD: Phòng B203, thư viện trường, quán cà phê...',
        ),
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _close,
          child: const Text('HỦY'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('XÁC NHẬN'),
        ),
      ],
    );
  }
}
