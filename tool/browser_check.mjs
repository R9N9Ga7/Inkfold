import { writeFileSync } from 'node:fs';

const [widthArg = '1440', heightArg = '900', output = 'build/browser-check.png'] = process.argv.slice(2);
const width = Number(widthArg);
const height = Number(heightArg);

async function connect() {
  for (let attempt = 0; attempt < 40; attempt++) {
    try {
      const pages = await fetch('http://127.0.0.1:9222/json/list').then((response) => response.json());
      const page = pages.find((item) => item.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch (_) {
      // Chrome is still starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error('Chrome DevTools endpoint did not start.');
}

const socket = new WebSocket(await connect());
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});

let sequence = 0;
const pending = new Map();
const runtimeErrors = [];
socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (message.id != null) {
    const callback = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) callback.reject(new Error(message.error.message));
    else callback.resolve(message.result);
    return;
  }
  if (message.method === 'Runtime.exceptionThrown') {
    runtimeErrors.push(message.params.exceptionDetails.text);
  }
  if (message.method === 'Runtime.consoleAPICalled' && message.params.type === 'error') {
    runtimeErrors.push(message.params.args.map((arg) => arg.description ?? arg.value).join(' '));
  }
});

function send(method, params = {}) {
  const id = ++sequence;
  socket.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

await send('Page.enable');
await send('Runtime.enable');
await send('Accessibility.enable');
await send('Emulation.setDeviceMetricsOverride', {
  width,
  height,
  deviceScaleFactor: 1,
  mobile: width < 600,
});
await send('Page.navigate', { url: 'http://localhost:8080' });
await new Promise((resolve) => setTimeout(resolve, 12000));

const tree = await send('Accessibility.getFullAXTree');
const labels = tree.nodes
  .map((node) => node.name?.value)
  .filter((value) => typeof value === 'string' && value.trim().length > 0);
const screenshot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
writeFileSync(output, Buffer.from(screenshot.data, 'base64'));

console.log(JSON.stringify({ width, height, labels, runtimeErrors }, null, 2));
socket.close();
