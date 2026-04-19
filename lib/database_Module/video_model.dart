// models/video_model.dart
class TrainingVideo {
  final int id;
  final String videoCode;
  final String title;
  final String? description;
  final int orderIndex;
  final String thumbnailUrl;
  final String thumbnailMedium;

  TrainingVideo({
    required this.id,
    required this.videoCode,
    required this.title,
    this.description,
    required this.orderIndex,
    required this.thumbnailUrl,
    required this.thumbnailMedium,
  });

  factory TrainingVideo.fromJson(Map<String, dynamic> json) {
    // Handle id if it comes as string or int
    int id;
    if (json['id'] is int) {
      id = json['id'];
    } else if (json['id'] is String) {
      id = int.parse(json['id']);
    } else {
      id = 0;
    }
    
    // Handle order_index similarly
    int orderIndex;
    if (json['order_index'] is int) {
      orderIndex = json['order_index'];
    } else if (json['order_index'] is String) {
      orderIndex = int.parse(json['order_index']);
    } else {
      orderIndex = 0;
    }
    
    return TrainingVideo(
      id: id,
      videoCode: json['video_code'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      orderIndex: orderIndex,
      thumbnailUrl: json['thumbnail_url'] ?? '',
      thumbnailMedium: json['thumbnail_medium'] ?? '',
    );
  }
  
  // Optional: Convert to JSON if needed
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video_code': videoCode,
      'title': title,
      'description': description,
      'order_index': orderIndex,
      'thumbnail_url': thumbnailUrl,
      'thumbnail_medium': thumbnailMedium,
    };
  }
}