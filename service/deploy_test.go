package service

import (
	"fmt"
	"os/exec"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// MockCmd is a mock for command execution
type MockCmd struct {
	mock.Mock
}

func (m *MockCmd) CombinedOutput() ([]byte, error) {
	args := m.Called()
	return args.Get(0).([]byte), args.Error(1)
}

// mockExecCommand is used to inject mock for testing
var mockExecCommand func(command string, args ...string) *exec.Cmd

// setupTest sets up the test environment
func setupTest(t *testing.T) func() {
	originalExecCommand := execCommand
	execCommand = func(command string, args ...string) *exec.Cmd {
		return &exec.Cmd{}
	}
	return func() {
		execCommand = originalExecCommand
	}
}

// TestDeployContract_Success tests the successful deployment scenario
func TestDeployContract_Success(t *testing.T) {

	scriptEnvVars := map[string]string{
		"XAAIAO_OWNER":                 "0xAE5015960Ff1E3ad095a7037533b1e3E7240b54D",
		"XAAIAO_REWARD_TOKEN_CONTRACT": "0x07D325030dA1A8c1f96C414BFFbe4fBD539CED45",
		"XAAIAO_START_TIMESTAMP":       "1743663600",
		"XAAIAO_PERIOD_HOURS":          "72",
		"XAAIAO_REWARD_AMOUNT":         "2000000000000000000000000001",
	}

	// Execute test
	proxy, err := DeployContract("../XAASwap", "../XAASwap/envs/iao/.env", scriptEnvVars, IAO)

	assert.NoError(t, err)
	fmt.Printf("proxy: %s", proxy)
}
