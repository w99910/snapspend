class Receipt {
  final int? id;
  final String imagePath;
  final DateTime imageTaken;
  final double amount;
  final String? recipient;
  final String? merchantName;
  final String? category;
  final String? rawOcrText;
  final String? rawJsonData;

  Receipt({
    this.id,
    required this.imagePath,
    required this.imageTaken,
    required this.amount,
    this.recipient,
    this.merchantName,
    this.category,
    this.rawOcrText,
    this.rawJsonData,
  });

  /// Convert Receipt to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_path': imagePath,
      'image_taken': imageTaken.toIso8601String(),
      'amount': amount,
      'recipient': recipient,
      'merchant_name': merchantName,
      'category': category,
      'raw_ocr_text': rawOcrText,
      'raw_json_data': rawJsonData,
    };
  }

  /// Create Receipt from Map (database query result)
  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'] as int?,
      imagePath: map['image_path'] as String,
      imageTaken: DateTime.parse(map['image_taken'] as String),
      amount: map['amount'] as double,
      recipient: map['recipient'] as String?,
      merchantName: map['merchant_name'] as String?,
      category: map['category'] as String?,
      rawOcrText: map['raw_ocr_text'] as String?,
      rawJsonData: map['raw_json_data'] as String?,
    );
  }

  /// Create a copy of this receipt with updated fields
  Receipt copyWith({
    int? id,
    String? imagePath,
    DateTime? imageTaken,
    double? amount,
    String? recipient,
    String? merchantName,
    String? category,
    String? rawOcrText,
    String? rawJsonData,
  }) {
    return Receipt(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      imageTaken: imageTaken ?? this.imageTaken,
      amount: amount ?? this.amount,
      recipient: recipient ?? this.recipient,
      merchantName: merchantName ?? this.merchantName,
      category: category ?? this.category,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      rawJsonData: rawJsonData ?? this.rawJsonData,
    );
  }

  @override
  String toString() {
    return 'Receipt{id: $id, merchant: $merchantName, amount: \$$amount, date: $imageTaken, recipient: $recipient}';
  }
}
