#ifndef RUNNER_AUDIO_SYSTEM_SESSION_CONTROLS_H_
#define RUNNER_AUDIO_SYSTEM_SESSION_CONTROLS_H_

#include <flutter/flutter_engine.h>
#include <windows.h>

#include <memory>

class AudioSystemSessionControls {
 public:
  AudioSystemSessionControls();
  ~AudioSystemSessionControls();

  AudioSystemSessionControls(const AudioSystemSessionControls&) = delete;
  AudioSystemSessionControls& operator=(const AudioSystemSessionControls&) =
      delete;

  void Register(flutter::FlutterEngine* engine, HWND window);
  bool HandleWindowMessage(UINT message, WPARAM wparam);
  void Dispose();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_AUDIO_SYSTEM_SESSION_CONTROLS_H_
