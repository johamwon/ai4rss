# Architecture

```text
apps/river_app
    -> river_design_system
    -> river_domain ports
    -> feature adapters

river_domain
    <- river_data / river_feed / river_extract / river_ai / river_preferences
    <- river_audio / river_knowledge / river_sync / river_commerce
    <- river_platform

river_test_harness
    -> deterministic fakes, scenarios, fixtures and eval runners
```

## Dependency rule

`river_domain` must remain pure Dart. It owns entities, value objects and ports. Feature packages implement use cases or adapters. Only `river_platform`, `river_design_system` and `river_app` may depend on Flutter.

External providers are selected in the composition root. No feature may read global clocks, environment variables, random generators, HTTP clients or vendor singletons directly.

## Decision records

Cross-cutting changes require an ADR in `docs/adr`. Initial decisions:

- ADR-0001: Flutter modular monolith.
- ADR-0002: deterministic test harness.
- ADR-0003: local-first and optional cloud.
