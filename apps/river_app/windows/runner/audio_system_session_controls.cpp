#include "audio_system_session_controls.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Media.Playback.h>
#include <winrt/base.h>

#include <optional>
#include <string>
#include <variant>

namespace {

constexpr UINT kAudioSystemCommandMessage = WM_APP + 0x52;

enum class CommandCode {
  kPlay = 1,
  kPause,
  kStop,
  kNext,
  kPrevious,
};

std::optional<std::string> ReadString(const flutter::EncodableMap& arguments,
                                      const char* key) {
  const auto iterator = arguments.find(flutter::EncodableValue(key));
  if (iterator == arguments.end()) {
    return std::nullopt;
  }
  const auto* value = std::get_if<std::string>(&iterator->second);
  return value == nullptr ? std::nullopt
                          : std::optional<std::string>(*value);
}

bool ReadBool(const flutter::EncodableMap& arguments, const char* key,
              bool fallback) {
  const auto iterator = arguments.find(flutter::EncodableValue(key));
  if (iterator == arguments.end()) {
    return fallback;
  }
  const auto* value = std::get_if<bool>(&iterator->second);
  return value == nullptr ? fallback : *value;
}

std::string CommandName(CommandCode command) {
  switch (command) {
    case CommandCode::kPlay:
      return "play";
    case CommandCode::kPause:
      return "pause";
    case CommandCode::kStop:
      return "stop";
    case CommandCode::kNext:
      return "next";
    case CommandCode::kPrevious:
      return "previous";
  }
  return "";
}

}  // namespace

struct AudioSystemSessionControls::Impl {
  HWND window = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;
  winrt::Windows::Media::Playback::MediaPlayer media_player{nullptr};
  winrt::Windows::Media::SystemMediaTransportControls controls{nullptr};
  winrt::Windows::Media::SystemMediaTransportControlsDisplayUpdater updater{
      nullptr};
  winrt::event_token button_token{};
  bool button_registered = false;

  void EnsureInitialized() {
    if (controls != nullptr) {
      return;
    }
    media_player = winrt::Windows::Media::Playback::MediaPlayer();
    controls = media_player.SystemMediaTransportControls();
    updater = controls.DisplayUpdater();
    controls.IsPlayEnabled(true);
    controls.IsPauseEnabled(true);
    controls.IsStopEnabled(true);
    controls.IsNextEnabled(false);
    controls.IsPreviousEnabled(false);
    controls.IsEnabled(false);
    button_token = controls.ButtonPressed(
        [window_handle = window](
            const auto&,
            const winrt::Windows::Media::
                SystemMediaTransportControlsButtonPressedEventArgs& args) {
          std::optional<CommandCode> command;
          using Button =
              winrt::Windows::Media::SystemMediaTransportControlsButton;
          switch (args.Button()) {
            case Button::Play:
              command = CommandCode::kPlay;
              break;
            case Button::Pause:
              command = CommandCode::kPause;
              break;
            case Button::Stop:
              command = CommandCode::kStop;
              break;
            case Button::Next:
              command = CommandCode::kNext;
              break;
            case Button::Previous:
              command = CommandCode::kPrevious;
              break;
            default:
              break;
          }
          if (command.has_value()) {
            PostMessage(window_handle, kAudioSystemCommandMessage,
                        static_cast<WPARAM>(*command), 0);
          }
        });
    button_registered = true;
  }

  void Clear() {
    if (controls == nullptr) {
      return;
    }
    controls.PlaybackStatus(
        winrt::Windows::Media::MediaPlaybackStatus::Stopped);
    controls.IsEnabled(false);
    updater.ClearAll();
    updater.Update();
  }
};

AudioSystemSessionControls::AudioSystemSessionControls()
    : impl_(std::make_unique<Impl>()) {}

AudioSystemSessionControls::~AudioSystemSessionControls() {
  Dispose();
}

void AudioSystemSessionControls::Register(flutter::FlutterEngine* engine,
                                          HWND window) {
  impl_->window = window;
  impl_->channel = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "app.river/audio_system_session",
      &flutter::StandardMethodCodec::GetInstance());
  impl_->channel->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        try {
          if (call.method_name() == "initialize") {
            impl_->EnsureInitialized();
            result->Success();
            return;
          }
          if (call.method_name() == "activate") {
            impl_->EnsureInitialized();
            result->Success(flutter::EncodableValue(true));
            return;
          }
          if (call.method_name() == "deactivate") {
            result->Success();
            return;
          }
          if (call.method_name() == "clear") {
            impl_->Clear();
            result->Success();
            return;
          }
          if (call.method_name() == "dispose") {
            impl_->Clear();
            result->Success();
            return;
          }
          if (call.method_name() != "publish") {
            result->NotImplemented();
            return;
          }

          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr) {
            result->Error("invalid_arguments", "publish requires a map");
            return;
          }
          const auto title = ReadString(*arguments, "title");
          const auto phase = ReadString(*arguments, "phase");
          if (!title.has_value() || !phase.has_value()) {
            result->Error("invalid_arguments",
                          "title and phase are required");
            return;
          }

          impl_->EnsureInitialized();
          impl_->controls.IsEnabled(true);
          impl_->controls.IsNextEnabled(
              ReadBool(*arguments, "canSkipNext", false));
          impl_->controls.IsPreviousEnabled(
              ReadBool(*arguments, "canSkipPrevious", false));
          impl_->updater.ClearAll();
          impl_->updater.Type(
              winrt::Windows::Media::MediaPlaybackType::Music);
          impl_->updater.MusicProperties().Title(
              winrt::to_hstring(*title));
          impl_->updater.MusicProperties().Artist(L"River");
          impl_->updater.Update();

          using Status = winrt::Windows::Media::MediaPlaybackStatus;
          if (*phase == "playing") {
            impl_->controls.PlaybackStatus(Status::Playing);
          } else if (*phase == "paused" || *phase == "interrupted" ||
                     *phase == "ready") {
            impl_->controls.PlaybackStatus(Status::Paused);
          } else if (*phase == "loading") {
            impl_->controls.PlaybackStatus(Status::Changing);
          } else {
            impl_->controls.PlaybackStatus(Status::Stopped);
          }
          result->Success();
        } catch (const winrt::hresult_error&) {
          result->Error("audio_system_session_failed",
                        "Windows media controls are unavailable");
        }
      });
}

bool AudioSystemSessionControls::HandleWindowMessage(UINT message,
                                                     WPARAM wparam) {
  if (message != kAudioSystemCommandMessage || impl_->channel == nullptr) {
    return false;
  }
  const auto name = CommandName(static_cast<CommandCode>(wparam));
  if (!name.empty()) {
    impl_->channel->InvokeMethod(
        "onCommand",
        std::make_unique<flutter::EncodableValue>(name));
  }
  return true;
}

void AudioSystemSessionControls::Dispose() {
  if (!impl_) {
    return;
  }
  try {
    impl_->Clear();
    if (impl_->button_registered && impl_->controls != nullptr) {
      impl_->controls.ButtonPressed(impl_->button_token);
    }
  } catch (const winrt::hresult_error&) {
    // Shutdown must remain safe when the system media service disappears.
  }
  impl_->button_registered = false;
  impl_->channel.reset();
  impl_->updater = nullptr;
  impl_->controls = nullptr;
  impl_->media_player = nullptr;
}
