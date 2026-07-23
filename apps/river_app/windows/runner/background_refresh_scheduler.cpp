#include "background_refresh_scheduler.h"

#include <windows.h>

#include <cstdint>
#include <limits>
#include <utility>

namespace {

constexpr wchar_t kTaskName[] = L"River Background Feed Refresh";
constexpr wchar_t kBackgroundArgument[] = L"--river-background-refresh";

const flutter::EncodableValue* FindValue(
    const flutter::EncodableMap& arguments,
    const char* key) {
  const auto iterator = arguments.find(flutter::EncodableValue(key));
  return iterator == arguments.end() ? nullptr : &iterator->second;
}

std::optional<int> ReadInteger(const flutter::EncodableMap& arguments,
                               const char* key) {
  const auto* value = FindValue(arguments, key);
  if (value == nullptr) {
    return std::nullopt;
  }
  if (const auto* integer = std::get_if<int32_t>(value)) {
    return *integer;
  }
  if (const auto* integer = std::get_if<int64_t>(value);
      integer != nullptr &&
      *integer >= std::numeric_limits<int>::min() &&
      *integer <= std::numeric_limits<int>::max()) {
    return static_cast<int>(*integer);
  }
  return std::nullopt;
}

std::optional<bool> ReadBoolean(const flutter::EncodableMap& arguments,
                                const char* key) {
  const auto* value = FindValue(arguments, key);
  if (value == nullptr) {
    return std::nullopt;
  }
  if (const auto* boolean = std::get_if<bool>(value)) {
    return *boolean;
  }
  return std::nullopt;
}

flutter::EncodableMap StatusMap(const char* state,
                                const std::optional<int>& interval_minutes,
                                bool wifi_only,
                                bool pause_when_battery_low) {
  flutter::EncodableMap response = {
      {flutter::EncodableValue("state"), flutter::EncodableValue(state)},
      {flutter::EncodableValue("detail"),
       flutter::EncodableValue(
           "Windows Task Scheduler owns the opportunistic launch window.")},
      {flutter::EncodableValue("wifiOnly"),
       flutter::EncodableValue(wifi_only)},
      {flutter::EncodableValue("pauseWhenBatteryLow"),
       flutter::EncodableValue(pause_when_battery_low)},
  };
  if (interval_minutes.has_value()) {
    response.emplace(flutter::EncodableValue("intervalMinutes"),
                     flutter::EncodableValue(*interval_minutes));
  }
  return response;
}

}  // namespace

BackgroundRefreshScheduler::BackgroundRefreshScheduler() = default;

BackgroundRefreshScheduler::~BackgroundRefreshScheduler() = default;

void BackgroundRefreshScheduler::Register(flutter::FlutterEngine* engine) {
  channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), "app.river/background_refresh",
          &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        if (call.method_name() == "configure") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr) {
            result->Error("invalid_arguments",
                          "Background refresh policy must be a map.");
            return;
          }
          const auto interval = ReadInteger(*arguments, "intervalMinutes");
          const auto wifi_only = ReadBoolean(*arguments, "wifiOnly");
          const auto pause_when_battery_low =
              ReadBoolean(*arguments, "pauseWhenBatteryLow");
          if (!interval.has_value() || *interval < 15 || *interval > 1440 ||
              !wifi_only.has_value() ||
              !pause_when_battery_low.has_value()) {
            result->Error(
                "invalid_arguments",
                "Interval must be 15-1440 minutes and constraints must be "
                "booleans.");
            return;
          }

          const auto executable = ExecutablePath();
          if (executable.empty()) {
            result->Error("executable_unavailable",
                          "River executable path could not be resolved.");
            return;
          }
          const std::wstring task_run =
              L"\"" + executable + L"\" " + kBackgroundArgument;
          const auto process = RunTaskScheduler(
              {L"/Create", L"/TN", kTaskName, L"/TR", task_run, L"/SC",
               L"MINUTE", L"/MO", std::to_wstring(*interval), L"/RL",
               L"LIMITED", L"/F"});
          if (!process.launched || process.code != ERROR_SUCCESS) {
            result->Error(
                "schedule_failed",
                "Windows Task Scheduler rejected the River refresh task.",
                flutter::EncodableValue(
                    static_cast<int64_t>(process.code)));
            return;
          }
          interval_minutes_ = interval;
          wifi_only_ = *wifi_only;
          pause_when_battery_low_ = *pause_when_battery_low;
          result->Success();
          return;
        }

        if (call.method_name() == "inspect") {
          const bool exists = TaskExists();
          result->Success(flutter::EncodableValue(StatusMap(
              exists ? "scheduled" : "notScheduled", interval_minutes_,
              wifi_only_, pause_when_battery_low_)));
          return;
        }

        if (call.method_name() == "cancel") {
          if (!DeleteTask(true)) {
            result->Error("cancel_failed",
                          "Windows Task Scheduler could not remove the River "
                          "refresh task.");
            return;
          }
          interval_minutes_.reset();
          result->Success();
          return;
        }

        result->NotImplemented();
      });
}

ProcessExit BackgroundRefreshScheduler::RunTaskScheduler(
    const std::vector<std::wstring>& arguments) const {
  wchar_t system_directory[MAX_PATH] = {};
  const UINT length =
      ::GetSystemDirectoryW(system_directory, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return {};
  }
  const std::wstring application =
      std::wstring(system_directory) + L"\\schtasks.exe";
  std::vector<std::wstring> command_arguments = {application};
  command_arguments.insert(command_arguments.end(), arguments.begin(),
                           arguments.end());
  std::wstring command_line = JoinWindowsCommandLine(command_arguments);

  STARTUPINFOW startup_info = {};
  startup_info.cb = sizeof(startup_info);
  startup_info.dwFlags = STARTF_USESHOWWINDOW;
  startup_info.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION process_info = {};
  const BOOL created = ::CreateProcessW(
      application.c_str(), command_line.data(), nullptr, nullptr, FALSE,
      CREATE_NO_WINDOW, nullptr, nullptr, &startup_info, &process_info);
  if (!created) {
    return {false, ::GetLastError()};
  }

  ::WaitForSingleObject(process_info.hProcess, INFINITE);
  DWORD exit_code = ERROR_GEN_FAILURE;
  ::GetExitCodeProcess(process_info.hProcess, &exit_code);
  ::CloseHandle(process_info.hThread);
  ::CloseHandle(process_info.hProcess);
  return {true, exit_code};
}

std::wstring BackgroundRefreshScheduler::ExecutablePath() const {
  std::wstring path(MAX_PATH, L'\0');
  while (true) {
    const DWORD length =
        ::GetModuleFileNameW(nullptr, path.data(),
                             static_cast<DWORD>(path.size()));
    if (length == 0) {
      return {};
    }
    if (length < path.size() - 1) {
      path.resize(length);
      return path;
    }
    path.resize(path.size() * 2);
  }
}

bool BackgroundRefreshScheduler::TaskExists() const {
  const auto process =
      RunTaskScheduler({L"/Query", L"/TN", kTaskName, L"/FO", L"CSV",
                        L"/NH"});
  return process.launched && process.code == ERROR_SUCCESS;
}

bool BackgroundRefreshScheduler::DeleteTask(bool allow_missing) const {
  const auto process =
      RunTaskScheduler({L"/Delete", L"/TN", kTaskName, L"/F"});
  if (!process.launched) {
    return false;
  }
  return process.code == ERROR_SUCCESS ||
         (allow_missing && !TaskExists());
}
