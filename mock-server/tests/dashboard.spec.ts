import { expect, test, type APIRequestContext } from '@playwright/test';
import { DashboardPage } from './pages/dashboard.page';

/** Sets the mock API to a named backend scenario for a test. */
async function setScenario(request: APIRequestContext, mode: string): Promise<void> {
  const response = await request.post('/__admin/scenario', { data: { mode } });
  expect(response.ok()).toBeTruthy();
}

/** Restores seeded standard data after scenario-based tests. */
async function resetBackend(request: APIRequestContext): Promise<void> {
  const response = await request.post('/__admin/reset');
  expect(response.ok()).toBeTruthy();
}

/** Resets backend state before each dashboard test. */
test.beforeEach(async ({ page, request }) => {
  await resetBackend(request);
});

/** Verifies the dashboard shows the expected fleet total and online percentage. */
test('[DASH-01] Fleet total is shown for the whole fleet', async ({ page }) => {
  const dashboard = new DashboardPage(page);

  await page.goto('/');
  await dashboard.open();
  await dashboard.assertFleetSummary('1,400,000');
});

/** Verifies the four device-status tiles sum to the fleet total. */
test('[DASH-02] Status counts reconcile to total', async ({ page }) => {
  const dashboard = new DashboardPage(page);

  await page.goto('/');
  await dashboard.open();
  await dashboard.assertStatusCountsReconcileToTotal();
});

/** Verifies the displayed online percentage matches the online and total tiles. */
test('[DASH-03] Online percentage is consistent with tiles', async ({ page }) => {
  const dashboard = new DashboardPage(page);

  await page.goto('/');
  await dashboard.open();
  await dashboard.assertOnlinePercentageIsConsistentWithTiles();
});

/** Verifies the server-error banner and Retry recovery flow. */
test('[DASH-07] Server error shows banner and Retry recovers', async ({ page, request }) => {
  await setScenario(request, 'error');

  const dashboard = new DashboardPage(page);
  try {
    await page.goto('/');
    await dashboard.assertServerErrorIsVisible();

    await setScenario(request, 'standard');

    await dashboard.retry.click();
    await dashboard.assertRecovered('1,400,000');
  } finally {
    await resetBackend(request);
  }
});

/** Verifies the loading indicator remains visible while the backend responds slowly. */
test('[DASH-08] Slow backend shows loading state', async ({ page, request }) => {
  await setScenario(request, 'slow');

  const dashboard = new DashboardPage(page);
  try {
    await page.goto('/');
    await dashboard.assertLoadingCompletes('1,400,000');
  } finally {
    await resetBackend(request);
  }
});

/** Verifies an empty fleet renders zero-valued tiles and a safe percentage. */
test('[DASH-09] Empty fleet renders zeros safely', async ({ page, request }) => {
  await setScenario(request, 'empty');

  const dashboard = new DashboardPage(page);
  try {
    await page.goto('/');
    await dashboard.assertEmptyFleet({
      totalDevices: '0',
      online: '0',
      offline: '0',
      updating: '0',
      failed: '0',
      activeDeployments: '0',
    }, '0.0% of the fleet is online');
  } finally {
    await resetBackend(request);
  }
});
