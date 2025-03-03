// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRebaseToken {
    function mint(address to, uint256 amount, uint256 interestRate) external;

    function burn(address from, uint256 amount) external;

    function balanceOf(address user) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function getUserInterestRate(address user) external view returns (uint256);

    function getPrincipleBalance(address user) external view returns (uint256);

    function getInterestRate() external view returns (uint256);

    function getUserLastUpdated(address user) external view returns (uint256);
}
