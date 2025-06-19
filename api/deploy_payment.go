package api

import (
	"auto-deploy-contract/api/middleware"
	"auto-deploy-contract/service"

	"fmt"
	"github.com/gin-gonic/gin"
)

// @title Auto Deploy Contract API
// @version 1.0
// @description This is the API documentation for Auto Deploy Contract
// @BasePath /api/v1
// @securityDefinitions.basic BasicAuth
// @Security BasicAuth

// DeployPaymentRequest represents the request body for deployment
// @DeployPaymentRequest
type DeployPaymentRequest struct {
	// Owner address of the contract
	Owner string `json:"owner" binding:"required" example:"0xAE5015960Ff1E3ad095a7037533b1e3E7240b54D"`
	// Payment token address
	PaymentToken string `json:"payment_token" binding:"required" example:"0x07D325030dA1A8c1f96C414BFFbe4fBD539CED45"`
	// Number of free requests available for the contract
	FreeRequestCount int `json:"free_request_count" binding:"required" example:"100"`
	// Number of free requests available for each address
	AddressFreeRequestCount int `json:"address_free_request_count" binding:"required" example:"10"`
	// Minimum USD balance required for using free requests for the address
	MinUsdBalanceForUsingFreeRequest int64 `json:"min_usd_balance_for_using_free_request" binding:"required" example:"100000"`
	// Number of VIP requests available for each month
	VIPMonthlyQuotas int `json:"vip_monthly_quotas" binding:"required" example:"10"`
	// Fixed price for VIP requests
	VIPPriceFixedCount int `json:"vip_price_fixed_count" binding:"required" example:"100000"`
	// Monthly price for VIP requests
	VIPPriceMonthly int `json:"vip_price_monthly" binding:"required" example:"100000"`
}

func (req *DeployPaymentRequest) ToMap() map[string]string {
	return map[string]string{
		"OWNER":                                  req.Owner,
		"PAYMENT_TOKEN":                          req.PaymentToken,
		"FREE_REQUEST_COUNT":                     fmt.Sprintf("%d", req.FreeRequestCount),
		"ADDRESS_FREE_REQUEST_COUNT":             fmt.Sprintf("%d", req.AddressFreeRequestCount),
		"MIN_USD_BALANCE_FOR_USING_FREE_REQUEST": fmt.Sprintf("%d", req.MinUsdBalanceForUsingFreeRequest),
		"VIP_MONTHLY_QUOTAS":                     fmt.Sprintf("%d", req.VIPMonthlyQuotas),
		"VIP_PRICE_FIXED_COUNT":                  fmt.Sprintf("%d", req.VIPPriceFixedCount),
		"VIP_PRICE_MONTHLY":                      fmt.Sprintf("%d", req.VIPPriceMonthly),
	}
}

// DeployPaymentResponse represents the response for deployment
// @DeployPaymentResponse
type DeployPaymentResponse struct {
	ProxyAddress string `json:"proxy_address" example:"0x1234567890abcdef"`
	Error        string `json:"error,omitempty" example:"error message"`
}

// @Summary Deploy contract
// @Description Deploy a new contract with the given parameters
// @Tags deployment
// @Accept json
// @Produce json
// @Param request body DeployPaymentRequest true "Deployment parameters"
// @Success 200 {object} StandardResponse
// @Failure 400 {object} StandardResponse
// @Failure 500 {object} StandardResponse
// @Router /deploy/payment [post]
func handleDeployPayment(c *gin.Context) {
	if Pending {
		c.JSON(200, StandardResponse{
			Code:    400,
			Message: "Pending",
			Data:    gin.H{"error": "Pending"},
		})
		return
	}

	Pending = true
	defer func() {
		Pending = false
	}()

	var req DeployPaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(200, StandardResponse{
			Code:    400,
			Message: "Invalid request parameters",
			Data:    gin.H{"error": err.Error()},
		})
		return
	}

	proxyAddr, err := service.DeployContract(service.ContractPath, service.ContractEnvPath, req.ToMap(), service.PAYMENT)
	if err != nil {
		c.JSON(200, StandardResponse{
			Code:    500,
			Message: "Deployment failed",
			Data:    gin.H{"error": err.Error()},
		})
		return
	}

	c.JSON(200, StandardResponse{
		Code:    200,
		Message: "Deployment successful",
		Data:    gin.H{"proxy_address": proxyAddr},
	})
}

func RegisterDeployPaymentRoutes(router *gin.Engine) {
	router.POST("/deploy/payment", middleware.BasicAuth(), handleDeployPayment)
}
