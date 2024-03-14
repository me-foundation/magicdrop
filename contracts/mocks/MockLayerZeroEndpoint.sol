// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ILayerZeroEndpoint} from "@layerzerolabs/solidity-examples/contracts/interfaces/ILayerZeroEndpoint.sol";

contract MockLayerZeroEndpoint is ILayerZeroEndpoint {
    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable {
        // do nothing
    }

    function receivePayload(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        address _dstAddress,
        uint64 _nonce,
        uint256 _gasLimit,
        bytes calldata _payload
    ) external {
        // do nothing
    }

    function getInboundNonce(
        uint16 _srcChainId,
        bytes calldata _srcAddress
    ) external view returns (uint64) {
        return 0;
    }

    function getOutboundNonce(
        uint16 _dstChainId,
        address _srcAddress
    ) external view returns (uint64) {
        return 0;
    }

    function estimateFees(
        uint16 _dstChainId,
        address _userApplication,
        bytes calldata _payload,
        bool _payInZRO,
        bytes calldata _adapterParam
    ) external view returns (uint256 nativeFee, uint256 zroFee) {
        return (0, 0);
    }

    function getChainId() external view returns (uint16) {
        return 0;
    }

    function retryPayload(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        bytes calldata _payload
    ) external {
        // do nothing
    }

    function hasStoredPayload(
        uint16 _srcChainId,
        bytes calldata _srcAddress
    ) external view returns (bool) {
        return false;
    }

    function getSendLibraryAddress(
        address _userApplication
    ) external view returns (address) {
        return address(0);
    }

    function getReceiveLibraryAddress(
        address _userApplication
    ) external view returns (address) {
        return address(0);
    }

    function isSendingPayload() external view returns (bool) {
        return false;
    }

    function isReceivingPayload() external view returns (bool) {
        return false;
    }

    function getConfig(
        uint16 _version,
        uint16 _chainId,
        address _userApplication,
        uint256 _configType
    ) external view returns (bytes memory) {
        return "";
    }

    function getSendVersion(
        address _userApplication
    ) external view returns (uint16) {
        return 0;
    }

    function getReceiveVersion(
        address _userApplication
    ) external view returns (uint16) {
        return 0;
    }

    function setConfig(
        uint16 _version,
        uint16 _chainId,
        uint256 _configType,
        bytes calldata _config
    ) external {
        // do nothing
    }

    function setSendVersion(uint16 _version) external {
        // do nothing
    }

    function setReceiveVersion(uint16 _version) external {
        // do nothing
    }

    function forceResumeReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress
    ) external {
        // do nothing
    }
}
