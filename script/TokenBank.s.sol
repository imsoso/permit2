// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract DeployTokenBankScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address tokenAddress = 0x4c65bDEA9e905992731d5727F7Fe86EaD464518C;
        address tokenPermit = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

        TokenBank bank = new TokenBank(tokenAddress, tokenPermit);

        console2.log("TokenBank deployed at:", address(bank));

        vm.stopBroadcast();
    }
}
