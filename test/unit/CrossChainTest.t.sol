// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {RebaseTokenPool} from "../../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {CCIPLocalSimulatorFork} from "@chainlink-local/ccip/CCIPLocalSimulatorFork.sol";
import "@chainlink-local/ccip/Register.sol";
import {BurnMintERC677Helper} from "@chainlink-local/ccip/BurnMintERC677Helper.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

contract CrossChainTest is Test {
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;
    BurnMintERC677Helper destinationCCIPBnMToken;
    uint64 destinationChainSelector;
    BurnMintERC677Helper sourceCCIPBnMToken;
    IERC20 sourceLinkToken;
    IRouterClient sourceRouter;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    RebaseToken sepoliaToken;
    RebaseTokenPool sepoliaPool;
    RebaseToken arbSepoliaToken;
    RebaseTokenPool arbSepoliaPool;
    Vault vault;
    uint256 amount = 100 ether;
    uint256 constant SEND_VALUE = 1e5;

    address bob = makeAddr("bob");
    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address user = makeAddr("user");

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia-eth");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // Deploy and configure on sepolia
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));

        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        sepoliaToken.grantMintAndBurnRole(address(vault));

        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(sepoliaToken)
        );

        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));

        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(sepoliaToken), address(sepoliaPool)
        );

        vm.stopPrank();

        // Deploy and configure on arbitrum sepolia
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);

        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        arbSepoliaToken = new RebaseToken();

        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );

        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));

        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(arbSepoliaToken)
        );

        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));

        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(arbSepoliaToken), address(arbSepoliaPool)
        );

        vm.stopPrank();

        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaPool),
            address(arbSepoliaToken)
        );

        configureTokenPool(
            arbSepoliaFork,
            address(arbSepoliaPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaPool),
            address(sepoliaToken)
        );

        console.log("END SETUP");
    }

    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteTokenAddress
    ) private {
        console.log("START CONFIGURE");

        vm.selectFork(fork);
        vm.prank(owner);
        TokenPool.ChainUpdate[] memory chainsIdToAdd = new TokenPool.ChainUpdate[](1);
        bytes memory remotePoolAddressBytes = abi.encode(remotePool);
        bytes memory remoteTokenAddressBytes = abi.encode(remoteTokenAddress);

        chainsIdToAdd[0] = TokenPool.ChainUpdate({
            allowed: true,
            remoteChainSelector: remoteChainSelector,
            remotePoolAddress: remotePoolAddressBytes,
            remoteTokenAddress: remoteTokenAddressBytes,
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });

        TokenPool(localPool).applyChainUpdates(chainsIdToAdd);
        console.log("END CONFIGURE");
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        console.log("START BRIDGE");
        vm.selectFork(localFork);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 1_000_000}))
        });

        uint256 fee =
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);

        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);

        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);

        vm.prank(user);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, fee);

        uint256 localBalanceBefore = localToken.balanceOf(user);

        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);

        uint256 localBalanceAfter = localToken.balanceOf(user);

        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);

        uint256 localUserInterestRate = localToken.getUserInterestRate(user);

        /* REMOTE CHAIN */

        vm.selectFork(remoteFork);

        vm.roll(block.timestamp + 20 minutes);

        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);

        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);

        uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);

        assertEq(remoteUserInterestRate, localUserInterestRate);
        console.log("END BRIDGE");
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);

        vm.startPrank(user);
        vault.deposit{value: SEND_VALUE}();

        assertEq(sepoliaToken.balanceOf(user), SEND_VALUE);

        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaToken,
            arbSepoliaToken
        );


    }
}
