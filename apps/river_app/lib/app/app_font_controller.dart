import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:river_platform/river_platform.dart';

abstract interface class RuntimeFontLoader {
  Future<void> load(CustomFontAsset asset);
}

final class FlutterRuntimeFontLoader implements RuntimeFontLoader {
  final Set<String> _loadedFamilies = <String>{};

  @override
  Future<void> load(CustomFontAsset asset) async {
    if (!_loadedFamilies.add(asset.family)) return;
    final loader = FontLoader(asset.family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(asset.bytes)));
    try {
      await loader.load();
    } on Object {
      _loadedFamilies.remove(asset.family);
      rethrow;
    }
  }
}

enum CustomFontImportOutcome { imported, cancelled }

final class AppFontController extends ChangeNotifier {
  AppFontController({
    required CustomFontAssetRepository repository,
    RuntimeFontLoader? loader,
  })  : _repository = repository,
        _loader = loader ?? FlutterRuntimeFontLoader();

  final CustomFontAssetRepository _repository;
  final RuntimeFontLoader _loader;

  CustomFontAsset? _active;
  bool _busy = false;
  bool _initialized = false;
  String? _startupFailure;

  CustomFontAsset? get active => _active;
  String? get activeFamily => _active?.family;
  bool get busy => _busy;
  bool get initialized => _initialized;
  String? get startupFailure => _startupFailure;

  Future<void> initialize() async {
    if (_initialized || _busy) return;
    _setBusy(true);
    try {
      final asset = await _repository.loadActive();
      if (asset != null) await _loader.load(asset);
      _active = asset;
      _startupFailure = null;
    } on Object {
      _active = null;
      _startupFailure = '已保存的自定义字体无法加载，请恢复默认字体后重新导入。';
    } finally {
      _initialized = true;
      _setBusy(false);
    }
  }

  Future<CustomFontImportOutcome> importFromFile() async {
    if (_busy) return CustomFontImportOutcome.cancelled;
    _setBusy(true);
    try {
      final asset = await _repository.pick();
      if (asset == null) return CustomFontImportOutcome.cancelled;
      await _loader.load(asset);
      await _repository.saveActive(asset);
      _active = asset;
      _startupFailure = null;
      notifyListeners();
      return CustomFontImportOutcome.imported;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> restoreDefault() async {
    if (_busy) return;
    _setBusy(true);
    try {
      await _repository.clearActive();
      _active = null;
      _startupFailure = null;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}
