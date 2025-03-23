class DebtModel {
  final int? id;
  final int userId;
  final String username;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final DateTime createdAt;
  final String? notes;

  DebtModel({
    this.id,
    required this.userId,
    required this.username,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    DateTime? createdAt,
    this.notes,
  }) : this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'isPaid': isPaid ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      id: map['id'],
      userId: map['userId'],
      username: map['username'],
      amount: map['amount'],
      dueDate: DateTime.parse(map['dueDate']),
      isPaid: map['isPaid'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      notes: map['notes'],
    );
  }

  get updatedAt => null;
}