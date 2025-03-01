// SPDX-License-Identifier: AGPL-3.0-or-later

/// join-8.sol -- Non-standard token adapters

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
// Copyright (C) 2018-2020 Maker Ecosystem Growth Holdings, INC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.12;

interface VatLike {
    function slip(bytes32, address, int256) external;
}

interface GemLike {
    function decimals() external view returns (uint8);
    function transfer(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
    function erc20Impl() external view returns (address);
}

// GemJoin8
// For a token that has a lower precision than 18, has decimals and it is upgradable (like GUSD)

contract GemJoin8 {
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth { wards[usr] = 1; }
    function deny(address usr) external auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    VatLike  public vat;
    bytes32  public ilk;
    GemLike  public gem;
    uint256  public dec;
    uint256  public live;  // Access Flag

    mapping (address => uint256) public implementations;

    constructor(address vat_, bytes32 ilk_, address gem_) public {
        gem = GemLike(gem_);
        dec = gem.decimals();
        require(dec < 18, "GemJoin8/decimals-18-or-higher");
        wards[msg.sender] = 1;
        live = 1;
        setImplementation(gem.erc20Impl(), 1);
        vat = VatLike(vat_);
        ilk = ilk_;
    }

    function cage() external auth {
        live = 0;
    }

    function setImplementation(address implementation, uint256 permitted) public auth {
        implementations[implementation] = permitted;  // 1 live, 0 disable
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "GemJoin8/overflow");
    }

    function join(address urn, uint256 amt) public {
        require(live == 1, "GemJoin8/not-live");
        uint256 wad = mul(amt, 10 ** (18 - dec));
        require(int256(wad) >= 0, "GemJoin8/overflow");
        require(implementations[gem.erc20Impl()] == 1, "GemJoin8/implementation-invalid");
        vat.slip(ilk, urn, int256(wad));
        require(gem.transferFrom(msg.sender, address(this), amt), "GemJoin8/failed-transfer");
    }

    function exit(address guy, uint256 amt) public {
        uint256 wad = mul(amt, 10 ** (18 - dec));
        require(int256(wad) >= 0, "GemJoin8/overflow");
        require(implementations[gem.erc20Impl()] == 1, "GemJoin8/implementation-invalid");
        vat.slip(ilk, msg.sender, -int256(wad));
        require(gem.transfer(guy, amt), "GemJoin8/failed-transfer");
    }
}
