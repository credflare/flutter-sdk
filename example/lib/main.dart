import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:credflare_sdk/credflare_sdk.dart';

void main() => runApp(const MaterialApp(home: Example()));

class Example extends StatefulWidget {
  const Example({super.key});
  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  final _input = TextEditingController();
  CredflareSession? _session;
  Map<String, dynamic>? _info;
  String? _message;
  bool _busy = false;

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    CredflareSession? next;
    try {
      next = CredflareSession(
        SessionDescriptor.fromJson(
          jsonDecode(_input.text) as Map<String, dynamic>,
        ),
      );
      final info = await next.get();
      if (!mounted) {
        next.close();
        return;
      }
      _session?.close();
      setState(() {
        _session = next;
        _info = info;
        _input.clear();
      });
    } catch (error) {
      next?.close();
      if (mounted) {
        setState(() {
          _message = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _session?.close();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documents =
        (_info?['profile'] as Map?)?['document_requirements'] as List? ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('CredFlare SDK example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste a short-lived session descriptor from your backend. Never paste a client secret. This example collects one document at a time.',
            ),
            TextField(
              controller: _input,
              maxLines: 4,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Session JSON'),
            ),
            FilledButton(
              onPressed: _busy ? null : _load,
              child: const Text('Load session'),
            ),
            if (_message != null) Text(_message!),
            if (_info != null) Text('Environment: ${_info!['environment']}'),
            if (_session != null && documents.isEmpty)
              const Text(
                'There are no outstanding documents. Use the session client for other requested checks.',
              ),
            if (_session != null && documents.isNotEmpty)
              CredflareDocumentCapture(
                key: ValueKey(
                  '${_info!['session_id']}:${documents.first['document_type']['id']}',
                ),
                session: _session!,
                requirement: Map<String, dynamic>.from(documents.first as Map),
                allowedFileTypes:
                    ((_info!['upload_limits'] as Map)['allowed_file_types']
                            as List)
                        .cast<String>(),
                maxFileSizeBytes:
                    (_info!['upload_limits'] as Map)['max_file_size_bytes']
                        as int,
                onSubmitted: (id) => setState(() {
                  _message =
                      'Document submitted for review. Submission $id. This is not a verification decision.';
                }),
              ),
          ],
        ),
      ),
    );
  }
}
