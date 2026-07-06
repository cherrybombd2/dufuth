class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    this.category,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: json['id'] as String,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      category: json['category'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String question;
  final String answer;
  final String? category;
  final int sortOrder;
  final bool isActive;

  FaqItem copyWith({
    String? id,
    String? question,
    String? answer,
    String? category,
    int? sortOrder,
    bool? isActive,
  }) {
    return FaqItem(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      category: category ?? this.category,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
      'category': category,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
}

class FaqDraft {
  const FaqDraft({
    required this.question,
    required this.answer,
    this.category,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory FaqDraft.fromItem(FaqItem item) {
    return FaqDraft(
      question: item.question,
      answer: item.answer,
      category: item.category,
      sortOrder: item.sortOrder,
      isActive: item.isActive,
    );
  }

  final String question;
  final String answer;
  final String? category;
  final int sortOrder;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
      'category': category,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
}
