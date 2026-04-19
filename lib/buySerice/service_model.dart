class ServiceModel {
  final String id;
  final String title;
  final String description;
  final List<String> images;
  final List<String> features; // NEW FIELD
  final double price;
  final double discount;
  final Map<String, int> coupons;

  ServiceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.images,
    required this.features, // NEW FIELD
    required this.price,
    required this.discount,
    required this.coupons,
  });

  double get finalPrice => price - (price * discount / 100);

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json["id"].toString(),
      title: json["title"] ?? "",
      description: json["description"] ?? "",
      images: List<String>.from(json["images"] ?? []),
      features: List<String>.from(json["features"] ?? []), // NEW MAPPING
      price: double.parse(json["price"].toString()),
      discount: double.parse(json["discount"].toString()),
      coupons: Map<String, int>.from(json["coupons"] ?? {}),
    );
  }
}