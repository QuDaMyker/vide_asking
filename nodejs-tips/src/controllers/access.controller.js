'use strict'

const { CREATED, SuccessReponse } = require("../core/success.reponse");
const AccessService = require("../services/access.service");

class AccessController {
    handleRefreshToken = async (req, res, next) => {
        // return new SuccessReponse({
        //     message: 'Get token success',
        //     metadata: await AccessService.handlerRefreshToken(req.body.refreshToken)
        // }).send(res)
        
         return new SuccessReponse({
            message: 'Get token success',
            metadata: await AccessService.handlerRefreshTokenV2({
                refreshToken: req.refreshToken,
                user: req.user,
                keyStore: req.keyStore
            })
        }).send(res)
    }
    logout = async (req, res, next) => {
        return new SuccessReponse({
            message: 'Logout success',
            metadata: await AccessService.logout(req.keyStore)
        }).send(res)
    }

    login = async (req, res, next) => {
        try {
            return new SuccessReponse({
                message: 'Login ok',
                metadata: await AccessService.login(req.body),
            }).send(res)
        } catch (error) {
            next(error)
        }
    }

    signUp = async (req, res, next) => {
        try {
            console.log(`[P]::signUp::`, req.body);
            /**
             * 200 ok
             * 201 created
             */
            // return res.status(201).json(await AccessService.signUp(req.body))
            return new CREATED({
                message: 'Registered OK!',
                metadata: await AccessService.signUp(req.body),
                options: {
                    limit: 10
                }
            }).send(res)
            
        } catch (err) {
            next(err)
        }
    }
}

module.exports = new AccessController()