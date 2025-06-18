package api

import (
	"auto-deploy-contract/service"
	"fmt"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
	"github.com/go-playground/validator/v10"
)

// @title Auto Deploy Contract API
// @version 1.0
// @description This is the API documentation for Auto Deploy Contract
// @BasePath /api/v1

// DeployTokenRequest represents the request body for deployment
// @DeployTokenRequest
type DeployTokenRequest struct {
	Owner                     string `json:"owner" binding:"required" example:"0xAE5015960Ff1E3ad095a7037533b1e3E7240b54D"`
	TokenName                 string `json:"token_name" binding:"required,nowhitespace" example:"TokenName"`
	TokenSymbol               string `json:"token_symbol" binding:"required,nowhitespace" example:"TN"`
	TokenInitSupply           string `json:"token_init_supply" binding:"required" example:"2000000000000000000000000000"`
	TokenSupplyFixedYears     int    `json:"token_supply_fixed_years" binding:"required" example:"8"`
	TokenAmountCanMintPerYear string `json:"token_amount_can_mint_per_year" binding:"required" example:"6000000000000000000000000000"`
	IAOContractAddress string `json:"iao_contract_address" binding:"required" example:"0xAE5015960Ff1E3ad095a7037533b1e3E7240b54D"`
	AmountToIAO string `json:"amount_to_iao" binding:"required" example:"100000000000000000000000000"`
}

func (req *DeployTokenRequest) ToMap() map[string]string {
	return map[string]string{
		"TOKEN_OWNER":                    req.Owner,
		"TOKEN_NAME":                     req.TokenName,
		"TOKEN_SYMBOL":                   req.TokenSymbol,
		"TOKEN_INIT_SUPPLY":              req.TokenInitSupply,
		"TOKEN_SUPPLY_FIXED_YEARS":       fmt.Sprintf("%d", req.TokenSupplyFixedYears),
		"TOKEN_AMOUNT_CAN_MINT_PER_YEAR": req.TokenAmountCanMintPerYear,
		"IAO_CONTRACT_ADDRESS": req.IAOContractAddress,
		"AMOUNT_TO_IAO": req.AmountToIAO,
	}
}

// DeployTokenResponse represents the response for deployment
// @DeployTokenResponse
type DeployTokenResponse struct {
	ProxyAddress string `json:"proxy_address" example:"0x1234567890abcdef"`
	Error        string `json:"error,omitempty" example:"error message"`
}

// @Summary Deploy contract
// @Description Deploy a new contract with the given parameters
// @Tags deployment
// @Accept json
// @Produce json
// @Param request body DeployTokenRequest true "Deployment parameters"
// @Success 200 {object} StandardResponse
// @Failure 400 {object} StandardResponse
// @Failure 500 {object} StandardResponse
// @Router /deploy/token [post]
func handleDeployToken(c *gin.Context) {
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

	var req DeployTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(200, StandardResponse{
			Code:    400,
			Message: "Invalid request parameters",
			Data:    gin.H{"error": err.Error()},
		})
		return
	}

	proxyAddr, err := service.DeployContract(service.ContractPath, service.ContractEnvPath, req.ToMap(), service.TOKEN)
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

func RegisterDeployTokenRoutes(router *gin.Engine) {
	router.POST("/deploy/token", handleDeployToken)
}

func init() {
	if v, ok := binding.Validator.Engine().(*validator.Validate); ok {
		v.RegisterValidation("nowhitespace", func(fl validator.FieldLevel) bool {
			return !strings.Contains(fl.Field().String(), " ")
		})
	}
}
