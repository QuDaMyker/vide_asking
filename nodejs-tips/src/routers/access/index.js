'use strict'

const express = require('express')
const accessController = require('../../controllers/access.controller')
const { asyncHandler } = require('../../helpers/asyncHandler')
const { authenticationV2 } = require('../../auth/authUtils')
const router = express.Router()

router.post('/signup', asyncHandler(accessController.signUp))
router.post('/login', asyncHandler(accessController.login))

router.use(authenticationV2)

router.post('/logout', asyncHandler(accessController.logout))
router.post('/handlerRefreshToken', asyncHandler(accessController.handleRefreshToken))

module.exports = router