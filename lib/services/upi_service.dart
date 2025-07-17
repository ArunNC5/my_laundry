// UPI QR code generation logic
class UpiService {
  static String generateUpiUrl({
    required String upiId,
    required String name,
    required double amount,
  }) {
    return 'upi://pay?pa=$upiId&pn=$name&am=${amount.toStringAsFixed(2)}&cu=INR';
  }
}
