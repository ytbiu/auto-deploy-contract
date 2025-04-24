package middleware

import (
	"encoding/base64"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	Username        = "admin"
	DefaultPassword = "admin123"
)

func getAdminPassword() string {
	if password := os.Getenv("ADMIN_PASSWORD"); password != "" {
		return password
	}
	return DefaultPassword
}

// BasicAuth 中间件用于验证Basic Auth认证
func BasicAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		auth := c.GetHeader("Authorization")
		if auth == "" {
			c.Header("WWW-Authenticate", "Basic realm=\"Authorization Required\"")
			c.AbortWithStatusJSON(401, gin.H{
				"code":    401,
				"message": "Unauthorized",
				"data":    gin.H{"error": "Authorization header is required"},
			})
			return
		}

		if !strings.HasPrefix(auth, "Basic ") {
			c.AbortWithStatusJSON(401, gin.H{
				"code":    401,
				"message": "Invalid authorization format",
				"data":    gin.H{"error": "Invalid authorization format"},
			})
			return
		}

		payload, _ := base64.StdEncoding.DecodeString(auth[6:])
		pair := strings.SplitN(string(payload), ":", 2)

		if len(pair) != 2 || pair[0] != Username || pair[1] != getAdminPassword() {
			c.AbortWithStatusJSON(401, gin.H{
				"code":    401,
				"message": "Invalid credentials",
				"data":    gin.H{"error": "Invalid credentials"},
			})
			return
		}

		c.Next()
	}
}
