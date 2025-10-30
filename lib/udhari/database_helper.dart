// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
// import 'data_models.dart';

// class DatabaseHelper {
//   static final DatabaseHelper _instance = DatabaseHelper._internal();
//   static Database? _database;

//   factory DatabaseHelper() => _instance;

//   DatabaseHelper._internal();

//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDatabase();
//     return _database!;
//   }

//   Future<Database> _initDatabase() async {
//     String path = join(await getDatabasesPath(), 'udhari.db');
//     return await openDatabase(
//       path,
//       version: 1,
//       onCreate: _onCreate,
//     );
//   }

//   Future<void> _onCreate(Database db, int version) async {
//     // Create customers table
//     await db.execute('''
//       CREATE TABLE customers(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         name TEXT NOT NULL,
//         phone TEXT
//       )
//     ''');

//     // Create transactions table
//     await db.execute('''
//       CREATE TABLE transactions(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         customer_id INTEGER NOT NULL,
//         amount REAL NOT NULL,
//         type TEXT NOT NULL,
//         date TEXT NOT NULL,
//         description TEXT,
//         FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
//       )
//     ''');
//   }

//   // Customer operations
//   Future<int> insertCustomer(Customer customer) async {
//     final db = await database;
//     return await db.insert('customers', {
//       'name': customer.name,
//       'phone': customer.phone,
//     });
//   }

//   Future<List<Customer>> getCustomers() async {
//     final db = await database;
//     final List<Map<String, dynamic>> maps = await db.query('customers');
    
//     List<Customer> customers = [];
//     for (var map in maps) {
//       // Get transactions for this customer
//       List<Transaction_udhari> transactions = await getTransactionsForCustomer(map['id']);
//       customers.add(Customer.fromMap(map, transactions));
//     }
    
//     return customers;
//   }

//   Future<int> updateCustomer(Customer customer) async {
//     final db = await database;
//     return await db.update(
//       'customers',
//       {
//         'name': customer.name,
//         'phone': customer.phone,
//       },
//       where: 'id = ?',
//       whereArgs: [customer.id],
//     );
//   }

//   Future<int> deleteCustomer(int id) async {
//     final db = await database;
//     return await db.delete(
//       'customers',
//       where: 'id = ?',
//       whereArgs: [id],
//     );
//   }

//   // Transaction operations
//   Future<int> insertTransaction(int customerId, Transaction_udhari transaction) async {
//     final db = await database;
//     return await db.insert('transactions', {
//       'customer_id': customerId,
//       'amount': transaction.amount,
//       'type': transaction.type == TransactionType.gave ? 'gave' : 'got',
//       'date': transaction.date.toIso8601String(),
//       'description': transaction.description,
//     });
//   }

//   Future<List<Transaction_udhari>> getTransactionsForCustomer(int customerId) async {
//     final db = await database;
//     final List<Map<String, dynamic>> maps = await db.query(
//       'transactions',
//       where: 'customer_id = ?',
//       whereArgs: [customerId],
//       orderBy: 'date DESC',
//     );

//     return List.generate(maps.length, (i) {
//       return Transaction_udhari(
//         amount: maps[i]['amount'],
//         type: maps[i]['type'] == 'gave' ? TransactionType.gave : TransactionType.got,
//         date: DateTime.parse(maps[i]['date']),
//         description: maps[i]['description'] ?? '',
//       );
//     });
//   }

//   Future<int> deleteTransaction(int id) async {
//     final db = await database;
//     return await db.delete(
//       'transactions',
//       where: 'id = ?',
//       whereArgs: [id],
//     );
//   }
// }