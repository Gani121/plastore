import 'package:path_provider/path_provider.dart';
import '../objectbox.g.dart';
import '../utilities.dart';

// class ObjectBoxService {
//   static final ObjectBoxService _singleton = ObjectBoxService._internal();
//   static ObjectBoxService get instance => _singleton;

//   late final Store _store;
//   late final Box<udhariCustomer> _customerBox;

//   ObjectBoxService._internal();

//   Future<void> init() async {
//     _store = await openStore();
//     _customerBox = _store.box<udhariCustomer>();
//   }

//   void addCustomer(udhariCustomer udhariCustomer) {
//     _customerBox.put(udhariCustomer);
//   }

//   List<udhariCustomer> getAllCustomers() {
//     return _customerBox.getAll();
//   }
// }


class ObjectBoxService {
  static final ObjectBoxService instance = ObjectBoxService._internal();
  ObjectBoxService._internal();

  Store? _store;

  Store get store {
    if (_store == null) {
      throw StateError("ObjectBox not initialized. Call init() first.");
    }
    return _store!;
  }

  Future<void> init() async {
    if (_store != null) return; // ✅ Prevent reopening
    final store_path = AppConstants.objectbox_path;
    _store = Store(getObjectBoxModel(), directory: store_path);
  }

  void dispose() {
    _store?.close();
    _store = null;
  }
}
