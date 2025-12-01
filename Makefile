-include .env

deploy-anvil:
	forge script script/DeployProject.s.sol:DeployProjectLocal \
		--rpc-url $(ANVIL_RPC_URL) \
		--broadcast \
		--private-key $(ANVIL_PRIVATE_KEY) \
		-vvvv

deploy-sepolia:
	forge script script/DeployProject.s.sol:DeployProjectSepolia \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--broadcast \
		--verify \
    	--etherscan-api-key $(ETHERSCAN_API_KEY)

test-specific:
	forge test --mt $(TEST) -vvvv


