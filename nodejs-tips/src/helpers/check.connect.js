"user strict";

const mongoose = require("mongoose");
const os = require('os')
const process = require('process')
const _SECOND = 5000;

const countConnect = () => {
  const numConnection = mongoose.connections.length;
  console.log(`Number of connection ${numConnection}`);
};

const checkOverload = () => {
  setInterval(() => {
    const numConnection = mongoose.connections.length
    const numCores = os.cpus().length
    const memoryUsage = process.memoryUsage().rss
    console.log(`Active connections: ${numConnection}`)
    console.log(`Memory usage:: ${memoryUsage / 1024 / 1024} MB`)

    const maxConnections = numCores *5;
    if (numConnection > maxConnections) {
        console.log(`Connection overload detected`)
    }
  }, _SECOND);
};

module.exports = {
  countConnect,
  checkOverload,
};
