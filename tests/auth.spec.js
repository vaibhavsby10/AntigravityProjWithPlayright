const { test, expect } = require('@playwright/test');

test.describe('Authentication and Portal Flow', () => {

  test('TC1: Should display login page with form elements', async ({ page }) => {
    await page.goto('/login.html');

    // Verify title and header
    await expect(page).toHaveTitle('Login - Portal');
    await expect(page.locator('h1')).toHaveText('Welcome Back');

    // Verify input fields and button exist
    await expect(page.locator('#username')).toBeVisible();
    await expect(page.locator('#password')).toBeVisible();
    await expect(page.locator('#loginButton')).toBeVisible();

    // Error message should initially be hidden
    await expect(page.locator('#errorMessage')).toBeHidden();
  });

  test('TC2: Should show error message when using invalid credentials', async ({ page }) => {
    await page.goto('/login.html');

    // Fill invalid credentials
    await page.fill('#username', 'wronguser');
    await page.fill('#password', 'wrongpass');
    await page.click('#loginButton');

    // Error message must become visible
    const errorMessage = page.locator('#errorMessage');
    await expect(errorMessage).toBeVisible();
    await expect(errorMessage).toContainText('Invalid User ID or Password');

    // Page must remain on login.html
    expect(page.url()).toContain('/login.html');
  });

  test('TC3: Should automatically log in with admin/admin and browse index.html', async ({ page }) => {
    // 1. Navigate to login page
    await page.goto('/login.html');

    // 2. Automatically enter default credentials
    await page.fill('#username', 'admin');
    await page.fill('#password', 'admin');

    // 3. Automatically click login
    await page.click('#loginButton');

    // 4. Verify automatic redirect to index.html
    await page.waitForURL('**/index.html');
    expect(page.url()).toContain('/index.html');

    // 5. Browse the page & verify authenticated user elements
    await expect(page.locator('#headerUsername')).toHaveText('admin');
    await expect(page.locator('#displayUsername')).toHaveText('admin');
    await expect(page.locator('.status-indicator')).toBeVisible();
    await expect(page.locator('.welcome-card')).toContainText('Welcome, admin!');
    await expect(page.locator('#logoutBtn')).toBeVisible();
  });

  test('TC4: Route Protection - Direct access to index.html without login should redirect to login.html', async ({ page }) => {
    // Try to navigate directly to index.html without an active session
    await page.goto('/index.html');

    // Verify automatic redirect back to login.html
    await page.waitForURL('**/login.html');
    expect(page.url()).toContain('/login.html');
  });

  test('TC5: Logout - Clicking logout should clear session and return to login.html', async ({ page }) => {
    // 1. Log in first
    await page.goto('/login.html');
    await page.fill('#username', 'admin');
    await page.fill('#password', 'admin');
    await page.click('#loginButton');
    await page.waitForURL('**/index.html');

    // 2. Click Logout button
    await page.click('#logoutBtn');

    // 3. Verify redirect to login.html
    await page.waitForURL('**/login.html');
    expect(page.url()).toContain('/login.html');

    // 4. Verify session storage is cleared
    const currentUser = await page.evaluate(() => sessionStorage.getItem('currentUser'));
    expect(currentUser).toBeNull();

    // 5. Attempt to go back to index.html
    await page.goto('/index.html');
    await page.waitForURL('**/login.html');
    expect(page.url()).toContain('/login.html');
  });

});
