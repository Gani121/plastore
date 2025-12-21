import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:test1/utilities.dart';
import '/objectbox.g.dart';

class ObjectBoxService {
  static final ObjectBoxService instance = ObjectBoxService._internal();
  ObjectBoxService._internal();

  Store? _store;
  String? store_path;

  Store get store {
    if (_store == null) {
      throw StateError("ObjectBox not initialized. Call init() first.");
    }
    return _store!;
  }
    // Setter is required so BackupManager can update it after re-opening!
  set store(Store newStore) {
    _store = newStore;
    print_log("✅ New ObjectBox initialized: $store_path and store $_store");
    // notifyListeners(); // Notify UI that DB has been reset/restored
  }

  Future<void> init() async {
    if (_store != null) return; // ✅ Prevent reopening
    store_path = AppConstants.objectbox_path;
    print_log("✅ ObjectBox initialized: on path $store_path");
    try {
      _store = Store(getObjectBoxModel(), directory: store_path);
    } on ObjectBoxException catch (e) {
      print_log("Error opening store, likely a schema mismatch. Consider deleting the database file. Error: $e");
      rethrow;
      // If a schema mismatch occurs during development, it's often easiest
      // to just delete the database and let ObjectBox create a new one.
      // if (e.toString().contains('failed to create store')) {
      //   print_log("Schema mismatch detected. Deleting old database and re-initializing.");
      //   Directory(store_path!).deleteSync(recursive: true);
      //   _store = Store(getObjectBoxModel(), directory: store_path);
      // } else {
      // rethrow;
      // }
    }
    print_log("✅ ObjectBox initialized: $store_path and store $_store");
  }



  void dispose() {
    _store?.close();
    _store = null;
  }
}
