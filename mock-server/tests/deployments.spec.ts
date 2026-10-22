import { expect, test } from '@playwright/test';
import { ContentPage } from './pages/content.page';
import { DeploymentsPage } from './pages/deployments.page';

/** Restores standard server data before each deployment test. */
test.beforeEach(async ({ page, request }) => {
  const response = await request.post('/__admin/reset');
  expect(response.ok()).toBeTruthy();
  await page.goto('/');
});

/** Verifies the app rejects deploying an already-active package to the same store. */
test('rejects a duplicate active package deployment', async ({ page }) => {
  const content = new ContentPage(page);
  await content.open();
  await content.openDeployDialog('pkg-001');
  await content.selectStore('store-001');
  await content.submitDeployment.click();

  await expect(content.deployError).toContainText('already being deployed');
  await expect(content.deployDialog).toBeVisible();
});

/** Verifies a new deployment appears and an active deployment can be cancelled. */
test('creates a deployment and allows an active deployment to be cancelled', async ({ page }) => {
  const content = new ContentPage(page);
  const deployments = new DeploymentsPage(page);
  await content.open();
  await content.openDeployDialog('pkg-002');
  await content.selectStore('store-001');
  await content.submitDeployment.click();

  await expect(deployments.screen).toBeVisible();
  const scheduledDeployment = deployments.deploymentList
    .getByRole('listitem')
    .filter({ hasText: 'Trade-In Promo' })
    .filter({ hasText: 'In Progress' });
  await expect(scheduledDeployment).toBeVisible();

  const seededDeployment = deployments.deploymentRow('dep-001');
  await expect(seededDeployment.getByTestId('deployments.status.dep-001')).toHaveText('In Progress');
  await seededDeployment.getByTestId('deployments.cancel.dep-001').click();
  await expect(seededDeployment.getByTestId('deployments.status.dep-001')).toHaveText('Cancelled');
});
