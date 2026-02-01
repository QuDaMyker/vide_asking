'use strict'

const { SuccessReponse } = require("../core/success.reponse");
const ProductServiceV2 = require('../services/product.service.xxx')

class ProductController {
    createProduct = async (req, res, next) => {
        return new SuccessReponse({
            message: 'Create Product success',
            metadata: await ProductServiceV2.createProduct(req.body.product_type, {
                ...req.body,
                product_shop: req.user.userId
            })
        }).send(res)
    }

    /**
     * 
     * @description Get All Drafts For Shop
     * @param {Number} limit
     * @param {Number} skip
     * @return { JSON }
     */
    getAllDraftsForShop = async (req, res, next) => {
            return new SuccessReponse({
                message: 'Get All Drafts For Shop Success',
                metadata: await ProductServiceV2.findAllDraftsForShop({
                    product_shop: req.user.userId,
                })
            }).send(res)
        }

    /**
     * 
     * @description Get All Drafts For Shop
     * @param {Number} limit
     * @param {Number} skip
     * @return { JSON }
     */
    getAllPublishForShop = async (req, res, next) => {
            return new SuccessReponse({
                message: 'Get All Drafts For Shop Success',
                metadata: await ProductServiceV2.findAllPublishForShop({
                    product_shop: req.user.userId,
                })
            }).send(res)
        }

    publishProductByShop = async (req, res, next) => {
        return new SuccessReponse({
                message: 'Publish Product Success',
                metadata: await ProductServiceV2.publishProductByShop({
                    product_shop: req.user.userId,
                    product_id: req.params.id
                })
            }).send(res) 
    } 

    unPublishProductByShop = async (req, res, next) => {
        return new SuccessReponse({
                message: 'Unpublish Product Success',
                metadata: await ProductServiceV2.unPublishProductByShop({
                    product_shop: req.user.userId,
                    product_id: req.params.id
                })
            }).send(res) 
    }    

    getListProducts = async (req, res, next) => {
        return new SuccessReponse({
                message: 'getListProducts Success',
                metadata: await ProductServiceV2.searchProducts(req.params)
            }).send(res) 
    }   
    
    findAllProducts = async (req, res, next) => {
        return new SuccessReponse({
                message: 'findAllProducts Success',
                metadata: await ProductServiceV2.findAllProducts(req.query)
            }).send(res) 
    }   

    findProduct = async (req, res, next) => {
        return new SuccessReponse({
                message: 'findProduct Success',
                metadata: await ProductServiceV2.findProduct({
                    product_id: req.params.id
                })
            }).send(res) 
    }   
}

module.exports = new ProductController()