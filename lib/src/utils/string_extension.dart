extension StringExtension on String {
  bool isPdf() {
    return toLowerCase().endsWith('.pdf');
  }
}
