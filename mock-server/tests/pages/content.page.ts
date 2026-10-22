import { expect } from '@playwright/test';
import { BasePage } from './base.page';

export class ContentPage extends BasePage {
  readonly screen = this.testId('content.screen');
  readonly packageList = this.testId('content.list');
  readonly deployDialog = this.testId('deploySheet.screen');
  readonly selectionCount = this.testId('deploySheet.selectionCount');
  readonly deployError = this.testId('deploySheet.error');
  readonly submitDeployment = this.testId('deploySheet.submit');

  /** Navigates to the content screen and waits for it to appear. */
  async open(): Promise<void> {
    await this.openTab('content', this.screen);
  }

  /**
   * Opens the deployment dialog for the specified content package.
   * @param {string} packageId - ID of the package to deploy.
   */
  async openDeployDialog(packageId: string): Promise<void> {
    await this.testId(`content.deploy.${packageId}`).click();
    await expect(this.deployDialog).toBeVisible();
  }

  /**
   * Selects or deselects the specified store in the deployment dialog.
   * @param {string} storeId - ID of the store to toggle.
   */
  async selectStore(storeId: string): Promise<void> {
    await this.testId(`deploySheet.store.${storeId}`).click();
  }

  /** Toggles selection of all stores in the deployment dialog. */
  async selectAllStores(): Promise<void> {
    await this.testId('deploySheet.selectAll').click();
  }
}
