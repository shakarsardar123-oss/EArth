/// Maps a Sorani utterance to a device action name. Pure text logic,
/// not imported anywhere yet, so it cannot affect the build.
class DeviceIntent {
  const DeviceIntent(this.action, [this.argument = '']);
  final String action;
  final String argument;

  @override
  String toString() => 'DeviceIntent($action, $argument)';
}

DeviceIntent? parseDeviceIntent(String input) {
  final s = input.trim().toLowerCase();
  if (s.isEmpty) return null;

  if (RegExp(r'فلاش.*(هەڵکە|بکەرەوە|کردنەوە)|فلاش\s*هەڵکە').hasMatch(s)) {
    return const DeviceIntent('flashlight_on');
  }
  if (RegExp(r'فلاش.*(کوژێنەوە|داخە|بکوژێنەوە)').hasMatch(s)) {
    return const DeviceIntent('flashlight_off');
  }
  if (RegExp(r'بلوتوس.*(نزیک|بدۆزەوە|بگەڕێ)').hasMatch(s)) {
    return const DeviceIntent('bluetooth_scan');
  }
  if (RegExp(r'بلوتوس.*(پەیوەست|لیست)').hasMatch(s)) {
    return const DeviceIntent('bluetooth_list');
  }
  final song = RegExp(r'گۆرانی\s*(.+)').firstMatch(s);
  if (song != null) {
    return DeviceIntent('song', song.group(1)!.trim());
  }
  final call = RegExp(r'پەیوەندی\s*بکە\s*بە\s*(.+)').firstMatch(s);
  if (call != null) {
    return DeviceIntent('contact_call', call.group(1)!.trim());
  }
  return null;
}
