import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laya Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Laya Mobile'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const _channel = MethodChannel('com.example/laya_engine');

  String _response = 'No response yet';
  bool _loading = false;

  static const _sample = 'question: hello';
  String _tokenResponse = 'No tokenization yet';
  bool _tokenLoading = false;

  Future<void> _sendPing() async {
    setState(() {
      _loading = true;
      _response = 'Waiting...';
    });
    try {
      final result = await _channel.invokeMethod<String>('ping', 'ping');
      setState(() => _response = result ?? 'null');
    } on PlatformException catch (e) {
      setState(() => _response = 'Error: ${e.message}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _tokenize() async {
    setState(() {
      _tokenLoading = true;
      _tokenResponse = 'Tokenizing $_sample ...';
    });
    try {
      final result =
          await _channel.invokeMethod<List<Object?>>('tokenize', _sample);
      final ids = result?.cast<int>() ?? const <int>[];
      final preview =
          '${ids.take(20).join(', ')}${ids.length > 20 ? ' ...' : ''}';
      setState(() => _tokenResponse = '${ids.length} ids: [$preview]');
    } on PlatformException catch (e) {
      setState(() => _tokenResponse = 'Error: ${e.message}');
    } finally {
      setState(() => _tokenLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('MethodChannel response:'),
            const SizedBox(height: 8),
            Text(
              _response,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _sendPing,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt),
              label: const Text('Send Ping'),
            ),
            const SizedBox(height: 40),
            const Text('Tokenize "$_sample":'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _tokenResponse,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _tokenLoading ? null : _tokenize,
              icon: _tokenLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.text_snippet_outlined),
              label: const Text('Tokenize'),
            ),
          ],
        ),
      ),
    );
  }
}
