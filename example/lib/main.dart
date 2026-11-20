import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:credflare_sdk/credflare_sdk.dart';

void main() => runApp(
  MaterialApp(
    title: 'Verification demo',
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
  bool _started = false;
  Future<SessionDescriptor> _session() async {
    final url = Uri.parse('http://localhost:3107/session');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'email': 'native-demo@example.test'});
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
        onClose: () => setState(() => _started = false),
      );
    }
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CredflareTheme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verify your identity',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Follow the steps requested by your verifier. Review your documents and selfie before sending.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => setState(() => _started = true),
                child: const Text('Start verification'),
              ),
              const SizedBox(height: 16),
              const Text('Sandbox demo. The server sets the requirements.'),
              const CredflareSecuredBy(),
            ],
          ),
        ),
      ),
    );
  }
}
