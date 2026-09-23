import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import 'pcm_audio_source.dart';

/// Thrown when a replay file is missing or is not the format the pipeline
/// expects. Always a developer error, never something a user can hit.
class ReplayAudioException implements Exception {
  const ReplayAudioException(this.message);

  final String message;

  @override
  String toString() => 'ReplayAudioException: $message';
}

/// Development-only [PcmAudioSource] that plays a WAV file into the recording
/// pipeline as if it came from the microphone.
///
/// Two things make this worth having over a mocked stream:
///   * the emulator's virtual microphone on this machine only ever produces a
///     DC offset, so there is no other way to get real speech through the
///     chunker;
///   * a 20-minute robustness run can be driven by [loop]ing a short file
///     instead of somebody talking for 20 minutes.
///
/// Audio is emitted in real time — one [sliceDuration] worth of bytes per
/// [sliceDuration] — because chunk lengths, silence detection and the "does
/// the transcript keep up" question are all meaningless at any other pace.
class WavReplayAudioSource implements PcmAudioSource {
  WavReplayAudioSource({
    required this.candidateFileNames,
    this.loop = false,
    this.sliceDuration = kSilenceFrameDuration,
  });

  static const _tag = 'audio.replay';

  /// File names to look for in the app documents directory, in order. The
  /// first one that exists wins, so a machine with only the short sample
  /// still works.
  final List<String> candidateFileNames;

  final bool loop;
  final Duration sliceDuration;

  StreamController<Uint8List>? _controller;
  Timer? _timer;
  Uint8List? _pcm;
  int _offset = 0;
  int _loops = 0;
  bool _paused = false;

  int get _sliceBytes =>
      (kSampleRateHz *
          kChannels *
          (kBitsPerSample ~/ 8) *
          sliceDuration.inMilliseconds) ~/
      1000;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<Stream<Uint8List>> start() async {
    if (_controller != null) {
      throw StateError('WavReplayAudioSource is already playing');
    }

    final file = await _resolveFile();
    final pcm = _pcmPayloadOf(await file.readAsBytes(), p.basename(file.path));
    _pcm = pcm;
    _offset = 0;
    _loops = 0;
    _paused = false;

    final seconds =
        pcm.length / (kSampleRateHz * kChannels * (kBitsPerSample ~/ 8));
    AppLog.d(
      _tag,
      'replaying ${p.basename(file.path)}: ${pcm.length} B '
      '(${seconds.toStringAsFixed(1)}s), loop=$loop',
    );

    final controller = StreamController<Uint8List>();
    _controller = controller;
    _timer = Timer.periodic(sliceDuration, (_) => _emitSlice());

    return controller.stream;
  }

  @override
  Future<void> pause() async {
    if (_controller == null || _paused) return;
    _timer?.cancel();
    _timer = null;
    _paused = true;
    AppLog.d(_tag, 'replay paused');
  }

  @override
  Future<void> resume() async {
    if (_controller == null || !_paused) return;
    _paused = false;
    _timer = Timer.periodic(sliceDuration, (_) => _emitSlice());
    AppLog.d(_tag, 'replay resumed');
  }

  void _emitSlice() {
    final controller = _controller;
    final pcm = _pcm;
    if (controller == null || pcm == null || controller.isClosed) return;

    if (_offset >= pcm.length) {
      if (!loop) {
        AppLog.d(_tag, 'replay finished after ${_loops + 1} pass(es)');
        unawaited(stop());
        return;
      }
      _offset = 0;
      _loops++;
      AppLog.d(_tag, 'replay loop $_loops');
    }

    final end = math.min(_offset + _sliceBytes, pcm.length);
    // sublist copies, so the consumer can hold on to the slice without it
    // being mutated underneath them on the next tick.
    controller.add(pcm.sublist(_offset, end));
    _offset = end;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;

    final controller = _controller;
    _controller = null;
    _pcm = null;
    _paused = false;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  @override
  Future<void> dispose() => stop();

  Future<File> _resolveFile() async {
    final docs = await getApplicationDocumentsDirectory();
    for (final name in candidateFileNames) {
      final file = File(p.join(docs.path, name));
      if (file.existsSync()) return file;
    }
    throw ReplayAudioException(
      'None of ${candidateFileNames.join(', ')} found in ${docs.path}. '
      'Put one there first.',
    );
  }

  /// Returns the raw samples of a RIFF/WAVE file, after checking the format
  /// matches what the pipeline expects.
  ///
  /// The header is walked chunk by chunk rather than assuming the canonical
  /// 44 bytes: Windows SAPI, which generates the test files, likes to insert
  /// `fact` and `LIST` chunks, and blindly skipping 44 bytes would then feed
  /// metadata into the chunker as if it were audio.
  static Uint8List _pcmPayloadOf(Uint8List bytes, String name) {
    if (bytes.length < 12) {
      throw ReplayAudioException('$name is too short to be a WAV file.');
    }

    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    String tagAt(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));

    if (tagAt(0) != 'RIFF' || tagAt(8) != 'WAVE') {
      throw ReplayAudioException('$name is not a RIFF/WAVE file.');
    }

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = tagAt(offset);
      final size = data.getUint32(offset + 4, Endian.little);
      final body = offset + 8;

      if (id == 'fmt ' && body + 16 <= bytes.length) {
        final format = data.getUint16(body, Endian.little);
        final channels = data.getUint16(body + 2, Endian.little);
        final sampleRate = data.getUint32(body + 4, Endian.little);
        final bits = data.getUint16(body + 14, Endian.little);

        if (format != 1 ||
            channels != kChannels ||
            sampleRate != kSampleRateHz ||
            bits != kBitsPerSample) {
          throw ReplayAudioException(
            '$name is format=$format ${sampleRate}Hz ${channels}ch ${bits}bit; '
            'expected PCM ${kSampleRateHz}Hz ${kChannels}ch ${kBitsPerSample}bit.',
          );
        }
      } else if (id == 'data') {
        // A truncated file (interrupted write) declares more than it holds, so
        // trust the file length over the declared size.
        final end = math.min(body + size, bytes.length);
        return Uint8List.sublistView(bytes, body, end);
      }

      // Chunks are word-aligned: an odd size is followed by a pad byte.
      offset = body + size + (size.isOdd ? 1 : 0);
    }

    throw ReplayAudioException('$name has no data chunk.');
  }
}
