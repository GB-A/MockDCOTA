import { expect } from '@playwright/test';
import { BasePage } from './base.page';

export class DevicesPage extends BasePage {
  readonly screen = this.testId('devices.screen');
  readonly search = this.testId('devices.search');
  readonly statusFilter = this.testId('devices.statusFilter');
  readonly resultCount = this.testId('devices.resultCount');
  readonly rows = this.testId('devices.list').locator('tr');
  readonly loadMoreButton = this.testId('devices.loadMore');
  readonly emptyState = this.testId('common.empty');
  readonly detailDialog = this.testId('deviceDetail.screen');
  readonly detailSerial = this.testId('deviceDetail.serial');
  readonly detailStatus = this.testId('deviceDetail.status');

  /** Navigates to the devices screen and waits for it to appear. */
  async open(): Promise<void> {
    await this.openTab('devices', this.screen);
  }

  /**
   * Enters a search term and allows the app's debounced search to run.
   * @param {string} term - Serial, model, or store text to search for.
   */
  async searchFor(term: string): Promise<void> {
    await this.search.fill(term);
  }

  /**
   * Applies a device status filter.
   * @param {string} status - Status option to select, or an empty string for all statuses.
   */
  async filterByStatus(status: string): Promise<void> {
    await this.statusFilter.selectOption(status);
  }

  /**
   * Opens the device at the given row index.
   * @param {number} index - Zero-based index of the device row to open.
   */
  async openDevice(index = 0): Promise<void> {
    await this.rows.nth(index).click();
  }

  /** Requests and displays the next page of devices. */
  async loadMore(): Promise<void> {
    await this.loadMoreButton.click();
  }

  /**
   * Checks the visible first-page row count and the overall result total.
   * @param {number} pageSize - Expected number of rows on the current page.
   * @param {number} totalDevices - Expected total number of matching devices.
   */
  async assertFirstPageShowsDeviceCountAndTotal(pageSize: number, totalDevices: number): Promise<void> {
    await expect(this.rows).toHaveCount(pageSize);
    await expect(this.resultCount).toHaveText(`${totalDevices} devices`);
  }

  /**
   * Checks how many device rows are currently rendered.
   * @param {number} count - Expected number of visible device rows.
   */
  async assertLoadedDeviceCount(count: number): Promise<void> {
    await expect(this.rows).toHaveCount(count);
  }

  /** Checks that no additional device page is available. */
  async assertLoadMoreHidden(): Promise<void> {
    await expect(this.loadMoreButton).toBeHidden();
  }

  /**
   * Checks result count and verifies each returned serial contains the given fragment, ignoring case.
   * @param {string} fragment - Serial-number fragment expected in each matching result.
   * @param {number} resultCount - Expected number of matching device rows.
   */
  async assertSearchResultsContainSerialFragment(fragment: string, resultCount: number): Promise<void> {
    await expect(this.rows).toHaveCount(resultCount);
    const serials = await this.rows.evaluateAll((rows) =>
      rows.map((row) => row.querySelector('td')?.textContent?.trim() ?? ''));

    expect(serials.every((serial) => serial.toLowerCase().includes(fragment.toLowerCase()))).toBeTruthy();
  }

  /**
   * Checks that a search with no matches displays the empty state and no device rows.
   * @param {string} message - Expected empty-state message.
   */
  async assertNoSearchResults(message: string): Promise<void> {
    await expect(this.rows).toHaveCount(0);
    await expect(this.resultCount).toHaveText('0 devices');
    await expect(this.emptyState).toHaveText(message);
  }

  /**
   * Checks that the selected status filter returns rows with only that status.
   * @param {string} status - Expected device status, such as "online" or "failed".
   */
  async assertRowsHaveStatus(status: string): Promise<void> {
    await expect.poll(() => this.rows.count()).toBeGreaterThan(0);
    const displayedStatuses = await this.rows.evaluateAll((rows) =>
      rows.map((row) => row.querySelector('td:last-child')?.textContent?.trim().toLowerCase() ?? ''));

    expect(displayedStatuses.every((displayedStatus) => displayedStatus === status.toLowerCase())).toBeTruthy();
  }
}
