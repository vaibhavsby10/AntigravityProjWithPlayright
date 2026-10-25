const { chromium } = require('@playwright/test');
const http = require('http');
const fs = require('fs');
const path = require('path');

// Optional standalone server in case it is not already running
function startLocalServer(port = 3050) {
  return new Promise((resolve) => {
    const MIME_TYPES = {
      '.html': 'text/html',
      '.css': 'text/css',
      '.js': 'text/javascript',
      '.json': 'application/json',
    };

    const server = http.createServer((req, res) => {
      let filePath = path.join(__dirname, req.url === '/' ? 'login.html' : req.url.split('?')[0]);
      const ext = path.extname(filePath).toLowerCase();
      const contentType = MIME_TYPES[ext] || 'text/html';

      fs.readFile(filePath, (err, content) => {
        if (err) {
          res.writeHead(404);
          res.end('Not Found');
        } else {
          res.writeHead(200, { 'Content-Type': contentType });
          res.end(content);
        }
      });
    });

    server.on('error', () => {
      // Server may already be running on port 3050
      resolve(null);
    });

    server.listen(port, () => {
      resolve(server);
    });
  });
}

(async () => {
  const server = await startLocalServer(3050);
  console.log('🚀 Launching automated browser with Playwright...');

  // Launch headed browser with a small delay between actions so the user can watch
  const browser = await chromium.launch({
    headless: false,
    slowMo: 500, // 500ms delay between actions to see typing & clicks clearly
  });

  const context = await browser.newContext({
    recordVideo: {
      dir: './recordings/',
      size: { width: 1280, height: 720 },
    },
  });
  const page = await context.newPage();

  console.log('🌐 Step 1: Navigating to login.html...');
  await page.goto('http://localhost:3050/login.html');

  console.log('✍️  Step 2: Entering User ID: admin...');
  await page.fill('#username', 'admin');

  console.log('🔑 Step 3: Entering Password: admin...');
  await page.fill('#password', 'admin');

  console.log('🖱️  Step 4: Clicking Log In button...');
  await page.click('#loginButton');

  // Wait for redirect to index.html
  await page.waitForURL('**/index.html');
  console.log('🎉 Step 5: Successfully redirected to index.html!');

  // Verify elements
  const displayedUser = await page.locator('#headerUsername').textContent();
  console.log(`👤 Active User detected on page: ${displayedUser}`);

  console.log('👀 Browsing dashboard for 5 seconds...');
  await page.waitForTimeout(5000);

  console.log('✅ Automated test session complete.');
  const video = page.video();
  await context.close();
  await browser.close();

  if (video) {
    const videoPath = await video.path();
    const finalVideo = path.join(__dirname, 'recordings', 'live_browse_session.webm');
    try {
      if (fs.existsSync(finalVideo)) fs.unlinkSync(finalVideo);
      fs.renameSync(videoPath, finalVideo);
      console.log(`📹 Video recorded successfully at: ${finalVideo}`);
    } catch (e) {
      console.log(`📹 Video saved at: ${videoPath}`);
    }
  }

  if (server) {
    server.close();
  }
  process.exit(0);
})();
