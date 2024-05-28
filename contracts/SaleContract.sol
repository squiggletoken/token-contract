// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./UniswapV2.sol";

contract SaleContract is Ownable, Pausable {
  struct Member {
    address account;
    uint256 totalAmount;
    uint256 claimedAmount;
    uint256 totalPaid;
    uint256 startTime;
    uint256 endTime;
  }

  struct Tier {
    string name;
    uint256 cooldownDuration;
    uint256 saleStartTime;
    uint256 salePrice;
    uint256 saleTotalAmount;
    uint256 saleBalance;
    uint256 saleMinPerWallet;
    uint256 saleMaxPerWallet;
    uint256 affiliateTotalAmount;
    uint256 affiliateBalance;
    uint256 affiliatePercent;
    uint256 tgePercent;
    uint256 cliffDuration;
    uint256 cliffPercent;
    uint256 linearDuration;
  }

  event Claimed(address account, uint256 amount);

  event NextSaleTier(uint saleTier, uint256 startTime);
  event SaleComplete(uint256 tgeTime);
  event Purchased(address account, uint tier, uint256 amount, uint256 totalPaid, uint256 salePrice);
  event Reward(address account, uint tier, uint256 amount);

  IERC20 token;
  IERC20 usdt;

  string public name = "Squiggle Sale Contract";

  uint256 public tgeTime;

  mapping(uint => Tier) public tiers;
  uint public currentTier;
  uint public countTiers;

  mapping(address => mapping(uint => Member)) public members;

  IUniswapV2Factory public liquidityFactory;
  IUniswapV2Router02 public liquidityRouter;
  address public liquidityPair;
  uint256 public liquidityUSDTPercent;
  uint256 public liquidityUSDT;
  uint256 public liquidityToken;

  /**
   * @dev Creates a sale contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _liquidityRouter UniswapV2Router address
   * @param _liquidityUSDTPercent 10,000 percentage to allocate to liquidity pool
   * @param _liquidityToken amount of token to allocate to liquidity pool
   */
  constructor(address _liquidityRouter, uint256 _liquidityUSDTPercent, uint256 _liquidityToken, Tier[] memory _tiers) Ownable(msg.sender) {
    liquidityRouter = IUniswapV2Router02(_liquidityRouter);
    liquidityFactory = IUniswapV2Factory(liquidityRouter.factory());
    liquidityUSDTPercent = _liquidityUSDTPercent;
    liquidityToken = _liquidityToken;
    for (uint i = 0; i < _tiers.length; i++) {
      addTier(_tiers[i]);
    }
  }

  function getTier(uint tier) public view returns (Tier memory) {
    return tiers[tier];
  }

  function getMember(address account, uint tier) public view returns (Member memory) {
    return members[account][tier];
  }
  
  function totalAmount(address addr) public view returns (uint256) {
    uint256 _totalAmount = 0;

    for (uint i = 0; i < countTiers; i++) {
      _totalAmount += members[addr][i].totalAmount;
    }
    
    return _totalAmount;
  }

  function remainingAmount(address addr) public view returns (uint256) {
    uint256 _claimedAmount = 0;

    for (uint i = 0; i < countTiers; i++) {
      _claimedAmount += members[addr][i].claimedAmount;
    }

    return _claimedAmount;
  }

  function totalPaid(address addr) public view returns (uint256) {
    uint256 _totalPaid = 0;

    for (uint i = 0; i < countTiers; i++) {
      _totalPaid += members[addr][i].totalPaid;
    }

    return _totalPaid;
  }

  /**
   * @dev Calculates the amount that has already vested but hasn't been released yet.
   */
  function claimableAmount(uint tier, address addr) public view returns (uint256) {
    uint256 vested = vestedAmount(tier, addr);

    if (vested < members[addr][tier].claimedAmount) {
      return 0;
    }

    return vested - members[addr][tier].claimedAmount;
  }

  function claimableAmountAllTiers(address addr) public view returns (uint256) {
    uint256 claimable = 0;

    for (uint i = 0; i < countTiers; i++) {
      claimable += claimableAmount(i, addr);
    }

    return claimable;
  }

  /**
   * @dev Calculates the amount that has already vested.
   */
  function vestedAmount(uint tier, address addr) public view returns (uint256) {
    uint256 timestamp = block.timestamp;
    
    if (address(token) == address(0)) {
      return 0;
    }

    if (tgeTime == 0) {
      return 0;
    }

    Member memory _member = members[addr][tier];
    Tier memory _tier = tiers[tier];

    if (timestamp < _member.startTime + tgeTime) {
      return 0;
    }

    uint256 _tgeAmount = (_member.totalAmount * _tier.tgePercent) / (100 * 10_000);
    uint256 _cliffTime = _member.startTime + tgeTime + _tier.cliffDuration;

    if (timestamp < _cliffTime) {
      return _tgeAmount;
    }

    if (_member.endTime != 0) {
      return _member.totalAmount;
    }

    if (timestamp >= (_cliffTime + _tier.linearDuration)) {
      return _member.totalAmount;
    }

    uint256 _cliffAmount = (_member.totalAmount * _tier.cliffPercent) / (100 * 10_000);

    uint256 _linearAmount = (_member.totalAmount - _tgeAmount) - _cliffAmount;
    _linearAmount = (_linearAmount * (timestamp - _cliffTime)) / _tier.linearDuration;

    uint256 _vestedAmount = _tgeAmount + _cliffAmount + _linearAmount;

    if (_vestedAmount > _member.totalAmount) {
      _vestedAmount = _member.totalAmount;
    }

    return _vestedAmount;
  }

  function claim() external {
    require(tgeTime != 0, "tgeTime has not been reached");
    uint256 _amountClaimed = 0;

    for (uint i = 0; i < countTiers; i++) {
      Member memory _member = members[msg.sender][i];

      uint256 claimable = claimableAmount(i, _member.account);

      require(_member.totalAmount >= (_member.claimedAmount + claimable), "token pool exhausted");

      if (claimable > 0) {
        if (claimable > token.balanceOf(address(this))) {
          claimable = token.balanceOf(address(this));
        }
        
        _member.claimedAmount += claimable;

        if (_member.claimedAmount == _member.totalAmount) {
          _member.endTime = block.timestamp;
        }

        members[msg.sender][i] = _member;

        _amountClaimed += claimable;
      }
    }

    if (_amountClaimed > 0) {
      token.transfer(msg.sender, _amountClaimed);
      emit Claimed(msg.sender, _amountClaimed);
    }
  }

  function _advanceTier() internal whenNotPaused() {
    if (currentTier + 1 < countTiers) {
      tiers[currentTier + 1].saleStartTime = block.timestamp + tiers[currentTier].cooldownDuration;
      tiers[currentTier + 1].saleTotalAmount += tiers[currentTier].saleBalance;
      tiers[currentTier].saleBalance = 0;
      currentTier++;
      emit NextSaleTier(currentTier, tiers[currentTier].saleStartTime);
    } else {
      tgeTime = block.timestamp + tiers[currentTier].cooldownDuration;
      currentTier++;
      
      // allow usdt and token
      usdt.approve(address(liquidityRouter), liquidityUSDT);
      token.approve(address(liquidityRouter), liquidityToken);

      // launch liquidity pool
      liquidityRouter.addLiquidity(
        address(usdt),
        address(token),
        liquidityUSDT,
        liquidityToken,
        liquidityUSDT,
        liquidityToken,
        address(this),
        block.timestamp
      );

      // get liquidity pair
      liquidityPair = liquidityFactory.getPair(address(usdt), address(token));
      IUniswapV2Pair pair = IUniswapV2Pair(liquidityPair);

      // burn liquidity tokens
      pair.transfer(address(0), pair.balanceOf(address(this)));

      // set in-contract balances to zero so we can recover the remainder
      liquidityUSDT = 0;
      liquidityToken = 0;

      emit SaleComplete(tgeTime);
    }
  }

  function purchase(address affiliate, uint256 tokenAmount) external whenNotPaused() {
    Tier memory tier = tiers[currentTier];

    uint256 _balance = tier.saleBalance;

    require(block.timestamp >= tier.saleStartTime, "sale has not yet started");
    require(tgeTime == 0, "sale has finished");
    require(address(usdt) != address(0), 'usdt not initialized');
    require(tokenAmount <= _balance, 'allocation would exceed remaining balance');
    require(affiliate == address(0) || affiliate != msg.sender, 'affiliate cannot be msg.sender');
    require(usdt.allowance(msg.sender, address(this)) >= (tokenAmount * tier.salePrice) / (10**18), 'sale price exceeds usdt allowance');

    Member memory _member = members[msg.sender][currentTier];

    require(_member.totalAmount + tokenAmount <= tier.saleMaxPerWallet, 'allocation would exceed saleMaxPerWallet');
    require(_member.totalAmount + tokenAmount >= tier.saleMinPerWallet, 'allocation does not meet saleMinPerWallet');

    if (_member.account == address(0)) {
      _member.account = msg.sender;
      _member.startTime = 0;
    }

    uint256 toPay = (tokenAmount * tier.salePrice) / (10**18);

    require(usdt.transferFrom(msg.sender, address(this), toPay), 'transfer failed');

    _member.endTime = 0;
    _member.totalAmount += tokenAmount;
    _member.totalPaid += toPay;
    tier.saleBalance -= tokenAmount;

    liquidityUSDT += (toPay * liquidityUSDTPercent) / (100 * 10_000);

    members[msg.sender][currentTier] = _member;

    if (affiliate != address(0)) {
      _member = members[affiliate][currentTier];

      if (_member.account == address(0)) {
        _member.account = affiliate;
        _member.startTime = 0;
      }

      _member.endTime = 0;
      uint256 affiliateAmount = (tokenAmount * tier.affiliatePercent) / (100 * 10_000);

      if (tier.affiliateBalance < affiliateAmount) {
        affiliateAmount = tier.affiliateBalance;
      }

      if (affiliateAmount > tier.affiliateBalance) {
        affiliateAmount = tier.affiliateBalance;
      }

      _member.totalAmount += affiliateAmount;
      tier.affiliateBalance -= affiliateAmount;

      emit Reward(affiliate, currentTier, affiliateAmount);

      members[affiliate][currentTier] = _member;
    }

    tiers[currentTier] = tier;

    emit Purchased(msg.sender, currentTier, tokenAmount, toPay, tier.salePrice);

    if (tier.saleBalance <= tier.saleMinPerWallet) {
      _advanceTier();
    }
  }

  function surplusTokens() public view returns (uint256) {
    if (tgeTime == 0) {
      return 0;
    }

    uint256 _surplusTokens = 0;

    for (uint i = 0; i < countTiers; i++) {
      _surplusTokens += tiers[i].saleBalance + tiers[i].affiliateBalance;
    }

    if (_surplusTokens > token.balanceOf(address(this))) {
      _surplusTokens = token.balanceOf(address(this));
    }

    return _surplusTokens;
  }

  function withdrawSurplusTokens(address account) external onlyOwner {
    token.transfer(account, surplusTokens());
  }

  function saleBalance() public view returns (uint256) {
    return usdt.balanceOf(address(this)) - liquidityUSDT;
  }

  function withdrawPartialSaleBalance(address account, uint256 amount) external onlyOwner {
    require(amount <= saleBalance(), "amount exceeds sale balance");

    usdt.transfer(account, amount);
  }

  function withdrawSaleBalance(address account) external onlyOwner() {
    usdt.transfer(account, saleBalance());
  }

  function withdrawErc20(address _erc, address account) external onlyOwner {
    require(_erc != address(token), "cannot withdraw token");
    IERC20 _token = IERC20(_erc);
    _token.transfer(account, _token.balanceOf(address(this)));
  }

  function withdrawEth(address payable account) external onlyOwner() {
    account.transfer(address(this).balance);
  }

  function setToken(address _erc) external onlyOwner {
    token = IERC20(_erc);
  }

  function setUSDT(address _erc) external onlyOwner {
    usdt = IERC20(_erc);
  }

  function addTier(Tier memory _tier) internal {
    tiers[countTiers] = _tier;
    countTiers++;
  }

  function emergencyWithdraw(address _erc, address account, uint256 amount) external onlyOwner {
    IERC20 _token = IERC20(_erc);
    _token.transfer(account, amount);
  }
}