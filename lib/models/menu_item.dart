import 'package:objectbox/objectbox.dart';


//flutter pub run build_runner watch
//flutter pub run build_runner build
@Entity()
class MenuItem {
  @Id()
  int id = 0;

  String name; //
  String sellPrice;
  String sellPriceType; //efault to rs
  String category; //
  String? mrp;
  String? purchasePrice;
  String? acSellPrice; //
  String? acSellPriceHalf; //
  String? nonAcSellPrice; //
  String? nonAcSellPriceHalf; //
  String? onlineDeliveryPrice; //
  String? onlineDeliveryPriceHalf; //
  String? onlineSellPrice; //
  String? onlineSellPriceHalf; //
  String? hsnCode;
  String? itemCode; //
  String? barCode;
  String? barCode2;
  String? imagePath;
  int? available; //
  int? adjustStock;
  double? gstRate;
  bool? withTax;
  double? cessRate;
  bool favorites;
  bool selected;
  int qty;
  int h_qty;
  String? h_price;
  String? f_price;
  String? H_portion;
  String? F_portion;
  int? selectedprice;
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';
  String? reserved_field4 = '';
  String? reserved_field5 = '';

  MenuItem({
    this.id = 0,
    required this.name,
    required this.sellPrice,
    required this.sellPriceType,
    required this.category,
    this.mrp,
    this.purchasePrice,
    this.acSellPrice,
    this.acSellPriceHalf,
    this.nonAcSellPrice,
    this.nonAcSellPriceHalf,
    this.onlineDeliveryPrice,
    this.onlineDeliveryPriceHalf,
    this.onlineSellPrice,
    this.onlineSellPriceHalf,
    this.hsnCode,
    this.itemCode,
    this.barCode,
    this.barCode2,
    this.imagePath,
    this.available,
    this.adjustStock,
    this.gstRate,
    this.withTax,
    this.cessRate,
    this.selected = false,
    this.qty = 0,
    this.h_qty = 0,
    this.f_price,
    this.h_price,
    this.H_portion,
    this.F_portion,
    this.selectedprice,
    this.favorites = false,
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reserved_field4,
    this.reserved_field5,
  });

  // CopyWith method for immutable updates
  MenuItem copyWith({
    int? id,
    String? name,
    String? sellPrice,
    String? sellPriceType,
    String? category,
    String? mrp,
    String? purchasePrice,
    String? acSellPrice,
    String? acSellPriceHalf,
    String? nonAcSellPrice,
    String? nonAcSellPriceHalf,
    String? onlineDeliveryPrice,
    String? onlineDeliveryPriceHalf,
    String? onlineSellPrice,
    String? onlineSellPriceHalf,
    String? hsnCode,
    String? itemCode,
    String? barCode,
    String? barCode2,
    String? imagePath,
    int? available,
    int? adjustStock,
    double? gstRate,
    bool? withTax,
    double? cessRate,
    bool? selected,
    int? qty,
    int? h_qty,
    String? f_price,
    String? h_price,
    bool? favorites,
    String? H_portion,
    String? F_portion,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      sellPrice: sellPrice ?? this.sellPrice,
      sellPriceType: sellPriceType ?? this.sellPriceType,
      category: category ?? this.category,
      mrp: mrp ?? this.mrp,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      acSellPrice: acSellPrice ?? this.acSellPrice,
      acSellPriceHalf : acSellPriceHalf ?? this.acSellPriceHalf,
      nonAcSellPrice: nonAcSellPrice ?? this.nonAcSellPrice,
      nonAcSellPriceHalf:nonAcSellPriceHalf ?? this.nonAcSellPriceHalf,
      onlineDeliveryPrice: onlineDeliveryPrice ?? this.onlineDeliveryPrice,
      onlineDeliveryPriceHalf:onlineDeliveryPriceHalf ?? this.onlineDeliveryPriceHalf,
      onlineSellPrice: onlineSellPrice ?? this.onlineSellPrice,
      onlineSellPriceHalf:onlineSellPriceHalf ?? this.onlineSellPriceHalf,
      hsnCode: hsnCode ?? this.hsnCode,
      itemCode: itemCode ?? this.itemCode,
      barCode: barCode ?? this.barCode,
      barCode2: barCode2 ?? this.barCode2,
      imagePath: imagePath ?? this.imagePath,
      available: available ?? this.available,
      adjustStock: adjustStock ?? this.adjustStock,
      gstRate: gstRate ?? this.gstRate,
      withTax: withTax ?? this.withTax,
      cessRate: cessRate ?? this.cessRate,
      selected: selected ?? this.selected,
      qty: qty ?? this.qty,
      f_price: f_price ?? this.f_price,
      h_price: h_price ?? this.h_price,
      favorites: favorites?? this.favorites,
      H_portion: H_portion ?? this.H_portion,
      F_portion: F_portion ?? this.F_portion,
      h_qty: h_qty ?? this.h_qty,
    );
  }

  // Factory constructor from Map
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'] ?? 0,
      name: map['name'] ?? '',
      sellPrice: map['sellPrice'] ?? '0',
      sellPriceType: map['sellPriceType'] ?? '',
      category: map['category'] ?? '',
      mrp: map['mrp'],
      purchasePrice: map['purchasePrice'],
      acSellPrice: map['acSellPrice'],
      nonAcSellPrice: map['nonAcSellPrice'],
      onlineDeliveryPrice: map['onlineDeliveryPrice'],
      onlineSellPrice: map['onlineSellPrice'],
      acSellPriceHalf: map['acSellPrice'],
      nonAcSellPriceHalf: map['nonAcSellPrice'],
      onlineDeliveryPriceHalf: map['onlineDeliveryPrice'],
      onlineSellPriceHalf: map['onlineSellPrice'],
      hsnCode: map['hsnCode'],
      itemCode: map['itemCode'],
      barCode: map['barCode'],
      barCode2: map['barCode2'],
      imagePath: map['imagePath'],
      available: map['available'],
      adjustStock: map['adjustStock'],
      gstRate: map['gstRate']?.toDouble(),
      withTax: map['withTax'],
      cessRate: map['cessRate']?.toDouble(),
      selected: map['selected'] ?? false,
      qty: map['qty'] ?? 0,
      f_price: map['f_price'] ?? 0,
      h_price: map['h_price'] ?? 0,
      favorites: map['favorites'] ?? false,
      H_portion: map['H_portion'],
      F_portion: map['F_portion'],
      h_qty: map['h_qty'] ?? 0,
    );
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sellPrice': sellPrice,
      'sellPriceType': sellPriceType,
      'category': category,
      'mrp': mrp,
      'purchasePrice': purchasePrice,
      'acSellPrice': acSellPrice,
      'nonAcSellPrice': nonAcSellPrice,
      'onlineDeliveryPrice': onlineDeliveryPrice,
      'onlineSellPrice': onlineSellPrice,
      'acSellPriceHalf': acSellPriceHalf,
      'nonAcSellPriceHalf': nonAcSellPriceHalf,
      'onlineDeliveryPriceHalf': onlineDeliveryPriceHalf,
      'onlineSellPriceHalf': onlineSellPriceHalf,
      'hsnCode': hsnCode,
      'itemCode': itemCode,
      'barCode': barCode,
      'barCode2': barCode2,
      'imagePath': imagePath,
      'available': available,
      'adjustStock': adjustStock,
      'gstRate': gstRate,
      'withTax': withTax,
      'cessRate': cessRate,
      'selected': selected,
      'qty': qty,
      'h_qty': h_qty,
      'f_price': f_price,
      'h_price': h_price,
      'favorites':favorites,
      'H_portion': H_portion,
      'F_portion': F_portion,
    };
  }

  @override
  String toString() {
    return 'MenuItem(id: $id, name: $name, '
        'sellPrice: $sellPrice, '
        'h_price: $h_price, '
        'f_price: $f_price, '
        'selected: $selected, qty: $qty, h_qty:$h_qty, favorites: $favorites, onlineSellPriceHalf $onlineSellPriceHalf onlineDeliveryPriceHalf $onlineDeliveryPriceHalf nonAcSellPriceHalf $nonAcSellPriceHalf acSellPriceHalf $acSellPriceHalf )';
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      name: (json['submenu']?.toString() ?? ''),
      sellPrice:
          json['full_price']?.toString() ??
          '0.00', // Using ac_price as default sellPrice
      sellPriceType: 'rs',
      category: json['menu']?.toString() ?? '',
      mrp: json['full_price']?.toString() ?? json['ac_price']?.toString(),
      purchasePrice: null, // Not in response
      acSellPrice: json['ac_price']?.toString(),
      nonAcSellPrice: json['nonac_price']?.toString(),
      onlineDeliveryPrice: json['parcel_price']?.toString(),
      onlineSellPrice: json['online_price']?.toString(),
      acSellPriceHalf: json['ac_price_half']?.toString(),
      nonAcSellPriceHalf: json['nonac_price_half']?.toString(),
      onlineDeliveryPriceHalf: json['parcel_price_half']?.toString(),
      onlineSellPriceHalf: json['online_price_half']?.toString(),
      hsnCode: null, // Not in response
      itemCode: json['id']?.toString(),
      barCode: null, // Not in response
      barCode2: null, // Not in response
      imagePath: null, // Not in response
      available: json['available'] != null
          ? (json['available'] is int
                ? json['available']
                : int.tryParse(json['available'].toString()))
          : null,
      adjustStock: null, // Not in response
      gstRate: null, // Not in response
      withTax: null, // Not in response
      cessRate: null, // Not in response
      f_price: json['f_price'],
      h_price: json['h_price'],
      favorites: false,
      H_portion: json['H_portion']?.toString(),
      F_portion: json['F_portion']?.toString(),
      
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sellPrice': sellPrice,
      'sellPriceType': sellPriceType,
      'category': category,
      'mrp': mrp,
      'purchasePrice': purchasePrice,
      'acSellPrice': acSellPrice,
      'nonAcSellPrice': nonAcSellPrice,
      'onlineDeliveryPrice': onlineDeliveryPrice,
      'onlineSellPrice': onlineSellPrice,
      'acSellPriceHalf': onlineSellPriceHalf,
      'nonAcSellPriceHalf': onlineDeliveryPriceHalf,
      'onlineDeliveryPriceHalf': onlineDeliveryPriceHalf,
      'onlineSellPriceHalf': onlineSellPriceHalf,
      'hsnCode': hsnCode,
      'itemCode': itemCode,
      'barCode': barCode,
      'barCode2': barCode2,
      'imagePath': imagePath,
      'available': available,
      'adjustStock': adjustStock,
      'gstRate': gstRate,
      'withTax': withTax,
      'cessRate': cessRate,
      'f_price': f_price,
      'h_price': h_price,
      'favorites':favorites,
      'H_portion': H_portion,
      'F_portion': F_portion,
    };
  }

  // Optional: Equality comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
