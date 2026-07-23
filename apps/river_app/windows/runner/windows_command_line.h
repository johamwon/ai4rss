#ifndef RUNNER_WINDOWS_COMMAND_LINE_H_
#define RUNNER_WINDOWS_COMMAND_LINE_H_

#include <string>
#include <vector>

std::wstring QuoteWindowsArgument(const std::wstring& argument);
std::wstring JoinWindowsCommandLine(
    const std::vector<std::wstring>& arguments);

#endif  // RUNNER_WINDOWS_COMMAND_LINE_H_
