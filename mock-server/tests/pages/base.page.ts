import { expect, type Locator, type Page } from '@playwright/test';

export class BasePage {
  /**
   * Creates a base page object backed by the current Playwright page.
   * @param {Page} page - Playwright page used to locate and interact with the UI.
   */
  constructor(protected readonly page: Page) {}

  /**
   * Finds an element using the app's stable data-testid contract.
   * @param {string} id - The element's data-testid value.
   */
  protected testId(id: string): Locator {
    return this.page.getByTestId(id);
  }

  /**
   * Opens a navigation tab and waits for its screen to become visible.
   * @param {string} tab - Navigation tab name used in its data-testid.
   * @param {Locator} screen - Locator for the screen expected to appear.
   */
  protected async openTab(tab: string, screen: Locator): Promise<void> {
    await this.testId(`tab.${tab}`).click();
    await expect(screen).toBeVisible();
  }
}
