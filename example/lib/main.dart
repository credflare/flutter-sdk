import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:credflare_sdk/credflare_sdk.dart';

void main() => runApp(
  MaterialApp(
    title: 'Credflare demo',
    debugShowCheckedModeBanner: false,
    theme: CredflareTheme.data(Brightness.light),
    darkTheme: CredflareTheme.data(Brightness.dark),
    home: const Example(),
  ),
);

class Example extends StatefulWidget {
  final http.Client? httpClient;
  const Example({super.key, this.httpClient});
  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  String _mode = 'either';
  bool _started = false;
  static const modes = {
    'either': [
      'Photos or files',
      'Profile allows a photo or a saved file for each side.',
    ],
    'snapshot_and_upload': [
      'Photos and files',
      'Profile requires a photo and a saved file of each side.',
    ],
    'snapshot': [
      'Camera photos',
      'Profile requires a camera photo of each side.',
    ],
    'upload': ['File uploads', 'Profile requires saved images or PDFs.'],
  };
  Future<SessionDescriptor> _session() async {
    final url = Uri.parse('http://localhost:3107/session');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'email': 'native-demo@example.test',
      'mode': _mode,
    });
    final response =
        await (widget.httpClient?.post(url, headers: headers, body: body) ??
                http.post(url, headers: headers, body: body))
            .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('The local demo backend could not create a session.');
    }
    return SessionDescriptor.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_started) {
      return CredflareVerification(
        sessionProvider: _session,
        httpClient: widget.httpClient,
        autoStart: true,
        onClose: () => setState(() {
          _started = false;
        }),
      );
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const CredflareMark()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CredflareTheme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Try document verification',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose a sample profile. Each profile sets its own capture method, and the SDK follows whatever the case asks for. A fresh sandbox case is created when you start.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              for (final entry in modes.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    selected: _mode == entry.key,
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _mode = entry.key;
                      }),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _mode == entry.key
                            ? theme.colorScheme.primaryContainer
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Icon(
                              _mode == entry.key
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.value[0],
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    entry.value[1],
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => setState(() {
                  _started = true;
                }),
                child: const Text('Start verification'),
              ),
              const SizedBox(height: 16),
              Text(
                'Sandbox demo. Use sample documents.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
