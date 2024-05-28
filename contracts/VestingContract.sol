// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SaleContract.sol";

contract VestingContract is Ownable {
  struct Member {
    address account;
    uint256 totalAmount;
    uint256 claimedAmount;
    uint256 startTime;
    uint256 endTime;
  }

  event Claimed(address account, uint256 amount);

  event Added(address account, uint256 amount);
  event Removed(address account, uint256 amount);

  IERC20 token;
  SaleContract saleContract;

  string public name;

  mapping(address => Member) public members;

  address public claimProxy;

  uint256 public tgePercent;
  uint256 public cliffDuration;
  uint256 public cliffPercent;
  uint256 public linearDuration;

  uint256 public allocatedAmount;

  /**
   * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _name beneficiary of tokens after they are released
   * @param _saleContract address of the sale contract to base tgeTime calculations from
   * @param _cliffDuration duration in seconds of the cliff in which tokens will begin to vest
   * @param _cliffPercent dd
   * @param _linearDuration duration in seconds of the period in which the tokens will vest
   */
  constructor(
    string memory _name,
    address _saleContract,
    uint256 _tgePercent,
    uint256 _cliffDuration,
    uint256 _cliffPercent,
    uint256 _linearDuration
  ) Ownable(msg.sender) {
    require(_saleContract != address(0), "invalid tgeTime");

    name = _name;
    saleContract = SaleContract(_saleContract);
    tgePercent = _tgePercent;
    cliffDuration = _cliffDuration;
    cliffPercent = _cliffPercent;
    linearDuration = _linearDuration;
  }

  modifier onlyMember(address account) {
    require(members[account].account != address(0), "You are not a valid member");
    _;
  }

  function tgeTime() public view returns (uint256) {
    uint256 _tgeTime = saleContract.tgeTime();
    return _tgeTime;
  }
  
  function balance() public view returns (uint256) {
    require(address(token) != address(0), "token has not been set");

    uint256 _balance = token.balanceOf(address(this));
    _balance -= allocatedAmount;
    return _balance;
  }

  function totalAmount(address addr) public view returns (uint256) {
    Member memory _member = members[addr];

    return _member.totalAmount;
  }

  function remainingAmount(address addr) public view returns (uint256) {
    Member memory _member = members[addr];

    return _member.totalAmount - _member.claimedAmount;
  }

  /**
   * @dev Calculates the amount that has already vested but hasn't been released yet.
   */
  function claimableAmount(address addr) public view returns (uint256) {
    Member memory _member = members[addr];

    uint256 vested = vestedAmount(addr);

    if (vested < _member.claimedAmount) {
      return 0;
    }

    return vested - _member.claimedAmount;
  }

  /**
   * @dev Calculates the amount that has already vested.
   */
  function vestedAmount(address addr) public view returns (uint256) {
    uint256 timestamp = block.timestamp;

    if (address(token) == address(0)) {
      return 0;
    }

    uint256 tgeTime = saleContract.tgeTime();

    if (tgeTime == 0) {
      return 0;
    }

    Member memory _member = members[addr];

    if (timestamp < _member.startTime + tgeTime) {
      return 0;
    }

    uint256 _tgeAmount = (_member.totalAmount * tgePercent) / (100 * 10_000);
    uint256 _cliffTime = _member.startTime + tgeTime + cliffDuration;

    if (timestamp < _cliffTime) {
      return _tgeAmount;
    }

    if (_member.endTime != 0) {
      return _member.totalAmount;
    }

    if (timestamp >= (_cliffTime + linearDuration)) {
      return _member.totalAmount;
    }

    uint256 _cliffAmount = (_member.totalAmount * cliffPercent) / (100 * 10_000);

    uint256 _linearAmount = (_member.totalAmount - _tgeAmount) - _cliffAmount;
    _linearAmount = (_linearAmount * (timestamp - _cliffTime)) / linearDuration;

    uint256 _vestedAmount = _tgeAmount + _cliffAmount + _linearAmount;

    if (_vestedAmount > _member.totalAmount) {
      _vestedAmount = _member.totalAmount;
    }

    return _vestedAmount;
  }

  function claim() external onlyMember(msg.sender) {
    Member memory _member = members[msg.sender];

    uint256 claimable = claimableAmount(_member.account);

    require(claimable > 0, "no tokens claimable");
    require(_member.totalAmount >= (_member.claimedAmount + claimable), "token pool exhausted");

    token.transfer(_member.account, claimable);
    _member.claimedAmount += claimable;
    allocatedAmount -= claimable;

    members[msg.sender] = _member;

    emit Claimed(_member.account, claimable);
  }

  function addMembers(address[] calldata addrs, uint256[] calldata tokenAmounts) external onlyOwner {
    uint256 _balance = balance();

    uint256 tgeTime = saleContract.tgeTime();

    for (uint256 i = 0; i < addrs.length; i++) {
      require(tokenAmounts[i] <= _balance, 'allocation would exceed remaining balance');

      Member memory _member = members[addrs[i]];

      if (_member.account == address(0)) {
        _member.account = addrs[i];

        if (block.timestamp < tgeTime) {
          _member.startTime = 0;
        } else {
          _member.startTime = block.timestamp - tgeTime;
        }
      }

      _member.endTime = 0;
      _member.totalAmount += tokenAmounts[i];
      allocatedAmount += tokenAmounts[i];
      _balance -= tokenAmounts[i];

      members[addrs[i]] = _member;

      emit Added(addrs[i], tokenAmounts[i]);
    }
  }

  function removeMember(address addr) external onlyOwner {
    Member memory _member = members[addr];

    uint256 remaining = _member.totalAmount;
    _member.totalAmount = _member.claimedAmount + claimableAmount(addr);
    remaining -= _member.totalAmount;
    allocatedAmount -= remaining;

    _member.endTime = block.timestamp;

    members[addr] = _member;

    emit Removed(addr, remaining);
  }

  function withdrawErc20(address _erc, address account) external onlyOwner {
    IERC20 _token = IERC20(_erc);
    _token.transfer(account, _token.balanceOf(address(this)));
  }

  function withdrawEth(address payable account) external onlyOwner() {
    account.transfer(address(this).balance);
  }

  function setToken(address _erc) external onlyOwner {
    token = IERC20(_erc);
  }

  function emergencyWithdraw(address _erc, address account, uint256 amount) external onlyOwner {
    IERC20 _token = IERC20(_erc);
    _token.transfer(account, amount);
  }
}