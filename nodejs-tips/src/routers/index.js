'use strict'

const express = require('express')
const { apiKey, permission } = require('../auth/checkAuth')
const router = express.Router()

router.use(apiKey)
router.use(permission('0000'))

router.use('/v1/api/auth', require('./access'))
router.use('/v1/api/product', require('./product'))

// router.get('', (req, res, next) => {
//     return res.status(200).json({
//         message: 'welcome',
//     })
// })

module.exports = router