require('dotenv').config()
const compression = require('compression');
const express = require('express');
const {default : helmet} = require('helmet')
const morgan = require('morgan')
const app = express();

// console.log(`Process:`, process.env)

// init middleware
app.use(morgan('dev'));
// app.use(morgan('combined'));
// app.use(morgan('combined'));
// morgan('common')
// morgan('short')
// morgan('tiny')
app.use(helmet())
app.use(compression())

// init database
require('./dbs/init.mongodb')


// init routers
app.use(express.json())
app.use(express.urlencoded({ extended: true }))
app.use('/', require('./routers/index'))

// handle errors
app.use((req, res, next) => {
    const error = new Error('Not Found')
    error.status = 404
    next(error)
})

app.use((error, req, res, next) => {
   const statusCode = error.status || 500
   console.log(error)
   return res.status(statusCode).json({
    status: 'errr',
    code: statusCode,
    message: error.message || 'Internal Server Error'
   })
})


module.exports = app;