# ADR-0001: Flutter modular monolith

Status: Accepted

River uses one Flutter application, pure-Dart domain packages and explicit adapters. This preserves shared behavior across three platforms without introducing a second systems-language core before profiling proves it necessary.
