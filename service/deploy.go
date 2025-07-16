package service

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
)

type contractType int

const (
	IAO contractType = iota
	STAKING
	TOKEN
	PAYMENT
)

// execCommand is used to make the function testable
var execCommand = exec.Command

func DeployContract(path, envPath string, scriptEnvVars map[string]string, tp contractType) (proxyAddress string, err error) {
	err = LoadEnv("./.env")
	if err != nil {
		log.Fatal(err)
	}

	err = WriteEnv(scriptEnvVars, envPath, tp)
	if err != nil {
		return "", err
	}
	defer func() {
		cleanCMD := execCommand("forge", "clean")
		cleanCMD.Dir = path
		// Set environment variables with explicit paths to avoid version conflicts
		env := os.Environ()
		// Prioritize correct Node.js version and forge paths
		pathVar := "/home/ubuntu/.nvm/versions/node/v23.9.0/bin:/home/ubuntu/.foundry/bin:/usr/local/bin:/usr/bin:/bin"
		env = append(env, "PATH="+pathVar)
		cleanCMD.Env = env
		_, _ = cleanCMD.CombinedOutput()
	}()

	deployTarget := "deploy-XAAAIO-dbc-mainnet"
	if tp == STAKING {
		deployTarget = "deploy-staking-dbc-mainnet"
	}
	if tp == TOKEN {
		deployTarget = "deploy-token-dbc-mainnet"
	}
	if tp == PAYMENT {
		deployTarget = "deploy-payment-mainnet"
	}
	cmd := execCommand("bash", "-c", fmt.Sprintf(
		"make %s PRIVATE_KEY=%s dbc-mainnet=%s MAIN_NET_VERIFIER_URL=%s",
		deployTarget,
		os.Getenv("PRIVATE_KEY"),
		DBC_MAINNET,
		MAIN_NET_VERIFIER_URL,
	))
	cmd.Dir = path
	// Set environment variables with explicit paths to avoid version conflicts
	env := os.Environ()
	// Prioritize correct Node.js version and forge paths
	pathVar := "/home/ubuntu/.nvm/versions/node/v23.9.0/bin:/home/ubuntu/.foundry/bin:/usr/local/bin:/usr/bin:/bin"
	env = append(env, "PATH="+pathVar)
	cmd.Env = env

	log.Printf("Executing command:  make %s PRIVATE_KEY=%s dbc-mainnet=%s MAIN_NET_VERIFIER_URL=%s",
		deployTarget,
		os.Getenv("PRIVATE_KEY"),
		DBC_MAINNET,
		MAIN_NET_VERIFIER_URL)

	output, err := cmd.CombinedOutput()
	log.Printf("Command output:\n%s", string(output))

	if err != nil {
		return "", fmt.Errorf("deploy error: %v: %s", err, string(output))
	}

	outputStr := string(output)
	lines := strings.Split(outputStr, "\n")
	for _, line := range lines {
		if strings.Contains(line, "Proxy Contract deployed at:") {
			proxyAddress = strings.TrimSpace(strings.Split(line, ":")[1])
		}
	}

	if proxyAddress == "" {
		return "", fmt.Errorf("failed to parse contract addresses from output")
	}

	return proxyAddress, nil
}
