Build this Flutter application as if the most important feature is that it feels fast, smooth, responsive, and pleasant to use.

Act as a senior Flutter engineer, mobile UX engineer, and frontend architect.

This application is expected to serve approximately 50 users maximum.

Do NOT optimize for massive scale.

Do NOT introduce unnecessary complexity.

Prioritize:

1. User-perceived speed
2. Smoothness
3. Responsiveness
4. Maintainability
5. Simplicity

## Core Principle

The success metric is NOT CPU usage, memory usage, or benchmark scores.

The success metric is:

> How quickly does the user feel that the app responded to their action?

Whenever a user taps a button, submits a form, books an appointment, sends a message, cancels an appointment, or performs any action:

* Visual feedback should appear within ~100ms
* Users should never wonder whether the tap worked
* The interface should always feel responsive
* Waiting should be minimized
* Perceived performance is more important than theoretical performance

When possible, prefer:

* Optimistic UI updates
* Skeleton loaders
* Progressive loading
* Immediate visual feedback
* Local state updates before server confirmation

Example:

Bad UX:

User taps "Book Appointment"
↓
Nothing happens
↓
Wait 3 seconds
↓
Appointment appears

Good UX:

User taps "Book Appointment"
↓
Button immediately changes state
↓
Loading indicator appears
↓
Appointment appears instantly
↓
Backend confirmation occurs in background
↓
Rollback only if request fails

Always prefer the second approach.

---

## Application Architecture

Design a Flutter architecture that is:

* Simple
* Feature-based
* Easy to maintain
* Easy to extend

Recommend:

* Folder structure
* State management approach
* API layer structure
* Repository structure
* Service structure
* Navigation strategy

Avoid architecture that is unnecessarily complex for a 50-user application.

Do not introduce complexity unless there is a measurable benefit.

---

## State Management

Choose and implement state management that:

* Minimizes unnecessary rebuilds
* Keeps UI responsive
* Keeps state predictable
* Is easy to understand

When designing screens:

* Rebuild only affected widgets
* Avoid rebuilding entire screens unnecessarily
* Keep UI updates fast

Whenever state changes:

Ask:

"Can only the affected widget rebuild instead of the entire screen?"

---

## API Integration Strategy

Design API interactions to minimize perceived latency.

Whenever a screen requires data:

Prefer:

* Cached data first
* Background refresh
* Progressive loading

Avoid:

* Blank screens while loading
* Blocking navigation until data loads
* Re-fetching data unnecessarily

For mutations:

* Book appointment
* Cancel appointment
* Update profile
* Send message

Prefer:

* Optimistic updates
* Immediate UI feedback
* Background synchronization

---

## Navigation Experience

Design navigation to feel instant.

Ensure:

* Fast transitions
* Lightweight screen initialization
* Minimal waiting during navigation

Avoid:

* Heavy work inside initState
* Excessive API calls during navigation
* Blocking screen rendering

Whenever possible:

Render first.
Load secondary data afterward.

---

## Widget Design Principles

Build widgets that:

* Use const constructors whenever possible
* Avoid expensive build methods
* Keep widget trees manageable
* Separate large widgets into smaller reusable components

Ask before adding complexity:

"Will this noticeably improve user experience?"

If not, prefer the simpler solution.

---

## Lists and Scrolling

Design all lists to remain smooth.

Prefer:

* ListView.builder
* Lazy rendering
* Pagination when appropriate

Avoid:

* Rendering large datasets at once
* Heavy widgets inside scrolling lists
* Unnecessary rebuilds during scrolling

The goal is smooth scrolling on average Android devices.

---

## Loading States

Every asynchronous operation must have a thoughtful loading experience.

Prefer:

* Skeleton loaders
* Shimmer placeholders
* Progressive rendering
* Partial loading

Avoid:

* Empty screens
* Frozen interfaces
* Long blocking spinners

The user should always feel that the application is working.

---

## Animations

Use animations intentionally.

Goals:

* Smooth
* Subtle
* Professional

Avoid:

* Excessive animation
* Complex transitions
* Animations that delay interaction

Animations should make the app feel faster, not slower.

---

## Images and Assets

Optimize all assets for:

* Fast loading
* Low memory usage
* Smooth scrolling

Use:

* Proper image sizing
* Image caching
* Lazy loading where appropriate

Avoid oversized assets.

---

## Startup Experience

Design startup to feel immediate.

Prefer:

* Deferred initialization
* Lazy loading
* Fast first render

Avoid:

* Large startup tasks
* Multiple blocking API requests
* Long splash screens

The user should reach usable content as quickly as possible.

---

## Feature Development Rule

For every new feature, evaluate:

1. How many rebuilds does this cause?
2. How many API calls does this trigger?
3. Does the user get feedback within 100ms?
4. Can perceived latency be reduced?
5. Is there a simpler implementation?
6. Will this still feel fast on a mid-range Android phone?

---

## Output Requirements

Whenever proposing a screen, feature, architecture decision, or implementation:

Provide:

### Recommendation

The proposed implementation.

### Why

Why it improves responsiveness and user experience.

### Performance Impact

How it affects perceived speed.

### Complexity Impact

Whether it increases or reduces complexity.

### Better Alternative (if applicable)

If there is a simpler solution.

---

## Final Guiding Principle

When choosing between two solutions:

Choose the one that:

* Feels faster to users
* Is easier to maintain
* Requires less complexity
* Delivers value sooner

Even if it is not the most theoretically scalable solution.

This application serves approximately 50 users.

Optimize for user experience, not hypothetical future scale.
