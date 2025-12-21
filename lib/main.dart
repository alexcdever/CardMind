import 'package:flutter/material.dart';
import 'package:loro_dart/loro_dart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loro Dart Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoroTestPage(),
    );
  }
}

class LoroTestPage extends StatefulWidget {
  const LoroTestPage({super.key});

  @override
  State<LoroTestPage> createState() => _LoroTestPageState();
}

class _LoroTestPageState extends State<LoroTestPage> {
  LoroDoc? _doc;
  LoroText? _text;
  LoroMap? _map;
  LoroList? _list;

  String _log = '';
  String _inputText = '';
  bool _isInitializing = false;
  bool _rustLibInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeLoro();
  }

  Future<void> _initializeLoro() async {
    setState(() {
      _isInitializing = true;
      _log = '';
      _addLog('Initializing LoroDoc...');
    });

    try {
      // Initialize flutter_rust_bridge first (only once)
      if (!_rustLibInitialized) {
        await RustLib.init();
        _rustLibInitialized = true;
        _addLog('RustLib initialized successfully');
      }

      // Initialize LoroDoc
      _doc = await LoroDoc.newInstance();
      await _doc!.setPeerId(peer: BigInt.from(12345));

      _addLog('LoroDoc initialized successfully');
      _addLog('PeerID: ${await _doc!.peerId()}');

      // Initialize containers
      _text = await _doc!.getText(name: 'test-text');
      _map = await _doc!.getMap(name: 'test-map');
      _list = await _doc!.getList(name: 'test-list');

      _addLog('All containers initialized successfully');
    } catch (e) {
      _addLog('Error initializing LoroDoc: $e');
      _doc = null;
      _text = null;
      _map = null;
      _list = null;
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _addLog(String message) {
    // Output to command line terminal
    print(message);

    // Update UI log
    setState(() {
      _log = '$_log\n$message';
    });
  }

  bool _checkDocInitialized() {
    if (_doc == null) {
      _addLog('LoroDoc not initialized, please check the error log above');
      return false;
    }
    return true;
  }

  bool _checkTextInitialized() {
    if (_text == null) {
      _addLog('Text container not initialized');
      return false;
    }
    return true;
  }

  bool _checkMapInitialized() {
    if (_map == null) {
      _addLog('Map container not initialized');
      return false;
    }
    return true;
  }

  bool _checkListInitialized() {
    if (_list == null) {
      _addLog('List container not initialized');
      return false;
    }
    return true;
  }

  Future<void> _testTextCRDT() async {
    if (!_checkDocInitialized() || !_checkTextInitialized()) return;

    try {
      // Test Text CRDT
      await _text!.insert(pos: 0, text: 'Hello, Loro!');
      await _doc!.commit();
      _addLog('Text inserted: ${await _text!.text()}');

      await _text!.delete(pos: 0, len: 7);
      await _doc!.commit();
      _addLog('Text after delete: ${await _text!.text()}');
    } catch (e) {
      _addLog('Error testing Text CRDT: $e');
    }
  }

  Future<void> _testMapCRDT() async {
    if (!_checkDocInitialized() || !_checkMapInitialized()) return;

    try {
      // Test Map CRDT
      await _map!.insertString(key: 'key1', value: 'value1');
      await _map!.insertString(key: 'key2', value: '42');
      await _doc!.commit();
      _addLog(
        'Map - key1: ${await _map!.getJson(key: 'key1')}, key2: ${await _map!.getJson(key: 'key2')}',
      );

      await _map!.delete(key: 'key1');
      await _doc!.commit();
      _addLog(
        'Map after delete - key1: ${await _map!.getJson(key: 'key1')}, key2: ${await _map!.getJson(key: 'key2')}',
      );
    } catch (e) {
      _addLog('Error testing Map CRDT: $e');
    }
  }

  Future<void> _testListCRDT() async {
    if (!_checkDocInitialized() || !_checkListInitialized()) return;

    try {
      // Test List CRDT
      await _list!.insertString(pos: 0, value: 'item1');
      await _list!.insertString(pos: 1, value: 'item2');
      await _list!.insertString(pos: 2, value: 'item3');
      await _doc!.commit();
      _addLog(
        'List after insert - size: ${await _list!.len()}, items: ${await _list!.getJson(index: 0)}, ${await _list!.getJson(index: 1)}, ${await _list!.getJson(index: 2)}',
      );

      await _list!.delete(pos: 1, len: 1);
      await _doc!.commit();
      _addLog(
        'List after delete - size: ${await _list!.len()}, items: ${await _list!.getJson(index: 0)}, ${await _list!.getJson(index: 1)}',
      );
    } catch (e) {
      _addLog('Error testing List CRDT: $e');
    }
  }

  Future<void> _insertText() async {
    if (_inputText.isEmpty) {
      _addLog('Please enter text to test');
      return;
    }

    if (!_checkDocInitialized() || !_checkTextInitialized()) return;

    try {
      // Get current text and insert new text at the end
      final currentLen = await _text!.len();
      await _text!.insert(pos: currentLen, text: ' $_inputText');
      await _doc!.commit();
      _addLog('Text after inserting input: ${await _text!.text()}');
      setState(() {
        _inputText = '';
      });
    } catch (e) {
      _addLog('Error inserting text: $e');
    }
  }

  Future<void> _clearAll() async {
    setState(() {
      _addLog('Clearing all data...');
    });

    try {
      // Reinitialize everything
      await _initializeLoro();
      _addLog('All data cleared - new document created');
    } catch (e) {
      _addLog('Error clearing all: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Loro Dart Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Test Controls
            const Text(
              'Test Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Enter text to insert',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _inputText = value;
                      });
                    },
                    controller: TextEditingController(text: _inputText),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _insertText,
                  child: const Text('Insert'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isInitializing ? null : _testTextCRDT,
                  child: const Text('Test Text CRDT'),
                ),
                ElevatedButton(
                  onPressed: _isInitializing ? null : _testMapCRDT,
                  child: const Text('Test Map CRDT'),
                ),
                ElevatedButton(
                  onPressed: _isInitializing ? null : _testListCRDT,
                  child: const Text('Test List CRDT'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _clearAll,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Clear All'),
            ),

            const SizedBox(height: 24),

            // Results Display
            const Text(
              'Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_log),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
