// lib/quotation/quotation_model.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

enum QuotationStatus {
  draft,
  sent,
  accepted,
  expired,
  rejected,
}

enum PlateType {
  vegetarian,
  nonVegetarian,
  jain,
  vegan,
}

class Quotation {
  int syid;
  bool synced;
  final String id;
  final String quotationNumber;
  final DateTime quotationDate;
  final DateTime? validUntil;

  // RESTAURANT details
  final String? businessAddress;
  
  // Party/Customer details
  final String partyId;
  final String partyName;
  final String? partyMobile;
  final String? partyEmail;
  final String? partyAddress;
  final String? partyGst;
  
  // Event details
  final String? eventName;
  final DateTime? eventDate;
  final String? eventVenue;
  final int? expectedGuests;
  
  // Plate details
  final List<PlateQuotation> plates;
  
  // Banquet Hall details
  final List<BanquetQuotation> banquetItems;
  
  // Additional items
  final List<AdditionalQuotationItem> additionalItems;
  
  // Summary
  final double platesSubtotal;
  final double banquetSubtotal;
  final double additionalSubtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  
  // Charges
  final double? serviceCharge;
  final double? packagingCharge;
  final double? deliveryCharge;
  
  // Status
  final QuotationStatus status;
  
  // Notes
  final String? termsAndConditions;
  final String? cancellationPolicy;
  final String? paymentTerms;
  final String? specialInstructions;
  
  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  
  // PDF
  final String? pdfPath;
  final String? signaturePath;

  Quotation({
    required this.syid,
    this.synced = false,
    required this.id,
    required this.quotationNumber,
    required this.quotationDate,
    this.validUntil,
    required this.partyId,
    required this.partyName,
    this.businessAddress,
    this.partyMobile,
    this.partyEmail,
    this.partyAddress,
    this.partyGst,
    this.eventName,
    this.eventDate,
    this.eventVenue,
    this.expectedGuests,
    required this.plates,
    required this.banquetItems,
    required this.additionalItems,
    required this.platesSubtotal,
    required this.banquetSubtotal,
    required this.additionalSubtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    this.serviceCharge,
    this.packagingCharge,
    this.deliveryCharge,
    required this.status,
    this.termsAndConditions,
    this.cancellationPolicy,
    this.paymentTerms,
    this.specialInstructions,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.pdfPath,
    this.signaturePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'syid': syid,  // ADD THIS
      'synced': synced,  // ADD THIS
      'id': id,
      'businessAddress': businessAddress,
      'quotationNumber': quotationNumber,
      'quotationDate': quotationDate.toIso8601String(),
      'validUntil': validUntil?.toIso8601String(),
      'partyId': partyId,
      'partyName': partyName,
      'partyMobile': partyMobile,
      'partyEmail': partyEmail,
      'partyAddress': partyAddress,
      'partyGst': partyGst,
      'eventName': eventName,
      'eventDate': eventDate?.toIso8601String(),
      'eventVenue': eventVenue,
      'expectedGuests': expectedGuests,
      'plates': plates.map((p) => p.toMap()).toList(),
      'banquetItems': banquetItems.map((b) => b.toMap()).toList(),
      'additionalItems': additionalItems.map((a) => a.toMap()).toList(),
      'platesSubtotal': platesSubtotal,
      'banquetSubtotal': banquetSubtotal,
      'additionalSubtotal': additionalSubtotal,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'serviceCharge': serviceCharge,
      'packagingCharge': packagingCharge,
      'deliveryCharge': deliveryCharge,
      'status': status.index,
      'termsAndConditions': termsAndConditions,
      'cancellationPolicy': cancellationPolicy,
      'paymentTerms': paymentTerms,
      'specialInstructions': specialInstructions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy,
      'pdfPath': pdfPath,
      'signaturePath': signaturePath,
    };
  }

  factory Quotation.fromMap(Map<String, dynamic> map) {
    return Quotation(
      syid: map['syid'] ?? 0,  // Provide default value if null
      synced: map['synced'] ?? false,  // Provide default value if null
      id: map['id'] ?? '',
      quotationNumber: map['quotationNumber'] ?? '',
      quotationDate: map['quotationDate'] != null 
          ? DateTime.parse(map['quotationDate']) 
          : DateTime.now(),
      validUntil: map['validUntil'] != null ? DateTime.parse(map['validUntil']) : null,
      businessAddress: map['businessAddress'],
      partyId: map['partyId'] ?? '',
      partyName: map['partyName'] ?? '',
      partyMobile: map['partyMobile'],
      partyEmail: map['partyEmail'],
      partyAddress: map['partyAddress'],
      partyGst: map['partyGst'],
      eventName: map['eventName'],
      eventDate: map['eventDate'] != null ? DateTime.parse(map['eventDate']) : null,
      eventVenue: map['eventVenue'],
      expectedGuests: map['expectedGuests'],
      plates: (map['plates'] as List?)?.map((p) => PlateQuotation.fromMap(p)).toList() ?? [],
      banquetItems: (map['banquetItems'] as List?)?.map((b) => BanquetQuotation.fromMap(b)).toList() ?? [],
      additionalItems: (map['additionalItems'] as List?)?.map((a) => AdditionalQuotationItem.fromMap(a)).toList() ?? [],
      platesSubtotal: (map['platesSubtotal'] ?? 0).toDouble(),
      banquetSubtotal: (map['banquetSubtotal'] ?? 0).toDouble(),
      additionalSubtotal: (map['additionalSubtotal'] ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      serviceCharge: map['serviceCharge']?.toDouble(),
      packagingCharge: map['packagingCharge']?.toDouble(),
      deliveryCharge: map['deliveryCharge']?.toDouble(),
      status: map['status'] != null 
          ? QuotationStatus.values[map['status']] 
          : QuotationStatus.draft,
      termsAndConditions: map['termsAndConditions'],
      cancellationPolicy: map['cancellationPolicy'],
      paymentTerms: map['paymentTerms'],
      specialInstructions: map['specialInstructions'],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      createdBy: map['createdBy'],
      pdfPath: map['pdfPath'],
      signaturePath: map['signaturePath'],
    );
  }

  // Calculated getters
  double get grandTotal => totalAmount + (serviceCharge ?? 0) + (packagingCharge ?? 0) + (deliveryCharge ?? 0);
  
  String get formattedQuotationDate => DateFormat('dd/MM/yyyy').format(quotationDate);
  String get formattedValidUntil => validUntil != null ? DateFormat('dd/MM/yyyy').format(validUntil!) : 'Not specified';
  String get formattedEventDate => eventDate != null ? DateFormat('dd/MM/yyyy').format(eventDate!) : 'Not specified';
  String get formattedTotal => 'Rs. ${totalAmount.toStringAsFixed(2)}';
  String get formattedGrandTotal => 'Rs.  ${grandTotal.toStringAsFixed(2)}';
  
  int get totalItems => plates.length + banquetItems.length + additionalItems.length;
  
  Color get statusColor {
    switch (status) {
      case QuotationStatus.draft: return Colors.grey;
      case QuotationStatus.sent: return Colors.blue;
      case QuotationStatus.accepted: return Colors.green;
      case QuotationStatus.expired: return Colors.orange;
      case QuotationStatus.rejected: return Colors.red;
    }
  }
  
  String get statusText {
    switch (status) {
      case QuotationStatus.draft: return 'Draft';
      case QuotationStatus.sent: return 'Sent';
      case QuotationStatus.accepted: return 'Accepted';
      case QuotationStatus.expired: return 'Expired';
      case QuotationStatus.rejected: return 'Rejected';
    }
  }
}

class PlateQuotation {
  final String id;
  final String name;
  final PlateType type;
  final double pricePerPlate;
  final int quantity;
  final double total;
  final List<PlateMenuItem> items;
  final String? description;

  PlateQuotation({
    required this.id,
    required this.name,
    required this.type,
    required this.pricePerPlate,
    required this.quantity,
    required this.total,
    required this.items,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'pricePerPlate': pricePerPlate,
      'quantity': quantity,
      'total': total,
      'items': items.map((i) => i.toMap()).toList(),
      'description': description,
    };
  }

  factory PlateQuotation.fromMap(Map<String, dynamic> map) {
    return PlateQuotation(
      id: map['id'],
      name: map['name'],
      type: PlateType.values[map['type']],
      pricePerPlate: map['pricePerPlate'],
      quantity: map['quantity'],
      total: map['total'],
      items: (map['items'] as List).map((i) => PlateMenuItem.fromMap(i)).toList(),
      description: map['description'],
    );
  }

  String get typeName {
    switch (type) {
      case PlateType.vegetarian: return 'Vegetarian';
      case PlateType.nonVegetarian: return 'Non-Vegetarian';
      case PlateType.jain: return 'Jain';
      case PlateType.vegan: return 'Vegan';
    }
  }

  Color get typeColor {
    switch (type) {
      case PlateType.vegetarian: return Colors.green;
      case PlateType.nonVegetarian: return Colors.red;
      case PlateType.jain: return Colors.orange;
      case PlateType.vegan: return Colors.teal;
    }
  }

  String get formattedPrice => 'Rs.  ${pricePerPlate.toStringAsFixed(2)}';
  String get formattedTotal => 'Rs.  ${total.toStringAsFixed(2)}';
}

class PlateMenuItem {
  final String id;
  final String name;
  final String? description;
  final bool included;

  PlateMenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.included,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'included': included,
    };
  }

  factory PlateMenuItem.fromMap(Map<String, dynamic> map) {
    return PlateMenuItem(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      included: map['included'],
    );
  }
}

class BanquetQuotation {
  final String id;
  final String name;
  final double price;
  final int hours;
  final double total;
  final String? description;
  final List<String> inclusions;

  BanquetQuotation({
    required this.id,
    required this.name,
    required this.price,
    required this.hours,
    required this.total,
    this.description,
    required this.inclusions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'hours': hours,
      'total': total,
      'description': description,
      'inclusions': inclusions,
    };
  }

  factory BanquetQuotation.fromMap(Map<String, dynamic> map) {
    return BanquetQuotation(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      hours: map['hours'],
      total: map['total'],
      description: map['description'],
      inclusions: List<String>.from(map['inclusions'] ?? []),
    );
  }

  String get formattedPrice => 'Rs.  ${price.toStringAsFixed(2)}';
  String get formattedTotal => 'Rs.  ${total.toStringAsFixed(2)}';
  String get hourlyRate => 'Rs.  ${(price / hours).toStringAsFixed(2)}/hour';
}

class AdditionalQuotationItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final double total;
  final String? unit;
  final String? description;

  AdditionalQuotationItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.total,
    this.unit,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'total': total,
      'unit': unit,
      'description': description,
    };
  }

  factory AdditionalQuotationItem.fromMap(Map<String, dynamic> map) {
    return AdditionalQuotationItem(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      quantity: map['quantity'],
      total: map['total'],
      unit: map['unit'],
      description: map['description'],
    );
  }

  String get formattedPrice => 'Rs.  ${price.toStringAsFixed(2)}';
  String get formattedTotal => 'Rs.  ${total.toStringAsFixed(2)}';
  String get formattedQuantity => '$quantity ${unit ?? ''}';
}