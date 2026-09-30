import 'dart:convert';

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

  String _sequenceResponse = 'No sequence yet';
  bool _sequenceLoading = false;

  Future<void> _buildSequence() async {
    setState(() {
      _sequenceLoading = true;
      _sequenceResponse = 'Building...';
    });
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'buildSequence',
        {
          'question': 'Is the user asking for help?',
          'options': ['yes', 'no'],
          'state': 'user: can you help me reset my password?',
        },
      );
      final ids = (result?['input_ids'] as List?)?.cast<int>() ?? const <int>[];
      final markers =
          (result?['markers'] as List?)?.cast<int>() ?? const <int>[];
      final mask =
          (result?['attention_mask'] as List?)?.cast<double>() ?? const [];
      final realLength = mask.where((m) => m == 1.0).length;
      final atMarkers = markers.map((m) => ids[m]).toList();
      setState(
        () => _sequenceResponse =
            'len=${ids.length} real=$realLength\n'
            'markers=$markers ids@markers=$atMarkers\n'
            'qtype=${result?['qtype_onehot']}\n'
            'ids[0..$realLength]=${ids.take(realLength).toList()}',
      );
    } on PlatformException catch (e) {
      setState(() => _sequenceResponse = 'Error: ${e.message}');
    } finally {
      setState(() => _sequenceLoading = false);
    }
  }

  String _inferenceResponse = 'No inference yet';
  bool _inferenceLoading = false;

  Future<void> _runInference() async {
    setState(() {
      _inferenceLoading = true;
      _inferenceResponse = 'Running...';
    });
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'runInference',
        {
          'question': 'Is the user asking for help?',
          'options': ['yes', 'no'],
          'state': 'user: can you help me reset my password?',
        },
      );
      final logits = (result?['token_logits'] as List?) ?? const [];
      final elapsed = (result?['elapsed_ms'] as num?)?.toStringAsFixed(1);
      setState(
        () => _inferenceResponse =
            '$elapsed ms, token_logits=${logits.length}, '
            'pooled_cls=${result?['pooled_cls_size']}\n'
            'markers=${result?['markers']} '
            'logits@markers=${result?['marker_logits']}',
      );
    } on PlatformException catch (e) {
      setState(() => _inferenceResponse = 'Error: ${e.message}');
    } finally {
      setState(() => _inferenceLoading = false);
    }
  }

  String _askResponse = 'No answer yet';
  bool _askLoading = false;

  Future<void> _ask() async {
    setState(() {
      _askLoading = true;
      _askResponse = 'Asking...';
    });
    try {
      final json = await _channel.invokeMethod<String>('ask', {
        'question': 'What is the status?',
        'options': ['Online', 'Offline'],
        'state': 'The server is down.',
      });
      final answer = jsonDecode(json!) as Map<String, dynamic>;
      final confidence = (answer['confidence'] as num).toStringAsFixed(3);
      setState(
        () => _askResponse =
            'answer=${answer['answer']} confidence=$confidence\n'
            'probabilities=${answer['probabilities']}\n'
            'T=${answer['temperature']} raw=${answer['raw_logits']}',
      );
    } on PlatformException catch (e) {
      setState(() => _askResponse = 'Error: ${e.message}');
    } finally {
      setState(() => _askLoading = false);
    }
  }

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
      final result = await _channel.invokeMethod<List<Object?>>(
        'tokenize',
        _sample,
      );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
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
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _sequenceResponse,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sequenceLoading ? null : _buildSequence,
                icon: _sequenceLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.view_array_outlined),
                label: const Text('Build Sequence'),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _inferenceResponse,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _inferenceLoading ? null : _runInference,
                icon: _inferenceLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.memory),
                label: const Text('Run Inference'),
              ),
              const SizedBox(height: 40),
              const Text('"The server is down." → What is the status?'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _askResponse,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _askLoading ? null : _ask,
                icon: _askLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.question_answer_outlined),
                label: const Text('Ask'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
