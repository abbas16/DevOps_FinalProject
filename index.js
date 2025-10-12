const http = require('http');
const port = process.env.PORT || 80;
const server = http.createServer((req, res) => {
  res.end('Hello from automated EC2 + Docker!');
});
server.listen(port, () => console.log('listening on', port));
