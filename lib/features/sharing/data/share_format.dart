/// Human byte + speed formatting for the sharing UI.
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var b = bytes.toDouble();
  var i = -1;
  do {
    b /= 1024;
    i++;
  } while (b >= 1024 && i < units.length - 1);
  return '${b.toStringAsFixed(decimals)} ${units[i]}';
}

String formatSpeed(double bytesPerSecond) =>
    bytesPerSecond <= 0 ? '' : '${formatBytes(bytesPerSecond.round())}/s';
