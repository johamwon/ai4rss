import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_app/app/article_reader.dart';
import 'package:river_app/knowledge/knowledge_library_page.dart';
import 'package:river_app/knowledge/notion_workspace.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_platform/river_platform.dart';

import '../test_support/article_reader_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('article highlight becomes local knowledge and syncs to Notion',
      (tester) async {
    const selected = 'knowledge journey highlight';
    const body = 'Start. $selected. End.';
    final details = StreamController<FeedArticleDetailRecord?>();
    final annotations = FakeArticleAnnotationRepository();
    final knowledge = MemoryKnowledgeRepository();
    final extraction = Completer<ExtractionResult>();
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => details.stream,
      extract: (_) => extraction.future,
      annotations: annotations,
      ids: SequentialReaderIds(),
      knowledge: knowledge,
    );
    final workspace = _Workspace();
    final manager = _Manager();
    addTearDown(() async {
      controller.dispose();
      await details.close();
      await annotations.close();
      await knowledge.close();
      await workspace.close();
      await manager.close();
    });

    await tester.pumpWidget(
      MaterialApp(home: ArticleReaderScreen(controller: controller)),
    );
    details.add(
      FeedArticleDetailRecord(
        id: 'article-1',
        feedId: 'feed-1',
        feedTitle: 'Journey Feed',
        canonicalUrl: Uri.parse('https://example.test/journey'),
        title: 'Journey Article',
        read: false,
        starred: false,
        readLater: false,
        scrollDepth: 0,
        activeReadSeconds: 0,
        summary: body,
      ),
    );
    await tester.pump();
    await tester.pump();

    final document = tester.state<ArticleDocumentViewState>(
      find.byType(ArticleDocumentView),
    );
    final start = body.indexOf(selected);
    document.selectRange(start, start + selected.length);
    await tester.pump();
    await tester.tap(find.text('高亮并添加笔记'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'journey note');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存到知识库'));
    await tester.pumpAndSettle();

    expect(knowledge.items, hasLength(1));
    expect(knowledge.items.single.excerpts.single.quote, selected);

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeLibraryPage(
          repository: knowledge,
          files: _Files(),
          externalUri: _ExternalUri(),
          exportManager: manager,
          notionWorkspace: workspace,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Journey Article'));
    await tester.pumpAndSettle();
    expect(find.text('Journey Article'), findsWidgets);

    await tester.tap(find.text('保存到 Notion'));
    await tester.pump();
    expect(manager.targets, hasLength(1));
    expect(manager.targets.single.knowledgeItemId, knowledge.items.single.id);
    expect(manager.targets.single.destinationId, 'dataSource:research');
    expect(find.text('已同步，可安全重复更新'), findsOneWidget);
  });
}

final class _Workspace implements NotionWorkspaceExperience {
  _Workspace()
      : _state = NotionWorkspaceState(
          phase: NotionWorkspacePhase.connected,
          authorization: NotionAuthorization(
            accessToken: OpaqueNotionToken('access-token'),
            refreshToken: OpaqueNotionToken('refresh-token'),
            botId: 'bot',
            workspaceId: 'workspace',
            workspaceName: 'Workspace',
          ),
          targets: <NotionTarget>[_target],
          selectedTarget: _target,
        );

  static final _target = NotionTarget(
    kind: NotionTargetKind.dataSource,
    id: 'research',
    title: 'Research',
  );
  final StreamController<NotionWorkspaceState> _states =
      StreamController<NotionWorkspaceState>.broadcast();
  final NotionWorkspaceState _state;

  @override
  NotionWorkspaceState get state => _state;

  @override
  Stream<NotionWorkspaceState> get states => _states.stream;

  @override
  Future<void> load() async {}

  @override
  Future<void> beginAuthorization() async {}

  @override
  Future<void> completeAuthorization(String completionCodeOrRedirect) async {}

  @override
  Future<void> refreshTargets({String? query}) async {}

  @override
  Future<void> selectTarget(NotionTarget target) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> close() => _states.close();
}

final class _Manager implements KnowledgeExportManager {
  final List<KnowledgeExportTarget> targets = <KnowledgeExportTarget>[];
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
    targets.add(target);
    _state = KnowledgeExportState(
      target: target,
      operation: KnowledgeExportOperation.upsert,
      phase: KnowledgeExportPhase.succeeded,
      externalUrl: Uri.parse('https://notion.so/journey'),
    );
    _states.add(_state!);
  }

  @override
  Future<void> enqueueDelete(KnowledgeExportTarget target) async {}

  @override
  Future<void> retry(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async {}

  Future<void> close() => _states.close();
}

final class _Files implements KnowledgeMarkdownFileGateway {
  @override
  Future<bool> save(KnowledgeMarkdownExportBundle bundle) async => true;
}

final class _ExternalUri implements ExternalUriGateway {
  @override
  Future<ExternalUriOpenOutcome> open(Uri uri) async =>
      ExternalUriOpenOutcome.opened;
}
