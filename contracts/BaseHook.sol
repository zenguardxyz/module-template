// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.18;

import {ISafeProtocolPlugin} from "@safe-global/safe-core-protocol/contracts/interfaces/Integrations.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ISafeProtocolHooks} from "@safe-global/safe-core-protocol/contracts/interfaces/Integrations.sol";

enum MetadataProviderType {
    IPFS,
    URL,
    Contract,
    Event
}

interface IMetadataProvider {
    function retrieveMetadata(bytes32 metadataHash) external view returns (bytes memory metadata);
}

struct PluginMetadata {
    string name;
    string version;
    bool requiresRootAccess;
    string iconUrl;
    string appUrl;
    bool hook;
}

library PluginMetadataOps {
    function encode(PluginMetadata memory data) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(0x00), // Format
                uint8(0x00), // Format version
                abi.encode(data.name, data.version, data.requiresRootAccess, data.iconUrl, data.appUrl, data.hook) // Plugin Metadata
            );
    }

    function decode(bytes calldata data) internal pure returns (PluginMetadata memory) {
        require(bytes16(data[0:2]) == bytes16(0x0000), "Unsupported format or format version");
        (string memory name, string memory version, bool requiresRootAccess, string memory iconUrl, string memory appUrl,  bool hook) = abi.decode(
            data[2:],
            (string, string, bool, string, string, bool)
        );
        return PluginMetadata(name, version, requiresRootAccess, iconUrl, appUrl, hook);
    }
}

abstract contract BaseHook is ISafeProtocolHooks {
    using PluginMetadataOps for PluginMetadata;

    string public name;
    string public version;
    bool public immutable requiresRootAccess;
    bytes32 public immutable metadataHash;

    constructor(PluginMetadata memory metadata) {
        name = metadata.name;
        version = metadata.version;
        requiresRootAccess = metadata.requiresRootAccess;
        metadataHash = keccak256(metadata.encode());
    }

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return interfaceId == type(ISafeProtocolHooks).interfaceId || interfaceId == 0x01ffc9a7;
    }
}

abstract contract BaseHookWithStoredMetadata is BaseHook, IMetadataProvider {
    using PluginMetadataOps for PluginMetadata;

    bytes private encodedMetadata;

    constructor(PluginMetadata memory metadata) BaseHook(metadata) {
        encodedMetadata = metadata.encode();
    }

    function retrieveMetadata(bytes32 _metadataHash) external view override returns (bytes memory metadata) {
        require(metadataHash == _metadataHash, "Cannot retrieve metadata");
        return encodedMetadata;
    }

    function metadataProvider() public view returns (uint256 providerType, bytes memory location) {
        providerType = uint256(MetadataProviderType.Contract);
        location = abi.encode(address(this));
    }
}

abstract contract BaseHookWithEventMetadata is BaseHook {
    using PluginMetadataOps for PluginMetadata;

    event Metadata(bytes32 indexed metadataHash, bytes data);

    constructor(PluginMetadata memory metadata) BaseHook(metadata) {
        emit Metadata(metadataHash, metadata.encode());
    }

    function metadataProvider() public view returns (uint256 providerType, bytes memory location) {
        providerType = uint256(MetadataProviderType.Event);
        location = abi.encode(address(this));
    }
}
