# MockDCOTA Quality Engineering

MockDCOTA is a small iOS and web application that simulates a partner-store fleet managing digital content across a large device fleet. The repository focuses on UI automation, testability, and repeatable test data.

## Automated UI tests

| Suite | Framework | Coverage |
|---|---|---|
| Web console | Playwright + TypeScript | Dashboard totals, status reconciliation, percentage calculations, error and slow-backend states, empty fleet, device paging/search/filtering, deployment creation, duplicate-deployment validation, and cancellation |
| iOS app | XCUITest + Swift | Dashboard fleet-total smoke journey |

Both suites use page objects to keep UI interactions and assertions separate from test scenarios. The web console's `data-testid` values mirror the iOS accessibility identifiers in `Support/AccessibilityID.swift`, providing a consistent UI contract across platforms.

### Run Playwright tests

Requirements: Node.js 20 or later.

```bash
cd mock-server
npm ci
npx playwright install
npm test
```

Playwright starts the mock server automatically and runs against Chromium, Firefox, and WebKit. To run a focused suite:

```bash
npx playwright test tests/dashboard.spec.ts
npx playwright test tests/devices.spec.ts
npx playwright test tests/deployments.spec.ts
```

### Run XCUITest

Requirements: Xcode and an available iOS Simulator.

```bash
xcodebuild test \
  -project MockDCOTA.xcodeproj \
  -scheme MockDCOTA \
  -destination 'platform=iOS Simulator,name=<available simulator>'
```

The UI test target launches the app with onboarding skipped and the in-memory backend selected. Find available simulator names with:

```bash
xcrun simctl list devices available
```

## Application and testability

- The iOS app and web console provide a fleet dashboard, device search, content packages, and deployments.
- The zero-dependency Node server provides the web console and REST API at `http://localhost:8080`.
- The mock API exposes deterministic seed data and admin hooks for reset, empty/error/slow scenarios, and injected failures.
- App launch arguments support backend, scenario, progress, onboarding, and feature-flag configuration.
- The dashboard reports a 1.4-million-device fleet; the device table uses a seeded 480-device sample.

Start the server independently when exploring the web console or REST API:

```bash
node mock-server/server.js
```

The OpenAPI definition is in `mock-server/openapi.yaml`. Key business rules include device paging and filtering, valid deployment selection, duplicate active-deployment prevention, and cancellation of active deployments.

## CI

GitHub Actions runs the Playwright suite on pushes to `main`/`master` and pull requests targeting those branches. The workflow installs the dependencies and browser engines, runs tests in Chromium, Firefox, and WebKit, and uploads the HTML report as an artifact. The iOS workflow separately builds the app for Simulator; XCUITest is currently run locally using the command above.

## Project files

- `MockDCOTAUITests/` — XCUITest cases and iOS dashboard page object
- `mock-server/tests/` — Playwright specs and web page objects
- `mock-server/web/` — web console under test
- `Services/`, `ViewModels/`, `Models/` — iOS app layers
- `mock-server/openapi.yaml` — REST API contract
