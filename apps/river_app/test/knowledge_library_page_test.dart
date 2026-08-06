import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/knowledge/knowledge_library_page.dart';
import 'package:river_app/knowledge/notion_workspace.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_platform/river_platform.dart';

import '../test_support/article_reader_fakes.dart';

void main() {
  testWidgets('responsive library shows searchable detail and exports Markdown',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MemoryKnowledgeRepository();
    final files = _Files();
    final external = FakeExternalUriGateway();
    addTearDown(repository.close);
    await repository.saveItem(_item());

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeLibraryPage(
          repository: repository,
          files: files,
          externalUri: external,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('知识标题'), findsNWidgets(2));

    await tester.tap(find.text('导出 Markdown'));
    await tester.pumpAndSettle();
    expect(files.bundles, hasLength(1));
    expect(files.bundles.single.markdownFiles, hasLength(1));
    expect(find.text('Markdown 已导出'), findsOneWidget);

    await tester.tap(find.text('打开原文'));
    await tester.pump();
    expect(external.lastUri, Uri.parse('https://example.test/article'));

    await tester.drag(find.byType(ListView).last, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('高亮'), findsOneWidget);
    expect(find.textContaining('决定性内容'), findsOneWidget);
    expect(find.text('产品笔记'), findsWidgets);

    await tester.enterText(find.byType(SearchBar), '不存在');
    await tester.pump();
    expect(find.text('没有匹配内容'), findsWidgets);
  });

  testWidgets('Notion authorization selects a target without exposing tokens',
      (tester) async {
    final workspace = _Workspace(disconnected: true);
    addTearDown(workspace.close);
    await tester.pumpWidget(
      MaterialApp(home: NotionWorkspacePage(experience: workspace)),
    );
    await tester.pumpAndSettle();

    expect(find.text('连接你的 Notion 工作区'), findsOneWidget);
    await tester.tap(find.text('开始安全授权'));
    await tester.pumpAndSettle();
    expect(find.text('请在浏览器完成 Notion 授权'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'one-time-code');
    await tester.pump();
    await tester.tap(find.text('完成连接'));
    await tester.pumpAndSettle();

    expect(find.text('River Test Workspace'), findsOneWidget);
    expect(find.text('Research'), findsOneWidget);
    expect(find.textContaining('secret-access'), findsNothing);
    await tester.tap(find.text('Research'));
    await tester.pump();
    expect(workspace.state.selectedTarget?.title, 'Research');
  });

  testWidgets('failed Notion export has an explicit retry and then opens page',
      (tester) async {
    final repository = MemoryKnowledgeRepository();
    final workspace = _Workspace();
    final manager = _ExportManager();
    final external = FakeExternalUriGateway();
    addTearDown(repository.close);
    addTearDown(workspace.close);
    addTearDown(manager.close);
    final item = await repository.saveItem(_item());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KnowledgeDetailPane(
            item: item,
            repository: repository,
            files: _Files(),
            externalUri: external,
            exportManager: manager,
            notionWorkspace: workspace,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('保存到 Notion'), findsOneWidget);
    await tester.tap(find.text('保存到 Notion'));
    await tester.pump();
    expect(find.text('同步失败，本地知识不受影响'), findsOneWidget);
    expect(find.text('当前离线'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(find.text('已同步，可安全重复更新'), findsOneWidget);
    expect(find.text('打开 Notion 页面'), findsOneWidget);

    await tester.tap(find.text('打开 Notion 页面'));
    await tester.pump();
    expect(external.lastUri, Uri.parse('https://notion.so/page-1'));
  });

  testWidgets('IMA interop is explicit user-assisted sharing and public entry',
      (tester) async {
    final repository = MemoryKnowledgeRepository();
    final transfer = _ImaTransfer();
    final external = FakeExternalUriGateway();
    addTearDown(repository.close);
    final item = await repository.saveItem(_item());
    final interop = ImaPortableInterop(
      transfer: transfer,
      externalUri: external,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KnowledgeDetailPane(
            item: item,
            repository: repository,
            files: _Files(),
            externalUri: external,
            imaInterop: interop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('发送到 ima'));
    await tester.pumpAndSettle();
    expect(find.text('仅使用系统分享、标准文件和 ima 公共入口'), findsOneWidget);
    await tester.tap(find.text('通过系统分享发送文件'));
    await tester.pumpAndSettle();
    expect(transfer.shared, isNotNull);
    expect(transfer.shared!.mediaType, 'text/markdown');
    expect(find.textContaining('文件已交给系统分享'), findsOneWidget);

    await tester.tap(find.text('发送到 ima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开 ima'));
    await tester.pumpAndSettle();
    expect(external.lastUri, Uri.parse('https://ima.qq.com/'));
  });
}

final class _Files implements KnowledgeMarkdownFileGateway {
  final List<KnowledgeMarkdownExportBundle> bundles =
      <KnowledgeMarkdownExportBundle>[];

  @override
  Future<bool> save(KnowledgeMarkdownExportBundle bundle) async {
    bundles.add(bundle);
    return true;
  }
}

final class _ImaTransfer implements ImaPortableTransferGateway {
  ImaPortablePackage? shared;

  @override
  Future<ImaPortableOutcome> save(ImaPortablePackage package) async =>
      ImaPortableOutcome.completed;

  @override
  Future<ImaPortableOutcome> share(
    ImaPortablePackage package, {
    ShareAnchor? anchor,
  }) async {
    shared = package;
    return ImaPortableOutcome.completed;
  }
}

final class _Workspace implements NotionWorkspaceExperience {
  _Workspace({bool disconnected = false})
      : _state = disconnected
            ? const NotionWorkspaceState(
                phase: NotionWorkspacePhase.disconnected,
              )
            : NotionWorkspaceState(
                phase: NotionWorkspacePhase.connected,
                authorization: _authorization(),
                targets: <NotionTarget>[_target()],
                selectedTarget: _target(),
              );

  final StreamController<NotionWorkspaceState> _states =
      StreamController<NotionWorkspaceState>.broadcast(sync: true);
  NotionWorkspaceState _state;

  @override
  NotionWorkspaceState get state => _state;

  @override
  Stream<NotionWorkspaceState> get states => _states.stream;

  @override
  Future<void> load() async {
    _states.add(_state);
  }

  @override
  Future<void> beginAuthorization() async {
    _emit(
      NotionWorkspaceState(
        phase: NotionWorkspacePhase.authorizing,
        pendingFlow: NotionOAuthFlow(
          flowId: 'flow-1',
          authorizationUri: Uri.parse('https://notion.test/authorize'),
          expiresAt: DateTime.utc(2026, 7, 30),
        ),
      ),
    );
  }

  @override
  Future<void> completeAuthorization(String completionCodeOrRedirect) async {
    expect(completionCodeOrRedirect, 'one-time-code');
    _emit(
      NotionWorkspaceState(
        phase: NotionWorkspacePhase.connected,
        authorization: _authorization(),
        targets: <NotionTarget>[_target()],
      ),
    );
  }

  @override
  Future<void> refreshTargets({String? query}) async {
    _emit(
      NotionWorkspaceState(
        phase: NotionWorkspacePhase.connected,
        authorization: _authorization(),
        targets: <NotionTarget>[_target()],
        selectedTarget: _state.selectedTarget,
      ),
    );
  }

  @override
  Future<void> selectTarget(NotionTarget target) async {
    _emit(
      NotionWorkspaceState(
        phase: NotionWorkspacePhase.connected,
        authorization: _authorization(),
        targets: <NotionTarget>[_target()],
        selectedTarget: target,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    _emit(
      const NotionWorkspaceState(
        phase: NotionWorkspacePhase.disconnected,
      ),
    );
  }

  @override
  Future<void> close() => _states.close();

  void _emit(NotionWorkspaceState state) {
    _state = state;
    _states.add(state);
  }
}

final class _ExportManager implements KnowledgeExportManager {
  final StreamController<KnowledgeExportState> _states =
      StreamController<KnowledgeExportState>.broadcast(sync: true);
  KnowledgeExportState? _state;

  @override
  Stream<KnowledgeExportState> watch(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async* {
    yield _state ??
        KnowledgeExportState(
          target: target,
          operation: operation,
          phase: KnowledgeExportPhase.notQueued,
        );
    yield* _states.stream;
  }

  @override
  Future<KnowledgeExportState> status(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async =>
      _state ??
      KnowledgeExportState(
        target: target,
        operation: operation,
        phase: KnowledgeExportPhase.notQueued,
      );

  @override
  Future<void> enqueueUpsert(KnowledgeExportTarget target) async {
    _emit(
      KnowledgeExportState(
        target: target,
        operation: KnowledgeExportOperation.upsert,
        phase: KnowledgeExportPhase.failed,
        failureCode: 'offline',
      ),
    );
  }

  @override
  Future<void> retry(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async {
    _emit(
      KnowledgeExportState(
        target: target,
        operation: operation,
        phase: KnowledgeExportPhase.succeeded,
        externalUrl: Uri.parse('https://notion.so/page-1'),
      ),
    );
  }

  @override
  Future<void> enqueueDelete(KnowledgeExportTarget target) async {}

  Future<void> close() => _states.close();

  void _emit(KnowledgeExportState state) {
    _state = state;
    _states.add(state);
  }
}

NotionAuthorization _authorization() => NotionAuthorization(
      accessToken: OpaqueNotionToken('secret-access'),
      refreshToken: OpaqueNotionToken('secret-refresh'),
      botId: 'bot-1',
      workspaceId: 'workspace-1',
      workspaceName: 'River Test Workspace',
    );

NotionTarget _target() => NotionTarget(
      kind: NotionTargetKind.dataSource,
      id: 'data-source-1',
      title: 'Research',
    );

KnowledgeItem _item() => KnowledgeItem(
      id: 'knowledge-1',
      source: KnowledgeSourceReference(
        kind: KnowledgeSourceKind.article,
        sourceId: 'article-1',
        originalUrl: Uri.parse('https://example.test/article'),
        sourceTitle: 'Example Feed',
        author: 'River Author',
      ),
      title: '知识标题',
      markdown: '# 知识标题\n\n正文',
      sanitizedHtml: '<h1>知识标题</h1><p>正文</p>',
      excerpts: <KnowledgeExcerpt>[
        KnowledgeExcerpt(quote: '决定性内容', note: '产品笔记'),
      ],
      notes: const <String>['产品笔记'],
      tags: const <String>['RSS'],
      contentHash: 'sha256:${'a' * 64}',
      savedAt: DateTime.utc(2026, 7, 29),
      updatedAt: DateTime.utc(2026, 7, 29),
    );
