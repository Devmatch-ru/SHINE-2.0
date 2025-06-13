class VideoSize {
  VideoSize(this.width, this.height);

  factory VideoSize.fromString(String size) {
    final parts = size.split('x');
    return VideoSize(int.parse(parts[0]), int.parse(parts[1]));
  }
  final int width;
  final int height;

  @override
  String toString() {
    return '$width x $height';
  }
}
