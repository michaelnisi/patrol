---
name: new-plugin
description: Vet a candidate conditions source and, if it holds up, add it as a new plugin next to Hyde. Use when asked to add a plugin, support a new provider or source, or find out whether data for a region can be fetched and turned into SurfEntry values.
---

# new-plugin

Takes a candidate source from "does this data exist?" to a pull request that adds a plugin for it. Vetting comes first and costs only a few fetches, so a poor source is rejected before any code is written.

This skill follows the normal workflow from CLAUDE.md and has no exception, unlike `check-scrapers`: vet, issue, plan mode with the user's sign-off, branch, implement, PR. Fetching public URLs to vet a source is read-only and needs no issue. A human merges.

The reference implementation is `Core/Sources/Hyde/`. Read it before writing anything: `Hyde.swift` (the plugin, its `Station` enum, `place`, `key`, `url`, `deferredRequest`, `decodeDeferred`), `Parser.swift` and `Report.swift` (the source's own vocabulary, kept internal), and `SurfEntry+Report.swift` (the failable mapping into the domain). The contract is `Core/Sources/ConditionsPlugin/`.

## 1. Vet the source

Produce a short report. It becomes the body of the issue, so write it for someone who has not seen the conversation. Stop and say so if any check fails.

1. **Fetch live data** with `curl` and take the newest timestamp per station from the data itself, never from registry or catalog metadata. Metadata is a snapshot of unknown age: a catalog can show last year's date next to a live reading.
2. **List stations that are dead or stale** and leave them out of the plugin's places. A station whose newest reading is older than `SurfEntry.maxCachedAge` yields nothing usable, and a silently stale place is filed under a key nothing refreshes.
3. **Licence and access.** Note the licence and whether a key or login is needed. If one is, stop and ask the user: the apps scrape their sources directly today, so a key would have to ship in the apps.
4. **Map every `SurfEntry` field.** Write a table from the source's fields to `wave.max`, `wave.middle`, `wave.period`, `wave.direction`, `wind.speed.gust`, `wind.speed.middle`, `wind.speed.current`, `wind.direction` and `date`, and name each gap. `Wave` and `Wind` are non-optional in `Core/Sources/DomainTypes/SurfEntry.swift`; if the source lacks wind and `wind` is still non-optional there, report that the plugin depends on the optional-wind change and stop.
5. **Units, direction and missing values.** Read the source's units (a units row, a header, documentation) and compare with what the code expects: speeds are metres per second, because `Double.knots()` converts from that. Settle whether a direction is where something comes *from* or goes *to*, noting that `Direction` is a 16-point cardinal, so degrees must be rounded. List every sentinel for a missing value (`NaN`, blank, `MM`, `999.9999`).
6. **One plain GET per place?** If so the plugin is `DeferredDownloadable`. If a reading needs several requests or a join, say so; the plugin then implements only `ConditionsPlugin`, and the plan must cover how it fetches.
7. **Save a trimmed live response** per place type. It becomes the test fixture.

Report: source, licence, access, the field table with gaps, units and direction convention, sentinels, live stations with their newest timestamps, dead stations, and the recommendation.

## 2. Issue, then plan mode

File the issue from the vetting report. Then enter plan mode and settle these with the user before any code:

- the plugin's name; the `pluginID` is `ink.codes.Patrol.plugin.<name>`, named for the source and used for routing, never as a cache key or session identifier
- the `Station`-style enum (one case per live station) and each `place`: `key` is stable identity, `name` is the label
- `region`, the centre and radius covering the stations
- the `Place.icon`
- how the gaps from the field table are handled; the domain never learns the source's vocabulary

## 3. Implement

Branch from the up-to-date `main`: `GH-<N>-add-<name>-plugin`.

1. **Scaffold the target** in `Core/Package.swift`: a `.library` product, a `.target` depending on `DomainTypes` and `ConditionsPlugin`, and a `.testTarget`, placed outside the `canImport(Darwin)` block. The target builds on Linux: guard `os.log` and `FoundationNetworking` the way `Hyde/Logger.swift` and `Hyde/Hyde.swift` do.
2. **Write the plugin** after `Hyde`. The source's vocabulary stays internal. Plugin responsibility is exactly two things, HTTP with a session handed to it and parsing; caching and freshness belong to the coordinator. Return conditions for the place that was asked about, because the coordinator checks. Throw `ConditionsFault.unknownPlace` for another plugin's place and `ConditionsFault.unexpectedMediaType` for the wrong media type. A missing label or field throws, so a changed page is never mistaken for a reading the provider left out; a part the provider intentionally leaves out is `ConditionsFault.unavailable`. Percent-encode query strings: an ERDDAP request with a raw `>=` returned HTTP 400.
3. **Fixtures and tests.** Offline, XCTest, fixtures as inline literals, as in `Core/Tests/HydeTests/ParserTests.swift`. Trim fixtures to what the parser reads. Cover place vending, stable keys, the mapping, units conversion, direction rounding, missing values, the unavailable case and a foreign place. The test name carries the why; there are no comments.
4. **Register the plugin** in the three coordinator setups: `Patrol/Conditions+Live.swift`, `PatrolWatchApp/Conditions+Live.swift` and `PatrolWidget/Conditions+Widget.swift` (each has `plugins: [Hyde()]`), and in the `check-scrapers` probe: the `plugins` array in `.claude/skills/check-scrapers/probe/Sources/probe/main.swift` and the product dependency in `probe/Package.swift`. The probe names saved pages `<place key>.html`, which is cosmetic for a non-HTML source.
5. **Hand off the Xcode linking.** Never edit `Patrol.xcodeproj/project.pbxproj`. End the work by telling the user to add the new library product to these four targets: `Patrol`, `Patrol Watch App`, `PatrolWidgetExtension` and `PatrolWidgetIOSExtension`. Say so in the PR.
6. **Update the docs.** Where `CLAUDE.md` and `README.md` list the plugins ("Hyde is the first"), add the new one; source-specific quirks stay in the plugin.

## 4. Verify

From `Core`:

```bash
swift test
xcrun swift-format format --in-place --configuration ../.swift-format --recursive Sources Tests
xcrun swift-format lint --configuration ../.swift-format --strict --recursive Sources Tests
```

Then run the probe as `check-scrapers` describes and confirm every place of the new plugin reports `healthy`. The apps cannot be built until the user has linked the product in Xcode.

## 5. Pull request

Commit with the `GH-<N> …` prefix, merge the base branch into the feature branch, push, and open a PR titled like the commit. The body opens with `Closes #<N>`, then the as-built mapping, the vetting report, the stations left out and why, and the Xcode linking the user still has to do.

## Stop conditions

- Never merge, never push to `main`, never close an issue by hand.
- A source that fails vetting ends the run with the report: no issue, no branch, no PR.
- A source needing a key or login is the user's decision, never the skill's.
