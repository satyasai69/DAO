// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private s_number;

    event NumberChanged(uint256 number);

    constructor() {}

    function store(uint256 newName) public onlyOwner {
        s_number = newName;
        emit NumberChanged(newName);
    }

    function getNumber() public view returns (uint256) {
        return s_number;
    }
}
