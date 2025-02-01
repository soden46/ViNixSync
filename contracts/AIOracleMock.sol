// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// This is a mock contract simulating the behavior of an AI Oracle.
// The contract contains a simple function that returns data as if it were an oracle providing real data.

contract AIOracleMock {
    // State variable to store the oracle address, immutable as it is set once in the constructor
    address public immutable oracleAddress;

    // Event to log the oracle data retrieval
    event OracleDataFetched(uint256 data);

    // Constructor that sets the oracle address to the contract's address
    constructor() {
        oracleAddress = address(this); // Set the oracle address to the contract's address
    }

    // Function that simulates retrieving data from the oracle.
    // In a real oracle, this function would return real data fetched from an off-chain source.
    function getOracleData() external returns (uint256) {
        uint256 data = 42; // Return a constant value to simulate oracle data
        emit OracleDataFetched(data); // Emit event for data retrieval
        return data; // Return the mocked data
    }

    // This function returns the address of the oracle contract
    function getOracleAddress() external view returns (address) {
        return oracleAddress; // Return the contract's address as the oracle address
    }
}
