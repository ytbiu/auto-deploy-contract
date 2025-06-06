// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {GovernorUpgradeable} from "../../governance/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeable} from "../../governance/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorCountingFractionalUpgradeable} from
    "../../governance/extensions/GovernorCountingFractionalUpgradeable.sol";
import {GovernorVotesQuorumFractionUpgradeable} from
    "../../governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

abstract contract GovernorFractionalMockUpgradeable is
    Initializable,
    GovernorSettingsUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorCountingFractionalUpgradeable
{
    function __GovernorFractionalMock_init() internal onlyInitializing {}

    function __GovernorFractionalMock_init_unchained() internal onlyInitializing {}

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
}
