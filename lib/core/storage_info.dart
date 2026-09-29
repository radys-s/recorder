import 'package:flutter/services.dart';

/// Free space on the device, asked of the platform. Null when the platform
/// cannot say (web preview, tests) — callers then simply skip the check.
class StorageInfo {
  const StorageInfo();

  static const _channel = MethodChannel('recorder/storage');

  Future<int?> freeBytes() async {
    try {
      final value = await _channel.invokeMethod<num>('freeBytes');
      return value?.toInt();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// Below this a lesson is at risk: an hour of recording is about 115 MB, plus
/// the copy the refined pass makes.
const int kLowDiskBytes = 500 * 1024 * 1024;

/// Below this a chunk write is about to fail; stop cleanly instead.
const int kCriticalDiskBytes = 30 * 1024 * 1024;
