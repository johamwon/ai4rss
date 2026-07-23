#ifndef RUNNER_BACKGROUND_REFRESH_SCHEDULER_H_
#define RUNNER_BACKGROUND_REFRESH_SCHEDULER_H_

#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "windows_command_line.h"

struct ProcessExit {
  bool launched = false;
  unsigned long code = 0;
};

class BackgroundRefreshScheduler {
 public:
  BackgroundRefreshScheduler();
  ~BackgroundRefreshScheduler();

  void Register(flutter::FlutterEngine* engine);

 private:
  ProcessExit RunTaskScheduler(
      const std::vector<std::wstring>& arguments) const;
  std::wstring ExecutablePath() const;
  bool TaskExists() const;
  bool DeleteTask(bool allow_missing) const;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::optional<int> interval_minutes_;
  bool wifi_only_ = false;
  bool pause_when_battery_low_ = true;
};

#endif  // RUNNER_BACKGROUND_REFRESH_SCHEDULER_H_
