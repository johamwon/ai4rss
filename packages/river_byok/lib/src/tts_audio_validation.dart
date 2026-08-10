import 'dart:convert';

import 'configuration.dart';

String expectedTtsMediaType(ByokAudioFormat format) => switch (format) {
      ByokAudioFormat.mp3 => 'audio/mpeg',
      ByokAudioFormat.wav => 'audio/wav',
      ByokAudioFormat.opus => 'audio/opus',
      ByokAudioFormat.aac => 'audio/aac',
      ByokAudioFormat.flac => 'audio/flac',
    };

bool acceptedTtsMediaType(String value, ByokAudioFormat format) =>
    switch (format) {
      ByokAudioFormat.mp3 => value == 'audio/mpeg' || value == 'audio/mp3',
      ByokAudioFormat.wav => value == 'audio/wav' || value == 'audio/x-wav',
      ByokAudioFormat.opus => value == 'audio/opus' || value == 'audio/ogg',
      ByokAudioFormat.aac => value == 'audio/aac' || value == 'audio/mp4',
      ByokAudioFormat.flac => value == 'audio/flac' || value == 'audio/x-flac',
    };

bool hasValidTtsAudioSignature(List<int> bytes, ByokAudioFormat format) {
  if (bytes.length < 4) return false;
  return switch (format) {
    ByokAudioFormat.mp3 =>
      (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
          (bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0),
    ByokAudioFormat.wav => bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46,
    ByokAudioFormat.opus => bytes.length >= 8 &&
        utf8.decode(bytes.sublist(0, 4), allowMalformed: true) == 'OggS',
    ByokAudioFormat.aac => bytes[0] == 0xff && (bytes[1] & 0xf0) == 0xf0,
    ByokAudioFormat.flac =>
      utf8.decode(bytes.sublist(0, 4), allowMalformed: true) == 'fLaC',
  };
}
