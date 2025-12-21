class Party {
  final String name;
  final String phoneNumber;
  final String category;
  final String billingAddress;
  final String? gstNumber;
  final String? billingTerm;
  final String? billingType;
  final String? dateOfBirth;
  final bool sendWhatsAppAlerts;
  final bool isTable;

  Party({
    required this.name,
    required this.phoneNumber,
    required this.category,
    required this.billingAddress,
    this.gstNumber,
    this.billingTerm,
    this.billingType,
    this.dateOfBirth,
    this.sendWhatsAppAlerts = false,
    this.isTable = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phoneNumber': phoneNumber,
        'category': category,
        'billingAddress': billingAddress,
        'gstNumber': gstNumber,
        'billingTerm': billingTerm,
        'billingType': billingType,
        'dateOfBirth': dateOfBirth,
        'sendWhatsAppAlerts': sendWhatsAppAlerts,
        'isTable': isTable,
      };

  factory Party.fromJson(Map<String, dynamic> json) => Party(
        name: json['name'],
        phoneNumber: json['phoneNumber'],
        category: json['category'],
        billingAddress: json['billingAddress'],
        gstNumber: json['gstNumber'],
        billingTerm: json['billingTerm'],
        billingType: json['billingType'],
        dateOfBirth: json['dateOfBirth'],
        sendWhatsAppAlerts: json['sendWhatsAppAlerts'],
        isTable: json['isTable'],
      );

  @override
  String toString() {
    return 'Party('
        'name: $name, '
        'phoneNumber: $phoneNumber, '
        'category: $category, '
        'billingAddress: $billingAddress, '
        'gstNumber: $gstNumber, '
        'billingTerm: $billingTerm, '
        'billingType: $billingType, '
        'dateOfBirth: $dateOfBirth, '
        'sendWhatsAppAlerts: $sendWhatsAppAlerts, '
        'isTable: $isTable'
        ')';
  }
}
