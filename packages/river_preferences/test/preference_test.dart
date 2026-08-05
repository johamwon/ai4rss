import 'dart:math';

import 'package:river_domain/river_domain.dart';
import 'package:river_preferences/river_preferences.dart';
import 'package:test/test.dart';

void main() {
  test('signal weights keep every click weaker than intentional evidence', () {
    final random = Random(42);
    final now = DateTime.utc(2026, 7, 30);
    final click =
        readingSignalWeight(_event('open', ReadingEventType.open, now));

    for (var sample = 0; sample < 1000; sample += 1) {
      final active = readingSignalWeight(
        _event(
          'active-$sample',
          ReadingEventType.activeRead,
          now,
          activeSeconds: random.nextInt(86400) + 1,
        ),
      );
      final completed = readingSignalWeight(
        _event(
          'completed-$sample',
          ReadingEventType.completed,
          now,
          completionRatio: (random.nextInt(1000) + 1) / 1000,
        ),
      );
      final starred = readingSignalWeight(
        _event('starred-$sample', ReadingEventType.starred, now),
      );
      final saved = readingSignalWeight(
        _event('saved-$sample', ReadingEventType.savedToKnowledge, now),
      );
      final negative = readingSignalWeight(
        _event('negative-$sample', ReadingEventType.notInterested, now),
      );

      expect(click, lessThan(active));
      expect(click, lessThan(completed));
      expect(click, lessThan(starred));
      expect(click, lessThan(saved));
      expect(negative.abs(), greaterThan(saved));
    }
  });

  test('time decay has a stable half-life and rejects future evidence', () {
    final now = DateTime.utc(2026, 7, 30, 12);

    expect(
      decayWeight(
        weight: 2,
        occurredAt: now.subtract(const Duration(days: 30)),
        now: now,
      ),
      closeTo(1, 1e-12),
    );
    expect(
      decayWeight(
        weight: -4,
        occurredAt: now.subtract(const Duration(days: 60)),
        now: now,
      ),
      closeTo(-1, 1e-12),
    );
    expect(
      () => decayWeight(
        weight: 1,
        occurredAt: now.add(const Duration(microseconds: 1)),
        now: now,
      ),
      throwsFormatException,
    );
    expect(
      () => decayWeight(
        weight: 1,
        occurredAt: now,
        now: now,
        halfLifeDays: 0,
      ),
      throwsFormatException,
    );
  });

  test('simulated session builds bounded source and topic profiles', () {
    final now = DateTime.utc(2026, 7, 30, 12);
    final model = LocalPreferenceProfileModel();
    final open = PreferenceEvidence(
      event: _event('open-tech', ReadingEventType.open, now),
      sourceId: 'source-tech',
      topics: const <String>[' Flutter ', 'DART', 'flutter'],
    );
    final profile = model.build(
      now: now,
      evidence: <PreferenceEvidence>[
        open,
        open,
        PreferenceEvidence(
          event: _event(
            'active-tech',
            ReadingEventType.activeRead,
            now,
            activeSeconds: 120,
          ),
          sourceId: 'source-tech',
          topics: const <String>['flutter', 'dart'],
        ),
        PreferenceEvidence(
          event: _event('star-tech', ReadingEventType.starred, now),
          sourceId: 'source-tech',
          topics: const <String>['flutter'],
        ),
        PreferenceEvidence(
          event: _event(
            'negative-noise',
            ReadingEventType.notInterested,
            now,
          ),
          sourceId: 'source-noise',
          topics: const <String>['gossip'],
        ),
      ],
    );

    expect(profile.modelVersion, preferenceProfileModelVersion);
    expect(profile.modelId, 'river.preference-profile/1');
    expect(profile.generatedAt, now);
    expect(profile.evidenceCount, 4);
    expect(profile.sourceScores.keys, <String>[
      'source-noise',
      'source-tech',
    ]);
    expect(profile.sourceScore('source-tech'), closeTo(3.7, 1e-12));
    expect(profile.sourceScore('source-noise'), -4);
    expect(profile.topicScore('FLUTTER'), closeTo(3.1, 1e-12));
    expect(profile.topicScore('dart'), closeTo(0.6, 1e-12));
    expect(profile.topicScore('gossip'), -4);
    expect(
      profile.topicScore('flutter') + profile.topicScore('dart'),
      closeTo(profile.sourceScore('source-tech'), 1e-12),
    );
  });

  test('repeated opens for one article stay one weak contribution', () {
    final now = DateTime.utc(2026, 7, 30);
    final profile = const LocalPreferenceProfileModel().build(
      now: now,
      evidence: <PreferenceEvidence>[
        for (var index = 0; index < 100; index += 1)
          PreferenceEvidence(
            event: ReadingEvent(
              eventId: 'open-$index',
              articleId: 'same-article',
              type: ReadingEventType.open,
              occurredAt: now,
            ),
            sourceId: 'clicked-source',
          ),
        PreferenceEvidence(
          event: _event('star', ReadingEventType.starred, now),
          sourceId: 'intentional-source',
        ),
      ],
    );

    expect(profile.evidenceCount, 101);
    expect(profile.sourceScore('clicked-source'), 0.2);
    expect(
      profile.sourceScore('clicked-source'),
      lessThan(profile.sourceScore('intentional-source')),
    );

    final reopened = const LocalPreferenceProfileModel().build(
      now: now,
      evidence: <PreferenceEvidence>[
        PreferenceEvidence(
          event: ReadingEvent(
            eventId: 'old-open',
            articleId: 'reopened-article',
            type: ReadingEventType.open,
            occurredAt: now.subtract(const Duration(days: 30)),
          ),
          sourceId: 'old-source',
        ),
        PreferenceEvidence(
          event: ReadingEvent(
            eventId: 'new-open',
            articleId: 'reopened-article',
            type: ReadingEventType.open,
            occurredAt: now,
          ),
          sourceId: 'new-source',
        ),
      ],
    );
    expect(reopened.sourceScore('old-source'), 0);
    expect(reopened.sourceScore('new-source'), 0.2);
  });

  test('identity conflicts and unsupported model versions fail closed', () {
    final now = DateTime.utc(2026, 7, 30);
    final event = _event('same-id', ReadingEventType.open, now);

    expect(
      () => const LocalPreferenceProfileModel().build(
        now: now,
        evidence: <PreferenceEvidence>[
          PreferenceEvidence(event: event, sourceId: 'source-a'),
          PreferenceEvidence(event: event, sourceId: 'source-b'),
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => const LocalPreferenceProfileModel(
        config: PreferenceModelConfig(modelVersion: 2),
      ).build(now: now, evidence: const <PreferenceEvidence>[]),
      throwsFormatException,
    );
  });

  test('explicit controls adjust a rebuilt profile without mutating evidence',
      () {
    final now = DateTime.utc(2026, 8, 3);
    final original = const LocalPreferenceProfileModel().build(
      evidence: <PreferenceEvidence>[
        PreferenceEvidence(
          event: ReadingEvent(
            eventId: 'event-1',
            articleId: 'article-1',
            type: ReadingEventType.open,
            occurredAt: now,
          ),
          sourceId: 'feed-1',
          topics: const <String>['flutter'],
        ),
      ],
      now: now,
    );
    final controlled = applyReadingPreferenceControls(
      profile: original,
      controls: const ReadingPreferenceControls(
        sourceScoreAdjustments: <String, double>{'feed-1': 2},
        topicScoreAdjustments: <String, double>{'flutter': -2},
      ),
    );

    expect(original.sourceScore('feed-1'), closeTo(0.2, 1e-12));
    expect(controlled.sourceScore('feed-1'), closeTo(2.2, 1e-12));
    expect(controlled.topicScore('flutter'), closeTo(-1.8, 1e-12));
    expect(controlled.evidenceCount, original.evidenceCount);
    expect(controlled.modelId, original.modelId);
  });
}

ReadingEvent _event(
  String id,
  ReadingEventType type,
  DateTime at, {
  int activeSeconds = 0,
  double completionRatio = 0,
}) =>
    ReadingEvent(
      eventId: id,
      articleId: 'article-$id',
      type: type,
      occurredAt: at,
      activeSeconds: activeSeconds,
      completionRatio: completionRatio,
    );
