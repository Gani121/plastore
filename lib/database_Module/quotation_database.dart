// lib/quotation/quotation_database.dart
import 'package:objectbox/objectbox.dart';
import 'dart:convert';

@Entity()
class QuotationEntity {
  @Id()
  int id = 0;
    int syid;
  bool synced;
  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();
  
  String quotationData; // JSON string containing all quotation data
  
  String? pdfPath;
  String? signaturePath;
  
  // Indexed fields for faster queries
  @Index()
  String quotationNumber = '';
  
  @Index()
  String partyName = '';
  
  @Index()
  int statusIndex = 0;
  
  @Property(type: PropertyType.date)
  DateTime quotationDate = DateTime.now();
  
  @Property(type: PropertyType.date)
  DateTime? eventDate;

  QuotationEntity({
    required this.quotationData,
        required this.syid,
    this.synced = false,
    this.pdfPath,
    this.signaturePath,
    String? quotationNumber,
    String? partyName,
    int? statusIndex,
    DateTime? quotationDate,
    this.eventDate,
  }) {
    // Parse quotation data to extract indexed fields
    try {
      final Map<String, dynamic> data = jsonDecode(quotationData);
      this.syid = syid;
      this.synced = synced;
      this.quotationNumber = quotationNumber ?? data['quotationNumber'] ?? '';
      this.partyName = partyName ?? data['partyName'] ?? '';
      this.statusIndex = statusIndex ?? data['status'] ?? 0;
      this.quotationDate = quotationDate ?? 
          (data['quotationDate'] != null 
              ? DateTime.parse(data['quotationDate']) 
              : DateTime.now());
      this.eventDate = data['eventDate'] != null 
          ? DateTime.parse(data['eventDate']) 
          : null;
    } catch (e) {
      this.quotationNumber = quotationNumber ?? '';
      this.partyName = partyName ?? '';
      this.statusIndex = statusIndex ?? 0;
      this.quotationDate = quotationDate ?? DateTime.now();
    }
  }
}