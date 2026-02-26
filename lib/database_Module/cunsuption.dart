import 'package:objectbox/objectbox.dart';
import 'menu_item.dart';

@Entity()
class InventoryItem {
  @Id()
  int id = 0;

  String name; // e.g., "Plate", "Cheese"
  String unit; // e.g., "Grams", "Nos", "Kg"
  double stockQuantity; // Total quantity currently in stock

  InventoryItem({
    required this.name,
    required this.unit,
    this.stockQuantity = 0.0,
  });

  // ---------------------- FROM MAP ----------------------

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      name: map['name'] ?? '',
      unit: map['unit'] ?? '',
      stockQuantity: map['stockQuantity'] != null
          ? double.tryParse(map['stockQuantity'].toString()) ?? 0.0
          : 0.0,
    )..id = map['id'] ?? 0;
  }

  // ---------------------- TO MAP ----------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'stockQuantity': stockQuantity,
    };
  }

  // ---------------------- FROM JSON ----------------------

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      stockQuantity: json['stockQuantity'] != null
          ? double.tryParse(json['stockQuantity'].toString()) ?? 0.0
          : 0.0,
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
    };
  }

  @override
  String toString() {
    return 'InventoryItem(id: $id, name: $name, unit: $unit, stockQuantity: $stockQuantity)';
  }
}

@Entity()
class ItemConsumption {
  @Id()
  int id = 0;

  double quantityUsed; // How much is used for 1 menu item

  // Relations
  final menuItem = ToOne<MenuItem>();
  final inventoryItem = ToOne<InventoryItem>();

  ItemConsumption({required this.quantityUsed});

  // ---------------------- FROM MAP ----------------------

  factory ItemConsumption.fromMap(Map<String, dynamic> map) {
    final item = ItemConsumption(
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
      'quantityUsed': quantityUsed,
      'menuItemId': menuItem.targetId,
      'inventoryItemId': inventoryItem.targetId,
    };
  }

  // ---------------------- FROM JSON ----------------------

  factory ItemConsumption.fromJson(Map<String, dynamic> json) {
    final item = ItemConsumption(
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
      'quantityUsed': quantityUsed,
      'menuItemId': menuItem.targetId,
      'inventoryItemId': inventoryItem.targetId,
    };
  }

  @override
  String toString() {
    return 'ItemConsumption(id: $id, quantityUsed: $quantityUsed, '
        'menuItemId: ${menuItem.targetId}, '
        'inventoryItemId: ${inventoryItem.targetId})';
  }
}