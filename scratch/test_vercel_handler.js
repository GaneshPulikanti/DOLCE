import handler from '../api/gateway.js';

async function testVercelHandler() {
  const req = {
    method: 'POST',
    url: '/api/gateway?path=youtubei/v1/search&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30&alt=json',
    headers: {
      host: 'localhost:3000',
      'content-type': 'application/json'
    },
    query: {
      path: 'youtubei/v1/search',
      key: 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30',
      alt: 'json'
    },
    body: JSON.stringify({
      context: {
        client: {
          clientName: 'WEB_REMIX',
          clientVersion: '1.20260526.04.00',
          gl: 'IN',
          hl: 'en'
        }
      },
      query: 'Coldplay'
    })
  };

  const res = {
    statusCode: 200,
    headers: {},
    setHeader(k, v) { this.headers[k] = v; },
    status(code) { this.statusCode = code; return this; },
    send(data) {
      console.log(`Response Code: ${this.statusCode}`);
      console.log(`Response length: ${data ? data.length : 0}`);
      if (data && data.length < 500) {
        console.log(`Data: ${data}`);
      }
    },
    json(obj) {
      console.log(`JSON Response (${this.statusCode}):`, obj);
    },
    end() {}
  };

  await handler(req, res);
}

testVercelHandler().catch(console.error);
