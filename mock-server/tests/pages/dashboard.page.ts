import { expect, type Locator } from '@playwright/test';
import { BasePage } from './base.page';

export interface DashboardTileValues {
  totalDevices: string;
  online: string;
  offline: string;
  updating: string;
  failed: string;
  activeDeployments: string;
}

export class DashboardPage extends BasePage {
  readonly screen = this.testId('dashboard.screen');
  readonly loading = this.testId('common.loading');
  readonly errorBanner = this.page.locator('#error');
  readonly errorMessage = this.testId('common.error');
  readonly retry = this.testId('common.retry');
  readonly totalDevices = this.testId('dashboard.total');
  readonly online = this.testId('dashboard.online');
  readonly offline = this.testId('dashboard.offline');
  readonly updating = this.testId('dashboard.updating');
  readonly failed = this.testId('dashboard.failed');
  readonly activeDeployments = this.testId('dashboard.activeDeployments');
  readonly onlinePercentage = this.testId('dashboard.onlinePercentage');

  /** Navigates to the dashboard and waits for it to appear. */
  async open(): Promise<void> {
    await this.openTab('dashboard', this.screen);
  }

  /**
   * Checks that the dashboard summary displays the expected total and percentage label.
   * @param {string} expectedTotal - Expected formatted fleet total, such as "1,400,000".
   */
  async assertFleetSummary(expectedTotal: string): Promise<void> {
    await expect(this.screen).toBeVisible();
    await expect(this.totalDevices).toHaveText(expectedTotal);
    await expect(this.onlinePercentage).toContainText('% of the fleet is online');
  }

  /**
   * Checks the expected text for any supplied fleet-summary tiles.
   * @param {Partial<DashboardTileValues>} expectedValues - Expected display text keyed by tile name.
   */
  async assertTileValues(expectedValues: Partial<DashboardTileValues>): Promise<void> {
    const tiles: Record<keyof DashboardTileValues, Locator> = {
      totalDevices: this.totalDevices,
      online: this.online,
      offline: this.offline,
      updating: this.updating,
      failed: this.failed,
      activeDeployments: this.activeDeployments,
    };
    const assertions: [keyof DashboardTileValues, string | undefined][] = [
      ['totalDevices', expectedValues.totalDevices],
      ['online', expectedValues.online],
      ['offline', expectedValues.offline],
      ['updating', expectedValues.updating],
      ['failed', expectedValues.failed],
      ['activeDeployments', expectedValues.activeDeployments],
    ];

    await Promise.all(assertions.flatMap(([tile, value]) =>
      value === undefined ? [] : [expect(tiles[tile]).toHaveText(value)]));
  }

  /** Confirms online, offline, updating, and failed counts equal the total fleet size. */
  async assertStatusCountsReconcileToTotal(): Promise<void> {
    const counts = await Promise.all([
      this.online,
      this.offline,
      this.updating,
      this.failed,
    ].map(async (locator) => Number((await locator.innerText()).replaceAll(',', ''))));
    const total = Number((await this.totalDevices.innerText()).replaceAll(',', ''));

    expect(counts.reduce((sum, count) => sum + count, 0)).toBe(total);
  }

  /** Confirms the displayed online percentage is calculated from the online and total tiles. */
  async assertOnlinePercentageIsConsistentWithTiles(): Promise<void> {
    const online = Number((await this.online.innerText()).replaceAll(',', ''));
    const total = Number((await this.totalDevices.innerText()).replaceAll(',', ''));
    const displayedPercentage = (await this.onlinePercentage.innerText()).match(/^([\d.]+)%/);

    expect(total).toBeGreaterThan(0);
    expect(displayedPercentage).not.toBeNull();
    expect(displayedPercentage?.[1]).toBe(((online / total) * 100).toFixed(1));
  }

  /** Checks the loading indicator, error banner styling/message, and Retry control. */
  async assertServerErrorIsVisible(): Promise<void> {
    await expect(this.loading).toBeHidden();
    await expect(this.errorBanner).toBeVisible();
    await expect(this.errorBanner).toHaveCSS('background-color', 'rgb(253, 232, 232)');
    await expect(this.errorMessage).toContainText('DCOTA service is unavailable');
    await expect(this.retry).toBeVisible();
  }

  /**
   * Confirms a retry completed successfully and displays the expected fleet total.
   * @param {string} expectedTotal - Expected formatted fleet total after recovery.
   */
  async assertRecovered(expectedTotal: string): Promise<void> {
    await expect(this.loading).toBeHidden();
    await expect(this.errorBanner).toBeHidden();
    await expect(this.screen).toBeVisible();
    await expect(this.totalDevices).toHaveText(expectedTotal);
    await expect(this.online).toBeVisible();
  }

  /**
   * Checks loading is shown during the request and hidden once the expected total appears.
   * @param {string} expectedTotal - Expected formatted fleet total once loading finishes.
   * @param {number} timeoutMs - Maximum time in milliseconds to wait for the total.
   */
  async assertLoadingCompletes(expectedTotal: string, timeoutMs = 5_000): Promise<void> {
    await expect(this.loading).toBeVisible();
    await expect(this.totalDevices).toHaveText(expectedTotal, { timeout: timeoutMs });
    await expect(this.loading).toBeHidden();
  }

  /**
   * Checks an empty fleet's expected tile values, percentage, and absence of an error.
   * @param {DashboardTileValues} expectedValues - Expected display text for each dashboard tile.
   * @param {string} expectedOnlinePercentage - Expected complete online-percentage label.
   */
  async assertEmptyFleet(expectedValues: DashboardTileValues, expectedOnlinePercentage: string): Promise<void> {
    await expect(this.screen).toBeVisible();
    await this.assertTileValues(expectedValues);
    await expect(this.onlinePercentage).toHaveText(expectedOnlinePercentage);
    await expect(this.errorBanner).toBeHidden();
  }
}
