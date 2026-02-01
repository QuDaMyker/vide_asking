"use strict";

const mongoose = require("mongoose");

const connectString = `mongodb://localhost:27018/shopDEV`;

mongoose
  .connect(connectString)
  .then((_) => console.log(`Connected Mongodb Success`))
  .catch((err) => console.log(`Error Connect! ${err}`));

if (1 === 0) {
    mongoose.set('debug', true)
    mongoose.set("debug", { color: true });
}

module.exports = mongoose