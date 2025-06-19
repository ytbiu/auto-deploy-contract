package main

import (
	"auto-deploy-contract/api"
	"auto-deploy-contract/api/middleware"
	"flag"
	"log"

	_ "auto-deploy-contract/docs"

	"auto-deploy-contract/service"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files" // 修改为新的导入路径
	ginSwagger "github.com/swaggo/gin-swagger"
)

func init() {
	// 初始化日志
	service.LoadEnv("./.env")
}

func main() {
	// 添加环境参数
	env := flag.String("env", "dev", "(dev/prod)")
	flag.Parse()

	service.Init(*env)
	if *env == "prod" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// 添加全局Basic Auth中间件
	router.Use(middleware.BasicAuth())

	// 添加 Swagger 路由
	router.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	// 注册路由
	api.RegisterDeployIAORoutes(router)
	api.RegisterDeployStakingRoutes(router)
	api.RegisterDeployTokenRoutes(router)
	api.RegisterDeployPaymentRoutes(router)
	log.Printf("Server starting on :8070 in %s mode", *env)
	if err := router.Run("0.0.0.0:8070"); err != nil {
		log.Fatal(err)
	}
}
