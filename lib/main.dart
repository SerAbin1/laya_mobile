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

  final _stateController = TextEditingController(text: 'The server is down.');
  final _questionController = TextEditingController(
    text: 'What is the status?',
  );
  final _optionsController = TextEditingController(text: 'Online\nOffline');

  Map<String, dynamic>? _answer;
  int? _askElapsedMs;
  String? _askError;
  bool _askLoading = false;

  String _debugResponse = '';
  bool _debugLoading = false;

  @override
  void dispose() {
    _stateController.dispose();
    _questionController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  /// One option per non-empty line, trimmed; order sets marker order.
  List<String> get _options => _optionsController.text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  /// Returns channel arguments, or null after showing why the form is invalid.
  Map<String, Object>? _formArgs() {
    final state = _stateController.text.trim();
    final question = _questionController.text.trim();
    final options = _options;
    String? problem;
    if (state.isEmpty) {
      problem = 'Enter the state text.';
    } else if (question.isEmpty) {
      problem = 'Enter a question.';
    } else if (options.length < 2) {
      problem = 'Enter at least two options, one per line.';
    } else if (options.toSet().length != options.length) {
      problem = 'Options must be unique.';
    }
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return null;
    }
    return {'state': state, 'question': question, 'options': options};
  }

  Future<void> _ask() async {
    final args = _formArgs();
    if (args == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _askLoading = true;
      _askError = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final json = await _channel.invokeMethod<String>('ask', args);
      setState(() {
        _answer = jsonDecode(json!) as Map<String, dynamic>;
        _askElapsedMs = stopwatch.elapsedMilliseconds;
      });
    } on PlatformException catch (e) {
      setState(() {
        _answer = null;
        _askError = e.message;
      });
    } finally {
      setState(() => _askLoading = false);
    }
  }

  Future<void> _runDebug(String label, Future<String> Function() action) async {
    setState(() {
      _debugLoading = true;
      _debugResponse = '$label...';
    });
    try {
      final text = await action();
      setState(() => _debugResponse = text);
    } on PlatformException catch (e) {
      setState(() => _debugResponse = '$label error: ${e.message}');
    } finally {
      setState(() => _debugLoading = false);
    }
  }

  Future<void> _sendPing() => _runDebug('Ping', () async {
    return await _channel.invokeMethod<String>('ping', 'ping') ?? 'null';
  });

  Future<void> _tokenize() => _runDebug('Tokenize', () async {
    final result = await _channel.invokeMethod<List<Object?>>(
      'tokenize',
      _questionController.text,
    );
    final ids = result?.cast<int>() ?? const <int>[];
    return 'question → ${ids.length} ids: $ids';
  });

  Future<void> _buildSequence() async {
    final args = _formArgs();
    if (args == null) return;
    await _runDebug('Build sequence', () async {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'buildSequence',
        args,
      );
      final ids = (result?['input_ids'] as List).cast<int>();
      final markers = (result?['markers'] as List).cast<int>();
      final mask = (result?['attention_mask'] as List).cast<double>();
      final realLength = mask.where((m) => m == 1.0).length;
      return 'real=$realLength/${ids.length} '
          'markers=$markers ids@markers=${markers.map((m) => ids[m]).toList()}\n'
          'qtype=${result?['qtype_onehot']}\n'
          'ids=${ids.take(realLength).toList()}';
    });
  }

  Future<void> _runInference() async {
    final args = _formArgs();
    if (args == null) return;
    await _runDebug('Run inference', () async {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'runInference',
        args,
      );
      final elapsed = (result?['elapsed_ms'] as num).toStringAsFixed(1);
      return '$elapsed ms, token_logits=${(result?['token_logits'] as List).length}, '
          'pooled_cls=${result?['pooled_cls_size']}\n'
          'markers=${result?['markers']} '
          'logits@markers=${result?['marker_logits']}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _stateController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'State',
                hintText: 'The document or message to judge',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _optionsController,
              minLines: 2,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Options',
                helperText: 'One option per line',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
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
              label: Text(_askLoading ? 'Thinking...' : 'Ask'),
            ),
            const SizedBox(height: 16),
            if (_askError != null)
              Text(
                'Error: $_askError',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (_answer != null) _AnswerCard(_answer!, _askElapsedMs),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Debug'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _debugLoading ? null : _sendPing,
                      child: const Text('Ping'),
                    ),
                    OutlinedButton(
                      onPressed: _debugLoading ? null : _tokenize,
                      child: const Text('Tokenize question'),
                    ),
                    OutlinedButton(
                      onPressed: _debugLoading ? null : _buildSequence,
                      child: const Text('Build sequence'),
                    ),
                    OutlinedButton(
                      onPressed: _debugLoading ? null : _runInference,
                      child: const Text('Run inference'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _debugResponse,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Answer plus one probability bar per option, in the order sent.
class _AnswerCard extends StatelessWidget {
  const _AnswerCard(this.answer, this.elapsedMs);

  final Map<String, dynamic> answer;
  final int? elapsedMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final probabilities = (answer['probabilities'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );
    final best = answer['answer'] as String;
    final confidence = (answer['confidence'] as num).toDouble();
    final temperature = (answer['temperature'] as num).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(best, style: theme.textTheme.headlineSmall),
            Text(
              '${(confidence * 100).toStringAsFixed(1)}% confidence',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final entry in probabilities.entries) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(entry.key, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${(entry.value * 100).toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: entry.value,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: entry.key == best
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'T=${temperature.toStringAsFixed(4)}  '
              'raw=${(answer['raw_logits'] as List).map((v) => (v as num).toStringAsFixed(3)).toList()}'
              '${elapsedMs == null ? '' : '  ${elapsedMs}ms'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
