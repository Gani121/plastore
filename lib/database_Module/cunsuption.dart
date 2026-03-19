import 'package:objectbox/objectbox.dart';
import 'menu_item.dart';

@Entity()
class InventoryItem {
  @Id()
  int id = 0;
  int syid;
  bool synced;
  String name; // e.g., "Plate", "Cheese"
  String unit; // e.g., "Grams", "Nos", "Kg"
  double stockQuantity; // Total quantity currently in stock
  String? category; // Add this field for Materials/Premade

  // Reserved fields for future use (keeping your existing pattern)
  String? reserved_field;
  String? reserved_field1;
  String? reserved_field2;
  String? reserved_field3;

  InventoryItem({
    required this.name,
    required this.unit,
    required this.syid,
    this.synced = false,
    this.stockQuantity = 0.0,
    this.category, // Initialize category
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
  });

  // ---------------------- FROM MAP ----------------------

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      name: map['name'] ?? '',
      unit: map['unit'] ?? '',
      syid: map['syid'] ?? 1,
      synced: map['synced'] ?? false,
      stockQuantity: map['stockQuantity'] != null
          ? double.tryParse(map['stockQuantity'].toString()) ?? 0.0
          : 0.0,
      category: map['category']?.toString(), // Add category
    )..id = map['id'] ?? 0;
  }

  // ---------------------- TO MAP ----------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'stockQuantity': stockQuantity,
      'category': category, // Add category
      'syid': syid, // Add category
      'synced': synced, // Add category
    };
  }

  // ---------------------- FROM JSON ----------------------

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      syid: json['syid'] ?? 1,
      synced: json['synced'] ?? false,
      stockQuantity: json['stockQuantity'] != null
          ? double.tryParse(json['stockQuantity'].toString()) ?? 0.0
          : 0.0,
      category: json['category']?.toString(), // Add category
    )..id = json['id'] != null
        ? int.tryParse(json['id'].toString()) ?? 0
        : 0;
  }

  // ---------------------- TO JSON ----------------------

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'stockQuantity': stockQuantity,
      'category': category, // Add category
      'syid': syid, // Add category
      'synced': synced, // Add category
    };
  }

  @override
  String toString() {
    return 'InventoryItem(id: $id, syid $syid synced $synced name: $name, unit: $unit, stockQuantity: $stockQuantity, category: $category )';
  }
}

@Entity()
class ItemConsumption {
  @Id()
  int id = 0;
  int syid;
  bool synced;
  double quantityUsed; // How much is used for 1 menu item

  // Relations
  final menuItem = ToOne<MenuItem>();
  final inventoryItem = ToOne<InventoryItem>();

  ItemConsumption({
    required this.quantityUsed,
    required this.syid,
    this.synced = false,
    });

  // ---------------------- FROM MAP ----------------------

  factory ItemConsumption.fromMap(Map<String, dynamic> map) {
    final item = ItemConsumption(
      syid: map['syid'] ?? 1,
      synced: map['synced'] ?? false,
      quantityUsed: map['quantityUsed'] != null
          ? double.tryParse(map['quantityUsed'].toString()) ?? 0.0
          : 0.0,
    )..id = map['id'] ?? 0;

    return item;
  }

  // ---------------------- TO MAP ----------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'syid': syid, // Add category
      'synced': synced, // Add category
      'quantityUsed': quantityUsed,
      'menuItemId': menuItem.targetId,
      'inventoryItemId': inventoryItem.targetId,
    };
  }

  // ---------------------- FROM JSON ----------------------

  factory ItemConsumption.fromJson(Map<String, dynamic> json) {
    final item = ItemConsumption(
      syid: json['syid'] ?? 1,
      synced: json['synced'] ?? false,
      quantityUsed: json['quantityUsed'] != null
          ? double.tryParse(json['quantityUsed'].toString()) ?? 0.0
          : 0.0,
    )..id = json['id'] != null
        ? int.tryParse(json['id'].toString()) ?? 0
        : 0;

    return item;
  }

  // ---------------------- TO JSON ----------------------

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'syid': syid, // Add category
      'synced': synced, // Add category
      'quantityUsed': quantityUsed,
      'menuItemId': menuItem.targetId,
      'inventoryItemId': inventoryItem.targetId,
    };
  }

  @override
  String toString() {
    return 'ItemConsumption(id: $id, syid $syid synced $synced quantityUsed: $quantityUsed, '
        'menuItemId: ${menuItem.targetId}, '
        'inventoryItemId: ${inventoryItem.targetId})';
  }
}