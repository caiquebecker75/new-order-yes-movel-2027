// Confere se cada biblioteca carrega e se o Chromium usado pelas libs
// baseadas em navegador abre corretamente. Nao conecta em nenhum numero.
const fs = require('fs');

const libs = [
  'whatsapp-web.js',
  'baileys',
  '@wppconnect-team/wppconnect',
  '@open-wa/wa-automate',
  'venom-bot',
];

const path = require('path');

const version = (name) =>
  JSON.parse(fs.readFileSync(path.join(__dirname, 'node_modules', name, 'package.json'))).version;

(async () => {
  let ok = true;
  for (const name of libs) {
    try {
      await import(name);
      console.log(`OK    ${name}@${version(name)}`);
    } catch (err) {
      ok = false;
      console.log(`FALHA ${name}: ${err.message.split('\n')[0]}`);
    }
  }

  const executablePath = process.env.PUPPETEER_EXECUTABLE_PATH || '/opt/pw-browsers/chromium';
  try {
    const puppeteer = require('puppeteer');
    const browser = await puppeteer.launch({ executablePath, headless: true, args: ['--no-sandbox'] });
    console.log(`OK    Chromium ${await browser.version()} (${executablePath})`);
    await browser.close();
  } catch (err) {
    ok = false;
    console.log(`FALHA Chromium em ${executablePath}: ${err.message.split('\n')[0]}`);
  }
  process.exit(ok ? 0 : 1);
})();
