// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestUsdc is ERC20 {
    constructor(address _owner) ERC20("USDC", "USDC") {
        _mint(_owner, 1000000 * 1e6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
