import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

(async () => {
    console.log('Starting puppeteer...');
    const browser = await puppeteer.launch({ headless: "new" });
    const page = await browser.newPage();
    
    // Intercept network requests to find the Lottie JSON URL
    page.on('response', async (response) => {
        const url = response.url();
        if (url.includes('.json') && url.includes('lottie')) {
            console.log(`Intercepted JSON URL: ${url}`);
            try {
                const buffer = await response.buffer();
                const jsonText = buffer.toString('utf8');
                // Verify it looks like a Lottie file
                if (jsonText.includes('"v":') && jsonText.includes('"layers":')) {
                    fs.writeFileSync(path.join(__dirname, 'public', 'bus-loading.json'), jsonText);
                    console.log('Successfully saved bus-loading.json');
                    process.exit(0);
                }
            } catch (e) {
                console.error("Error reading response:", e);
            }
        }
    });

    console.log('Navigating to page...');
    await page.goto('https://lottiefiles.com/free-animation/animation-1716415932015-qf3NhLNj3L', { waitUntil: 'networkidle2' });
    
    // If not found via interception, try looking in the DOM
    console.log('Checking DOM for fallback...');
    const jsonUrl = await page.evaluate(() => {
        const scripts = Array.from(document.querySelectorAll('script'));
        for (const script of scripts) {
            const match = script.innerHTML.match(/https:\/\/[^"]+?\.json/);
            if (match && match[0].includes('lottie')) {
                return match[0];
            }
        }
        return null;
    });

    if (jsonUrl) {
         console.log(`Found URL in DOM: ${jsonUrl}`);
         const res = await fetch(jsonUrl);
         if(res.ok) {
             const data = await res.text();
             fs.writeFileSync(path.join(__dirname, 'public', 'bus-loading.json'), data);
             console.log('Successfully saved bus-loading.json via DOM url');
             process.exit(0);
         }
    }

    console.log('Failed to auto-download lottie file within timeframe.');
    await browser.close();
    process.exit(1);
})();
