---
name: concurrency-check
description: Review Swift concurrency for data-race safety. Use when working on async/await, actors, tasks, Sendable, Swift 6 migration, data races, or concurrency-related warnings.
argument-hint: "[file or description]"
---

# Swift Concurrency Check

**Target**: $ARGUMENTS

## Overview

Expert guidance on Swift Concurrency for iOS/Swift projects: async/await, actors, tasks, Sendable, and Swift 6 migration. Use when implementing or reviewing code that involves concurrency, or when resolving data-race or isolation diagnostics.

**Source**: Content adapted from [Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) (Antoine van der Lee).

## Agent Behavior Contract

1. **Discover project settings** - Check `Package.swift` or `.pbxproj` for Swift language mode (5.x vs 6), strict concurrency level, and default actor isolation before giving migration-sensitive advice.
2. **Identify isolation first** - Before proposing fixes, identify the boundary: `@MainActor`, custom actor, actor instance isolation, or nonisolated.
3. **No blanket @MainActor** - Do not recommend `@MainActor` as a generic fix; justify why main-actor isolation is correct.
4. **Prefer structured concurrency** - Prefer child tasks and task groups over unstructured `Task`; use `Task.detached` only with a documented reason.
5. **Unsafe escapes** - If recommending `@preconcurrency`, `@unchecked Sendable`, or `nonisolated(unsafe)`, require a documented safety invariant and a follow-up to remove or migrate.
6. **Migration** - Prefer minimal blast radius (small, reviewable changes) and add verification steps.

## Project Conventions

Services must have explicit isolation per project rules:
- **@MainActor**: For UI, SwiftData `ModelContext`, ViewModels
- **nonisolated + @concurrent**: For stateless/immutable services, CPU-intensive work
- **Dedicated actors**: For managing mutable state

## Quick Decision Tree

1. **Starting with async code?** → async/await basics; for parallel work use `async let` or task groups.
2. **Protecting shared mutable state?** → Class-based state: actors or `@MainActor`. Thread-safe value passing: `Sendable` conformance.
3. **Managing async operations?** → Structured work: `Task`, child tasks, cancellation. Streaming: `AsyncSequence` / `AsyncStream`.
4. **Legacy frameworks?** → Core Data: DAO pattern, `NSManagedObjectID`, isolation.
5. **Performance or debugging?** → Slow async code: profiling, suspension points. Tests: async test APIs.
6. **Threading behavior?** → Understand thread vs task, suspension points, isolation domains.
7. **Memory / tasks?** → Retain cycles in tasks, cancellation, `[weak self]` where appropriate.

## Triage-First Playbook (Common Errors)

| Symptom / Warning | First step | Then |
|-------------------|------------|------|
| "Sending value of non-Sendable type ... risks data races" | Find where the value crosses an isolation boundary. | Apply Sendable/isolation guidance. |
| "Main actor-isolated ... cannot be used from a nonisolated context" | Decide if it really belongs on `@MainActor`. | Use actors/global actors, `nonisolated`, or isolated parameters. |
| SwiftLint concurrency warnings | Use concurrency lint rules; avoid dummy `await` as "fix". | Prefer real fix or narrow suppression. |
| XCTest async / "wait(...) is unavailable from async" | Use async test APIs. | `await fulfillment(of:)` or Swift Testing patterns. |

## Core Patterns Reference

### When to Use Each Concurrency Tool

| Tool | Use for |
|------|--------|
| **async/await** | Single async operations, making sync code async. |
| **async let** | Fixed number of independent async operations in parallel. |
| **Task** | Fire-and-forget, bridging sync to async. |
| **Task group** | Dynamic number of parallel operations. |
| **Actor** | Shared mutable state, access from multiple contexts. |
| **@MainActor** | ViewModels, UI, SwiftData `ModelContext`. |

### Example: SpecSwift-style service

```swift
@MainActor
final class DatabaseService { ... }

nonisolated struct PhotoProcessor {
    @concurrent
    func process(data: Data) async -> ProcessedPhoto? { ... }
}
```

## Swift 6 Migration Quick Guide

- **Strict concurrency** is on by default; **data-race safety** at compile time.
- **Sendable** is required across isolation boundaries.
- **Isolation** is checked at all async boundaries.

Migrate in small steps: enable targeted strict concurrency, fix diagnostics, then move to complete.

## Verification Checklist

- [ ] Build settings (default isolation, strict concurrency) are known and consistent with advice.
- [ ] Tests run, including concurrency-sensitive tests.
- [ ] If performance-related, verify with Instruments.
- [ ] If lifetime-related, verify deinit and cancellation behavior.
- [ ] New services have explicit isolation (`@MainActor`, `nonisolated`, or `actor`) per project rules.
