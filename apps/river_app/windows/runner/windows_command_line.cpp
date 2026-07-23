#include "windows_command_line.h"

std::wstring QuoteWindowsArgument(const std::wstring& argument) {
  if (!argument.empty() &&
      argument.find_first_of(L" \t\n\v\"") == std::wstring::npos) {
    return argument;
  }

  std::wstring quoted = L"\"";
  size_t backslashes = 0;
  for (const wchar_t character : argument) {
    if (character == L'\\') {
      ++backslashes;
      continue;
    }
    if (character == L'"') {
      quoted.append(backslashes * 2 + 1, L'\\');
      quoted.push_back(L'"');
      backslashes = 0;
      continue;
    }
    quoted.append(backslashes, L'\\');
    backslashes = 0;
    quoted.push_back(character);
  }
  quoted.append(backslashes * 2, L'\\');
  quoted.push_back(L'"');
  return quoted;
}

std::wstring JoinWindowsCommandLine(
    const std::vector<std::wstring>& arguments) {
  std::wstring command_line;
  for (const auto& argument : arguments) {
    if (!command_line.empty()) {
      command_line.push_back(L' ');
    }
    command_line.append(QuoteWindowsArgument(argument));
  }
  return command_line;
}
