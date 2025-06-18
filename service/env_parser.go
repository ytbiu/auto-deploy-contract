package service

import (
	"fmt"
	"os"

	"github.com/joho/godotenv"
)

// LoadEnv 加载并解析 .env 文件
func LoadEnv(path string) error {
	// 加载 .env 文件
	err := godotenv.Load(path)
	if err != nil {
		return fmt.Errorf("failed to load .env file err: %v. path: %v", err, path)
	}

	return nil

}

func WriteEnv(envVars map[string]string, path string, tp contractType) error {
	envVars["PRIVATE_KEY"] = os.Getenv("PRIVATE_KEY")

	if tp == IAO {
		envVars["XAAIAO_TOKEN_IN_CONTRACT"] = XAAIAO_TOKEN_IN_CONTRACT
		envVars["XAAIAO_NFT_HOLDER_CONTRACT"] = XAAIAO_NFT_HOLDER_CONTRACT

	}
	if tp == STAKING {
		envVars["DBC_AI_PROXY"] = DBC_AI_PROXY
	}

	// 构建 .env 文件内容
	var envContent string
	for key, value := range envVars {
		envContent += fmt.Sprintf("%s=%s\n", key, value)
	}
	// 将内容写入 .env 文件
	err := os.WriteFile(path, []byte(envContent), 0644)
	if err != nil {
		return fmt.Errorf("failed to write .env file: %v", err)
	}
	return nil
}
