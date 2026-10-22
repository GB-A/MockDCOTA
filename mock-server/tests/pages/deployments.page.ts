import { type Locator } from '@playwright/test';
import { BasePage } from './base.page';

export class DeploymentsPage extends BasePage {
  readonly screen = this.testId('deployments.screen');
  readonly deploymentList = this.testId('deployments.list');

  /** Navigates to the deployments screen and waits for it to appear. */
  async open(): Promise<void> {
    await this.openTab('deployments', this.screen);
  }

  /**
   * Returns the locator for a deployment row by deployment ID.
   * @param {string} deploymentId - ID of the deployment row to locate.
   */
  deploymentRow(deploymentId: string): Locator {
    return this.testId(`deployments.row.${deploymentId}`);
  }
}
