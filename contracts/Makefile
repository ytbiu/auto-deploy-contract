
deploy-XAAAIO-dbc-testnet:
	source .env && forge script script/XAAIAO/Deploy.s.sol:Deploy --rpc-url dbc-testnet --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL --force --skip-simulation --legacy

upgrade-XAAAIO-dbc-testnet:
	source .env && forge script script/XAAIAO/Upgrade.s.sol:Upgrade --rpc-url dbc-testnet --broadcast --verify --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL --force --skip-simulation --legacy

deploy-XAAAIO-dbc-mainnet2:
	source .env && forge script script/XAAIAO/Deploy.s.sol:Deploy --rpc-url dbc-mainnet --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $MAIN_NET_VERIFIER_URL --force --skip-simulation --legacy

upgrade-XAAAIO-dbc-mainnet:
	source .env && forge script script/XAAIAO/Upgrade.s.sol:Upgrade --rpc-url dbc-mainnet --broadcast --verify --verifier blockscout --verifier-url $MAIN_NET_VERIFIER_URL --force --skip-simulation --legacy

verify-XAAAIO-dbc-testnet:
	source .env && forge verify-contract --chain 19850818  --compiler-version v0.8.26 --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL $PROXY_CONTRACT  src/XAAIAO.sol:XAAIAO --force

deploy-XAAAIO-dbc-mainnet:
	@if [ -f .env ]; then \
		export $$(grep -v '^#' .env | xargs); \
		forge script script/XAAIAO/Deploy.s.sol:Deploy \
		--rpc-url $(dbc-mainnet) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--verifier blockscout \
		--verifier-url $(MAIN_NET_VERIFIER_URL) \
		--force \
		--skip-simulation \
		--legacy; \
	else \
		echo "Error: .env file not found"; \
		exit 1; \
	fi

deploy-staking-dbc-mainnet:
	@if [ -f .env ]; then \
		export $$(grep -v '^#' .env | xargs); \
		forge script script/staking/Deploy.s.sol:Deploy \
		--rpc-url $(dbc-mainnet) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--verifier blockscout \
		--verifier-url $(MAIN_NET_VERIFIER_URL) \
		--force \
		--skip-simulation \
		--legacy; \
	else \
		echo "Error: .env file not found"; \
		exit 1; \
	fi

deploy-token-dbc-mainnet:
	@if [ -f .env ]; then \
		export $$(grep -v '^#' .env | xargs); \
		forge script script/token/Deploy.s.sol:Deploy \
		--rpc-url $(dbc-mainnet) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--verifier blockscout \
		--verifier-url $(MAIN_NET_VERIFIER_URL) \
		--force \
		--skip-simulation \
		--legacy; \
	else \
		echo "Error: .env file not found"; \
		exit 1; \
	fi

deploy-payment-mainnet:
	@if [ -f .env ]; then \
		export $$(grep -v '^#' .env | xargs); \
		forge script script/payment/Deploy.s.sol:Deploy \
		--rpc-url $(dbc-mainnet) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--verifier blockscout \
		--verifier-url $(MAIN_NET_VERIFIER_URL) \
		--force \
		--skip-simulation \
		--legacy; \
	else \
		echo "Error: .env file not found"; \
		exit 1; \
	fi