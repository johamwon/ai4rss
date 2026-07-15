# Native runners

The shared Flutter app is committed, while generated Android, iOS and Windows runners must be created once on a machine with Flutter installed:

```powershell
.\tool\bootstrap.ps1
```

Review and commit `android/`, `ios/`, `windows/` and `.metadata` after generation. Native feature implementations belong behind contracts in `river_platform`; do not place business rules in runner code.
