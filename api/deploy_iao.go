package api

import (
	"auto-deploy-contract/api/middleware"
	"auto-deploy-contract/service"
	"fmt"

	"github.com/gin-gonic/gin"
)

var (
	Pending bool
)

// @title Auto Deploy Contract API
// @version 1.0
// @description This is the API documentation for Auto Deploy Contract
// @BasePath /api/v1
// @securityDefinitions.basic BasicAuth
// @Security BasicAuth

// DeployIAORequest represents the request body for deployment
// @DeployIAORequest
type DeployIAORequest struct {
	Owner          string `json:"owner" binding:"required" example:"0xAE5015960Ff1E3ad095a7037533b1e3E7240b54D"`
	RewardToken    string `json:"reward_token" binding:"required" example:"0x07D325030dA1A8c1f96C414BFFbe4fBD539CED45"`
	StartTimestamp int64  `json:"start_timestamp" binding:"required" example:"1743663600"`
	DurationHours  int    `json:"duration_hours" binding:"required" example:"72"`
	RewardAmount   string `json:"reward_amount" binding:"required" example:"2000000000000000000000000000"`
	TokenInAddress string `json:"token_in_address" binding:"required" example:"0x07D325030dA1A8c1f96C414BFFbe4fBD539CED45"`
}

func (req *DeployIAORequest) ToMap() map[string]string {
	return map[string]string{
		"XAAIAO_OWNER":                 req.Owner,
		"XAAIAO_REWARD_TOKEN_CONTRACT": req.RewardToken,
		"XAAIAO_START_TIMESTAMP":       fmt.Sprintf("%d", req.StartTimestamp),
		"XAAIAO_PERIOD_HOURS":          fmt.Sprintf("%d", req.DurationHours),
		"XAAIAO_REWARD_AMOUNT":         req.RewardAmount,
		"XAAIAO_TOKEN_IN_CONTRACT":     req.TokenInAddress,
	}
}

// DeployIAOResponse represents the response for deployment
// @DeployIAOResponse
type DeployIAOResponse struct {
	ProxyAddress string `json:"proxy_address" example:"0x1234567890abcdef"`
	Error        string `json:"error,omitempty" example:"error message"`
}

// @Summary Deploy contract
// @Description Deploy a new contract with the given parameters
// @Tags deployment
// @Accept json
// @Produce json
// @Param request body DeployIAORequest true "Deployment parameters"
// @Success 200 {object} StandardResponse
// @Failure 400 {object} StandardResponse
// @Failure 500 {object} StandardResponse
// @Router /deploy/IAO [post]
func handleDeployIAO(c *gin.Context) {
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

	var req DeployIAORequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(200, StandardResponse{
			Code:    400,
			Message: "Invalid request parameters",
			Data:    gin.H{"error": err.Error()},
		})
		return
	}

	proxyAddr, err := service.DeployContract(service.ContractPath, service.ContractEnvPath, req.ToMap(), service.IAO)
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

func RegisterDeployIAORoutes(router *gin.Engine) {
	router.POST("/deploy/IAO", middleware.BasicAuth(), handleDeployIAO)
}

// Define standard response structure
type StandardResponse struct {
	Code    int         `json:"code"`    // Status code
	Message string      `json:"message"` // Message
	Data    interface{} `json:"data"`    // Data
}
