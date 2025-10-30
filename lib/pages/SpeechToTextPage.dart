// import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import '../cartprovier/cart_provider.dart';
// import 'package:provider/provider.dart';

// import '../cartprovier/ObjectBoxService.dart';
// import 'dart:convert'; // For jsonEncode/jsonDecode

// import '../models/menu_item.dart';
// import 'package:string_similarity/string_similarity.dart';

// class SpeechToTextPage extends StatefulWidget {
//   const SpeechToTextPage({super.key});

//   @override
//   State<SpeechToTextPage> createState() => _SpeechToTextPageState();
// }

// class _SpeechToTextPageState extends State<SpeechToTextPage> {
//   late stt.SpeechToText _speech;
//   bool _isListening = false;
//   String _recognizedText = "Hold the mic and speak...";
//   final Map<String, int> _cart = {};
//   double _total = 0.0;
//   late List<MenuItem> _items = [];
//   late Map<String, double> _menu = {}; // Declare at class level
//   late List<String> categories = [];

//   // final Map<String, double> _menu = {
//   //   "biryani": 150.0,
//   //   "coke": 50.0,
//   //   "pizza": 200.0,
//   //   "burger": 120.0,
//   //   "water": 20.0,
//   // };

//   Future<void> _loadItems() async {
//     final store = Provider.of<ObjectBoxService>(context, listen: false).store;
//     final items = store.box<MenuItem>().getAll();

//     setState(() {
//       _items = items
//           .map((item) => item.copyWith(selected: false, qty: 0))
//           .toList();

//       // Debug print loaded items
//       for (var item in _items) {
//         print('Loaded item: ${item.name} - Sell Price: ${item.sellPrice}');
//       }

//       _menu = {
//         for (var item in _items)
//           item.name.toLowerCase().replaceAll(RegExp(r'\s+'), ' '):
//               double.tryParse(item.sellPrice) ?? 0.0,
//       };

//       // categories = _extractCategories(_items);
//     });
//   }

//   final Map<String, int> numberWords = {
//     // English
//     'one': 1,
//     'two': 2,
//     'three': 3,
//     'four': 4,
//     'five': 5,
//     'six': 6,
//     'seven': 7,
//     'eight': 8,
//     'nine': 9,
//     'ten': 10,

//     // Common misrecognitions / phonetics
//     'tu': 2,
//     'to': 2,
//     'too': 2,
//     'do': 2,
//     'doo': 2,
//     'for': 4,
//     'ate': 8,

//     // Hindi
//     'ek': 1,
//     'do': 2,
//     'teen': 3,
//     'char': 4,
//     'paanch': 5,
//     'chhe': 6,
//     'che': 6,
//     'saat': 7,
//     'aath': 8,
//     'nau': 9,
//     'das': 10,

//     // Marathi
//     'ekda': 1,
//     'don': 2,
//     'donon': 2,
//     'down': 2,
//     'dont': 2,
//     'teen': 3,
//     'char': 4,
//     'pach': 5,
//     'saha': 6,
//     'sat': 7,
//     'aath': 8,
//     'nau': 9,
//     'daha': 10,
//     'daa': 10,
//     'da': 10,
//   };

//   final Map<String, String> speechCorrectionMap = {
//     'botal': 'bottle',
//     'botalo': 'bottle',
//     'botol': 'bottle',
//     'pani botal': 'pani bottle',
//     'paneer masal': 'paneer masala',
//     'masal': 'masala',
//     'cock': 'coke',
//     'tu': 'two',
//     'to': 'two',
//     'too': 'two',
//   };

//   String correctSpeech(String speech) {
//     speech = speech.toLowerCase();
//     speechCorrectionMap.forEach((wrong, correct) {
//       speech = speech.replaceAll(wrong, correct);
//     });
//     return speech;
//   }

//   @override
//   void initState() {
//     super.initState();
//     _speech = stt.SpeechToText();
//     _initSpeech();
//     _loadItems();
//   }

//   void _initSpeech() async {
//     bool available = await _speech.initialize(
//       onStatus: (val) => print("Status: $val"),
//       onError: (val) => print("Error: $val"),
//     );
//     if (!available) {
//       print("Speech recognition not available");
//     }
//   }

//   void _startListening() async {
//     bool available = await _speech.initialize();

//     if (available) {
//       await _speech.listen(
//         onResult: (val) {
//           if (val.finalResult) {
//             final raw = val.recognizedWords.toLowerCase();
//             final corrected = correctSpeech(raw);
//             final replaced = replaceNumberWords(corrected);

//             setState(() {
//               _recognizedText = replaced;
//             });

//             _parseSpeech(replaced); // process only final result
//           }
//         },
//       );
//     }
//   }

//   // Future<void> _startListening() async {
//   //   if (!_isListening) {
//   //     setState(() => _isListening = true);
//   //     await _speech.listen(
//   //       listenMode: stt.ListenMode.dictation,
//   //       onResult: (val) {
//   //         // setState(() => _recognizedText = val.recognizedWords);
//   //         // _parseSpeech(val.recognizedWords.toLowerCase());

//   //         final raw = val.recognizedWords.toLowerCase();
//   //         final corrected = correctSpeech(raw);
//   //         final replaced = replaceNumberWords(corrected);

//   //         setState(() {
//   //           _recognizedText = replaced; // <-- Display the fully cleaned version
//   //         });

//   //         _parseSpeech(replaced);
//   //       },
//   //     );
//   //   }
//   // }

//   Future<void> _stopListening() async {
//     if (_isListening) {
//       setState(() => _isListening = false);
//       await _speech.stop();
//     }
//   }

//   String replaceNumberWords(String text) {
//     final allNumberWords = numberWords.entries.toList()
//       ..sort(
//         (a, b) => b.key.length.compareTo(a.key.length),
//       ); // Match longer words first

//     final words = text.split(RegExp(r'\s+'));
//     final correctedWords = <String>[];

//     for (var word in words) {
//       bool matched = false;

//       for (final entry in allNumberWords) {
//         final key = entry.key.toLowerCase();
//         if (word.toLowerCase().startsWith(key)) {
//           final rest = word.substring(key.length);
//           correctedWords.add(entry.value.toString());

//           if (rest.isNotEmpty) {
//             correctedWords.add(rest);
//           }

//           matched = true;
//           break;
//         }
//       }

//       if (!matched) {
//         correctedWords.add(word);
//       }
//     }

//     return correctedWords.join(' ');
//   }

//   void _parseSpeech(String speech) {
//     _cart.clear();
//     _total = 0.0;

//     print("Raw speech: $speech");

//     // Step 1: Correct common mistakes
//     speech = correctSpeech(speech.toLowerCase());
//     print("Corrected speech: $speech");

//     // Step 2: Replace number words with digits
//     speech = replaceNumberWords(speech);
//     print("Replaced numbers: $speech");

//     // Step 3: Split into words
//     final words = speech.split(RegExp(r'\s+'));
//     int i = 0;

//     while (i < words.length) {
//       int? qty;
//       String? matchedItem;

//       // Try to extract quantity
//       qty = int.tryParse(words[i]);

//       // If found quantity and next word exists
//       if (qty != null && i + 1 < words.length) {
//         String itemPhrase = words[i + 1];

//         // Check next 1–3 words as possible item
//         for (int j = 1; j <= 3; j++) {
//           if (i + j < words.length) {
//             final candidate = words.sublist(i + 1, i + 1 + j).join(' ');
//             String match = getClosestMatch(candidate, _menu.keys.toList());

//             if (_menu.containsKey(match)) {
//               matchedItem = match;
//               i += j; // Move index forward
//               break;
//             }
//           }
//         }

//         if (matchedItem != null) {
//           _cart[matchedItem] = (_cart[matchedItem] ?? 0) + qty;
//         }

//         i++; // Skip qty
//       } else {
//         bool matched = false;

//         for (int j = 0; j <= 2 && i + j < words.length; j++) {
//           final candidate = words.sublist(i, i + j + 1).join(" ");
//           String match = getClosestMatch(candidate, _menu.keys.toList());

//           if (_menu.containsKey(match)) {
//             // Don't match again if this word was already matched with a qty
//             if (_cart.containsKey(match)) break;

//             _cart[match] = (_cart[match] ?? 0) + 1;
//             i += j; // skip matched words
//             matched = true;
//             break;
//           }
//         }

//         if (!matched) i++; // increment index only if not matched
//       }
//     }

//     // Calculate total
//     _total = _cart.entries
//         .map((e) => (_menu[e.key] ?? 0) * e.value)
//         .fold(0.0, (a, b) => a + b);

//     print("Final Cart: $_cart");
//     setState(() {});
//   }

//   String getClosestMatch(String input, List<String> itemNames) {
//     final matches = itemNames.map((name) {
//       final score = name.similarityTo(input);
//       return {'name': name, 'score': score};
//     }).toList();

//     matches.sort(
//       (a, b) => (b['score']! as double).compareTo(a['score']! as double),
//     );
//     return matches.first['name'] as String;
//   }

//   // void _parseSpeech(String speech) {
//   //   _cart.clear();
//   //   _total = 0.0;

//   //   // Debug print
//   //   print("Raw speech: $speech");

//   //   // Normalize misheard words
//   //   speech = speech.replaceAll("cock", "coke");

//   //   final words = speech.split(RegExp(r'\s+'));

//   //   for (int i = 0; i < words.length - 1; i++) {
//   //     final word = words[i];
//   //     final nextWord = words[i + 1];

//   //     int? qty = int.tryParse(word) ?? numberWords[word];
//   //     if (qty != null) {
//   //       // Match next word directly
//   //       if (_menu.containsKey(nextWord)) {
//   //         _cart[nextWord] = (_cart[nextWord] ?? 0) + qty;
//   //       } else {
//   //         // Try next 2–3 words ahead
//   //         for (int j = i + 1; j <= i + 3 && j < words.length; j++) {
//   //           if (_menu.containsKey(words[j])) {
//   //             _cart[words[j]] = (_cart[words[j]] ?? 0) + qty;
//   //             break;
//   //           }
//   //         }
//   //       }
//   //     }
//   //   }

//   //   // Calculate total
//   //   _cart.forEach((item, qty) {
//   //     _total += (_menu[item] ?? 0) * qty;
//   //   });

//   //   setState(() {});
//   // }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Voice Bill Generator")),
//       body: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           children: [
//             Text(_recognizedText, style: const TextStyle(fontSize: 20)),
//             const SizedBox(height: 30),
//             Expanded(
//               child: _cart.isEmpty
//                   ? const Center(child: Text("No items detected"))
//                   : ListView(
//                       children: _cart.entries.map((entry) {
//                         final price = _menu[entry.key]!;
//                         final subtotal = price * entry.value;
//                         return ListTile(
//                           title: Text("${entry.value} x ${entry.key}"),
//                           trailing: Text("₹${subtotal.toStringAsFixed(2)}"),
//                         );
//                       }).toList(),
//                     ),
//             ),
//             const Divider(thickness: 2),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text("Total:", style: TextStyle(fontSize: 18)),
//                 Text(
//                   "₹${_total.toStringAsFixed(2)}",
//                   style: const TextStyle(fontSize: 18),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),
//             GestureDetector(
//               onLongPressStart: (_) => _startListening(),
//               onLongPressEnd: (_) => _stopListening(),
//               child: CircleAvatar(
//                 radius: 35,
//                 backgroundColor: _isListening ? Colors.red : Colors.green,
//                 child: const Icon(Icons.mic, color: Colors.white, size: 32),
//               ),
//             ),
//             const SizedBox(height: 10),
//             const Text("Hold to Speak"),
//           ],
//         ),
//       ),
//     );
//   }
// }
