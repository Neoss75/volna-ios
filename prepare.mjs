// Copies the built web player into www/ for the iPhone app.
// Usage (from the Claude folder):  node volna-app-build.mjs  &&  node volna-ios/prepare.mjs
import { cpSync, mkdirSync, rmSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const app = join(here, '..', 'volna-app');
const www = join(here, 'www');

rmSync(www, { recursive: true, force: true });
mkdirSync(join(www, 'icons'), { recursive: true });
cpSync(join(app, 'icons'), join(www, 'icons'), { recursive: true });
cpSync(join(app, 'manifest.webmanifest'), join(www, 'manifest.webmanifest'));

// the offline cache (service worker) is only for the web version: inside the app the files are already on the phone
let html = readFileSync(join(app, 'index.html'), 'utf8');
html = html.replace(/<script>\s*if \('serviceWorker' in navigator\)[\s\S]*?<\/script>\s*/, '').replace(/\r\n/g, '\n');
writeFileSync(join(www, 'index.html'), html);

const build = (html.match(/сборка (\d+)/) || [])[1] || '?';
console.log('www/ обновлён: сборка ' + build + ' (' + Math.round(html.length / 1024) + ' КБ)');
