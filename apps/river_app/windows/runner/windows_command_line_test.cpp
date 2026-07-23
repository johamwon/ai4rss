#include "windows_command_line.h"

#include <cassert>

int main() {
  assert(QuoteWindowsArgument(L"/Create") == L"/Create");
  assert(QuoteWindowsArgument(L"River Background Feed Refresh") ==
         L"\"River Background Feed Refresh\"");
  assert(QuoteWindowsArgument(L"") == L"\"\"");
  assert(QuoteWindowsArgument(L"C:\\River\\") == L"C:\\River\\");
  assert(QuoteWindowsArgument(L"\"C:\\Program Files\\River\\river_app.exe\" "
                              L"--river-background-refresh") ==
         L"\"\\\"C:\\Program Files\\River\\river_app.exe\\\" "
         L"--river-background-refresh\"");
  assert(JoinWindowsCommandLine(
             {L"schtasks.exe", L"/TN", L"River Background Feed Refresh"}) ==
         L"schtasks.exe /TN \"River Background Feed Refresh\"");
  return 0;
}
