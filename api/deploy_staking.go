package api

import (
	"auto-deploy-contract/service"

	"github.com/gin-gonic/gin"
)

// @title Auto Deploy Contract API
// @version 1.0
// @description This is the API documentation for Auto Deploy Contract
// @BasePath /api/v1
// @securityDefinitions.basic BasicAuth
// @Security BasicAuth

// DeployStakingRequest represents the request body for deployment
// @DeployStakingRequest
type DeployStakingRequest struct {
	ProjectName         string `json:"project_name" binding:"required" example:"My Project"`
	RewardAmountPerYear string `json:"reward_amount_per_year" binding:"required" example:"2000000000000000000000000000"`
	Owner               string `json:"owner" binding:"required" example:"0xAE5015960Ff1E3ad095a7037533b1e3E7240b54D"`
	RewardToken         string `json:"reward_token" binding:"required" example:"0x07D325030dA1A8c1f96C414BFFbe4fBD539CED45"`
	NFT                 string `json:"nft"  binding:"required" example:"0x07D325030dA1A8c1f96C414BFFbe4fBD539CED45"`
}

func (req *DeployStakingRequest) ToMap() map[string]string {
	return map[string]string{
		"OWNER":                  req.Owner,
		"PROJECT_NAME":           req.ProjectName,
		"REWARD_AMOUNT_PER_YEAR": req.RewardAmountPerYear,
		"REWARD_TOKEN_CONTRACT":  req.RewardToken,
		"NFT_CONTRACT":           req.NFT,
	}
}

// DeployStakingResponse represents the response for deployment
// @DeployStakingResponse
type DeployStakingResponse struct {
	ProxyAddress string `json:"proxy_address" example:"0x1234567890abcdef"`
	Error        string `json:"error,omitempty" example:"error message"`
}

// @Summary Deploy contract
// @Description Deploy a new contract with the given parameters
// @Tags deployment
// @Accept json
// @Produce json
// @Param request body DeployStakingRequest true "Deployment parameters"
// @Success 200 {object} StandardResponse
// @Failure 400 {object} StandardResponse
// @Failure 500 {object} StandardResponse
// @Router /deploy/staking [post]
func handleDeployStaking(c *gin.Context) {
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

	var req DeployStakingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(200, StandardResponse{
			Code:    400,
			Message: "Invalid request parameters",
			Data:    gin.H{"error": err.Error()},
		})
		return
	}

	proxyAddr, err := service.DeployContract(service.CONTRACTS_PATH, service.CONTRACTS_ENV_PATH, req.ToMap(), service.STAKING)
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

func RegisterDeployStakingRoutes(router *gin.Engine) {
	router.POST("/deploy/staking", handleDeployStaking)
}
