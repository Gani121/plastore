// lib/purchase_order/purchase_order_model.dart
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:test1/utilities.dart';
import '../utilities.dart';


enum PurchaseOrderStatus {
  draft,
  sent,
  confirmed,
  received,
  cancelled,
}

class PurchaseOrder {
  int syid;
  bool synced;
  final String id;
  final String orderNumber;
  final DateTime orderDate;
  final DateTime? expectedDeliveryDate;
  
  // Supplier details
  final String supplierId;
  final String supplierName;
  final String? supplierMobile;
  final String? supplierAddress;
  final String? supplierGst;
  
  // Order details
  final List<PurchaseOrderItem> items;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double shippingAmount;
  final double totalAmount;
  
  // Status and notes
  final PurchaseOrderStatus status;
  final String? notes;
  final String? termsAndConditions;
  
  // Payment terms
  final String? paymentTerms;
  final DateTime? dueDate;
  
  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  
  // Attachments
  final String? pdfPath;
  final String? signaturePath;

  PurchaseOrder({
    required this.syid,
    this.synced = false,
    required this.id,
    required this.orderNumber,
    required this.orderDate,
    this.expectedDeliveryDate,
    required this.supplierId,
    required this.supplierName,
    this.supplierMobile,
    this.supplierAddress,
    this.supplierGst,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.shippingAmount,
    required this.totalAmount,
    required this.status,
    this.notes,
    this.termsAndConditions,
    this.paymentTerms,
    this.dueDate,
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
      'orderNumber': orderNumber,
      'orderDate': orderDate.toIso8601String(),
      'expectedDeliveryDate': expectedDeliveryDate?.toIso8601String(),
      'supplierId': supplierId,
      'supplierName': supplierName,
      'supplierMobile': supplierMobile,
      'supplierAddress': supplierAddress,
      'supplierGst': supplierGst,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'shippingAmount': shippingAmount,
      'totalAmount': totalAmount,
      'status': status.index,
      'notes': notes,
      'termsAndConditions': termsAndConditions,
      'paymentTerms': paymentTerms,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy,
      'pdfPath': pdfPath,
      'signaturePath': signaturePath,
    };
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      syid: map['syid'] ?? 0,  // Provide default value if null
      synced: map['synced'] ?? false,
      id: map['id'],
      orderNumber: map['orderNumber'],
      orderDate: DateTime.parse(map['orderDate']),
      expectedDeliveryDate: map['expectedDeliveryDate'] != null 
          ? DateTime.parse(map['expectedDeliveryDate']) 
          : null,
      supplierId: map['supplierId'],
      supplierName: map['supplierName'],
      supplierMobile: map['supplierMobile'],
      supplierAddress: map['supplierAddress'],
      supplierGst: map['supplierGst'],
      items: (map['items'] as List)
          .map((item) => PurchaseOrderItem.fromMap(item))
          .toList(),
      subtotal: map['subtotal'],
      taxAmount: map['taxAmount'],
      discountAmount: map['discountAmount'],
      shippingAmount: map['shippingAmount'],
      totalAmount: map['totalAmount'],
      status: PurchaseOrderStatus.values[map['status']],
      notes: map['notes'],
      termsAndConditions: map['termsAndConditions'],
      paymentTerms: map['paymentTerms'],
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      createdBy: map['createdBy'],
      pdfPath: map['pdfPath'],
      signaturePath: map['signaturePath'],
    );
  }

  String get formattedOrderDate => DateFormat('dd/MM/yyyy').format(orderDate);
  String get formattedExpectedDate => expectedDeliveryDate != null 
      ? DateFormat('dd/MM/yyyy').format(expectedDeliveryDate!) 
      : 'Not set';
  String get formattedTotal => 'Rs. ${totalAmount.toStringAsFixed(2)}';
  
  Color get statusColor {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return Colors.grey;
      case PurchaseOrderStatus.sent:
        return Colors.blue;
      case PurchaseOrderStatus.confirmed:
        return Colors.green;
      case PurchaseOrderStatus.received:
        return Colors.purple;
      case PurchaseOrderStatus.cancelled:
        return Colors.red;
    }
  }
  
  String get statusText {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return 'Draft';
      case PurchaseOrderStatus.sent:
        return 'Sent';
      case PurchaseOrderStatus.confirmed:
        return 'Confirmed';
      case PurchaseOrderStatus.received:
        return 'Received';
      case PurchaseOrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class PurchaseOrderItem {
  final String id;
  final String name;
  final String? description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discount;
  final double tax;
  final double total;
  
  // Reference to source (menu item or inventory item)
  final String? sourceId;
  final String? sourceType; // 'menu' or 'inventory'
  
  // Stock tracking
  final double? currentStock;
  final double? minimumStock;
  final double discountAmount; // calculated discount amount
  final double taxAmount; // calculated tax amount
  final double subtotal; // quantity * unitPrice

  PurchaseOrderItem({
    required this.id,
    required this.name,
    this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    this.sourceId,
    this.sourceType,
    this.currentStock,
    this.minimumStock,
    required this.discountAmount,
    required this.taxAmount,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'discount': discount,
      'tax': tax,
      'total': total,
      'sourceId': sourceId,
      'sourceType': sourceType,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'subtotal': subtotal,
    };
  }

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      quantity: map['quantity'],
      unit: map['unit'],
      unitPrice: map['unitPrice'],
      discount: map['discount'] ?? 0,
      tax: map['tax'] ?? 0,
      total: map['total'],
      sourceId: map['sourceId'],
      sourceType: map['sourceType'],
      currentStock: map['currentStock']?.toDouble(),
      minimumStock: map['minimumStock']?.toDouble(),
      discountAmount: map['discountAmount'],
      taxAmount: map['taxAmount'],
      subtotal: map['subtotal'],
    );
  }

  String get formattedUnitPrice => 'Rs. ${unitPrice.toStringAsFixed(2)}';
  String get formattedTotal => 'Rs. ${total.toStringAsFixed(2)}';
  String get formattedQuantity => quantity.toStringAsFixed(2);
  String get formattedDiscount => '${discount.toStringAsFixed(0)}%';
  String get formattedTax => '${tax.toStringAsFixed(0)}%';
}