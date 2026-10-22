import { expect, test } from '@playwright/test';
import { DevicesPage } from './pages/devices.page';

/** Resets seeded data and opens the web console before each device test. */
test.beforeEach(async ({ page, request }) => {
  const response = await request.post('/__admin/reset');
  expect(response.ok()).toBeTruthy();
  await page.goto('/');
});

/** Verifies the first page contains 25 devices and reports all 480 devices. */
test('[DEV-01] First page shows 25 devices and the total', async ({ page }) => {
  const devices = new DevicesPage(page);
  await devices.open();
  await devices.assertFirstPageShowsDeviceCountAndTotal(25, 480);
});

/** Verifies Load more appends the next page without changing the total count. */
test('[DEV-02] Load more fetches the next page', async ({ page }) => {
  const devices = new DevicesPage(page);
  await devices.open();
  await devices.assertLoadedDeviceCount(25);

  await devices.loadMore();
  await devices.assertLoadedDeviceCount(50);
  await expect(devices.resultCount).toHaveText('480 devices');
});

/** Verifies Load more disappears when all devices, including the final partial page, are loaded. */
test('[DEV-03] Last page hides Load more', async ({ page }) => {
  const devices = new DevicesPage(page);
  await devices.open();

  for (let loadedCount = 25; loadedCount < 480; loadedCount += 25) {
    await devices.loadMore();
    await devices.assertLoadedDeviceCount(Math.min(loadedCount + 25, 480));
  }

  await devices.assertLoadMoreHidden();
});

/** Verifies searching with part of a serial number returns its matching device. */
test('[DEV-05] Search by partial serial number', async ({ page }) => {
  const devices = new DevicesPage(page);
  await devices.open();

  const serial = await devices.rows.first().locator('td').first().innerText();
  const fragment = serial.slice(2, -1);
  await devices.searchFor(fragment);
  await devices.assertSearchResultsContainSerialFragment(fragment, 1);
});

/** Verifies a lowercase serial search matches the seeded uppercase serial. */
test('[DEV-06] Search is case-insensitive', async ({ page }) => {
  const devices = new DevicesPage(page);
  await devices.open();

  const serial = await devices.rows.first().locator('td').first().innerText();
  await devices.searchFor(serial.toLowerCase());
  await devices.assertSearchResultsContainSerialFragment(serial.toLowerCase(), 1);
});

/** Verifies an unmatched search displays the empty state instead of device rows. */
test('[DEV-08] Search with no matches shows empty state', async ({ page }) => {
  const devices = new DevicesPage(page);
  await devices.open();
  await devices.searchFor('no-device-matches-this-query');
  await devices.assertNoSearchResults('No devices found');
});

/** Verifies every supported device status filter returns only devices with that status. */
test('[DEV-10] Status filter works for each status', async ({ page }) => {
  const devices = new DevicesPage(page);
  await devices.open();

  for (const status of ['online', 'offline', 'updating', 'failed']) {
    await devices.filterByStatus(status);
    await devices.assertRowsHaveStatus(status);
  }
});

/** Verifies status filtering, serial search, and opening matching device details. */
test('filters devices and opens the selected device details', async ({ page }) => {
  const devices = new DevicesPage(page);
  await devices.open();
  await devices.filterByStatus('online');
  await expect(devices.rows.first()).toBeVisible();

  const row = devices.rows.first();
  await expect(row.locator('td').last()).toContainText('Online');
  const serial = await row.locator('td').first().innerText();

  await devices.searchFor(serial);
  await expect(devices.rows).toHaveCount(1);
  await devices.openDevice();

  await expect(devices.detailDialog).toBeVisible();
  await expect(devices.detailSerial).toHaveText(serial);
  await expect(devices.detailStatus).toHaveText('Online');
});
