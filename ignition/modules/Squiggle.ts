import { AccountRuntimeValue, CallableContractFuture, buildModule } from "@nomicfoundation/ignition-core";
import assert from "assert";

export interface SaleTier {
  id: string;
  type: 'sale';
  address?: CallableContractFuture<string>;
  name: string;

  // timings
  cooldownDuration: bigint;
  saleStartTime: bigint; // set to zero for other tiers than first tier

  // sale price in usdt
  salePrice: bigint;

  // total number of tokens
  tokens: bigint;

  // min/max per wallet
  saleMinPerWallet: bigint;
  saleMaxPerWallet: bigint;

  // affiliates
  affiliateTotalAmount: bigint;
  affiliatePercent: bigint;

  // vesting
  tgePercent: bigint;
  cliffDuration: bigint;
  cliffPercent: bigint;
  linearDuration: bigint;
}

export interface LiquidityAllocation {
  id: string;
  type: 'liquidity';
  address?: CallableContractFuture<string>;
  tokens: bigint;
}

export interface VestingAllocation {
  id: string;
  type: 'vesting';
  address?: CallableContractFuture<string>;
  name: string;
  tokens: bigint;
  tgePercent: bigint;
  cliffDuration: bigint;
  cliffPercent: bigint;
  linearDuration: bigint;
}

export interface AccountAllocation {
  id: string;
  type: 'account';
  address: AccountRuntimeValue | string;
  tokens: bigint;
}

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

export default buildModule('Squiggle', m => {
  let allocations: (SaleTier | LiquidityAllocation | VestingAllocation | AccountAllocation)[];

  const totalSupply = 343434343434343434343434343434n;
  const decimals = 18n;
  const usdtDecimals = 18n;
  let USDT: any;
  let PancakeSwapRouter: any;

  if (process.env.NODE_ENV !== 'production') {
    USDT = m.contract('USDT');
  } else {
    USDT = m.contractAt('IERC20', process.env.BSC_USDT_ADDRESS!);
  }

  const liquidityDEXPercent = 1.5;
  const percentage = (percent: number) => (totalSupply * BigInt((percent * 100_000_000).toFixed(0))) / (100n * 100_000_000n);
  const usdt = (dollars: number) => (BigInt((dollars * 1_000_000).toFixed(0)) * 10n**usdtDecimals) / 1_000_000n;
  const date = (isoDate: string) => new Date(isoDate).getTime() / 1000;
  const months = (months: number) => months * 28 * 24 * 3600;
  const cooldownDuration = 0n;
  const months2 = 2n * 31n * 24n * 3600n
  const months4 = 4n * 31n * 24n * 3600n
  const months12 = 12n * 31n * 24n * 3600n
  const months24 = 24n * 31n * 24n * 3600n
  const months36 = 36n * 31n * 24n * 3600n


  allocations = [
    {
      id: 'seed_sale_1',
      type: 'sale',
      name: 'Seed Sale Tier 1',
      cooldownDuration,
      saleStartTime: BigInt(new Date('2024-05-31T15:43:34Z').getTime()) / 1000n,
      salePrice: usdt(0.000034),
      tokens: percentage(0.5 / 1.1),
      saleMinPerWallet: 1_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(0.5),
      affiliateTotalAmount: percentage(0.5) - percentage(0.5 / 1.1),
      affiliatePercent: 10n * 10_000n,
      tgePercent: 3n * 10_000n,
      cliffDuration: months2,
      cliffPercent: 10n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'seed_sale_2',
      type: 'sale',
      name: 'Seed Sale Tier 2',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000038),
      tokens: percentage(0.75 / 1.0975),
      saleMinPerWallet: 5_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(0.75),
      affiliateTotalAmount: percentage(0.75) - percentage(0.75 / 1.0975),
      affiliatePercent: 975n * 100n,
      tgePercent: 325n * 100n,
      cliffDuration: months2,
      cliffPercent: 10n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'seed_sale_3',
      type: 'sale',
      name: 'Seed Sale Tier 3',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000044),
      tokens: percentage(1.25 / 1.0950),
      saleMinPerWallet: 5_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(1.25),
      affiliateTotalAmount: percentage(1.25) - percentage(1.25 / 1.0950),
      affiliatePercent: 950n * 100n,
      tgePercent: 350n * 100n,
      cliffDuration: months2,
      cliffPercent: 10n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'seed_sale_4',
      type: 'sale',
      name: 'Seed Sale Tier 4',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000050),
      tokens: percentage(1.50 / 1.0925),
      saleMinPerWallet: 5_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(1.50),
      affiliateTotalAmount: percentage(1.50) - percentage(1.50 / 1.0925),
      affiliatePercent: 925n * 100n,
      tgePercent: 375n * 100n,
      cliffDuration: months2,
      cliffPercent: 10n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_1',
      type: 'sale',
      name: 'Public Sale Tier 1',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000057),
      tokens: percentage(1.75 / 1.0900),
      saleMinPerWallet: 5_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(1.75),
      affiliateTotalAmount: percentage(1.75) - percentage(1.75 / 1.0900),
      affiliatePercent: 900n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_2',
      type: 'sale',
      name: 'Public Sale Tier 2',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000064),
      tokens: percentage(2.00 / 1.0875),
      saleMinPerWallet: 5_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(2.00),
      affiliateTotalAmount: percentage(2.00) - percentage(2.00 / 1.0875),
      affiliatePercent: 875n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_3',
      type: 'sale',
      name: 'Public Sale Tier 3',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000073),
      tokens: percentage(2.25 / 1.0850),
      saleMinPerWallet: 1_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(2.25),
      affiliateTotalAmount: percentage(2.25) - percentage(2.25 / 1.0850),
      affiliatePercent: 850n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_4',
      type: 'sale',
      name: 'Public Sale Tier 4',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000083),
      tokens: percentage(2.50 / 1.0800),
      saleMinPerWallet: 1_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(2.50),
      affiliateTotalAmount: percentage(2.50) - percentage(2.50 / 1.0800),
      affiliatePercent: 800n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_5',
      type: 'sale',
      name: 'Public Sale Tier 5',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000094),
      tokens: percentage(3.00 / 1.0750),
      saleMinPerWallet: 1_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(3.00),
      affiliateTotalAmount: percentage(3.00) - percentage(3.00 / 1.0750),
      affiliatePercent: 750n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_6',
      type: 'sale',
      name: 'Public Sale Tier 6',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000107),
      tokens: percentage(3.50 / 1.0700),
      saleMinPerWallet: 1_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(3.50),
      affiliateTotalAmount: percentage(3.50) - percentage(3.50 / 1.0700),
      affiliatePercent: 700n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_7',
      type: 'sale',
      name: 'Public Sale Tier 7',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000121),
      tokens: percentage(4.00 / 1.0675),
      saleMinPerWallet: 1_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(4.00),
      affiliateTotalAmount: percentage(4.00) - percentage(4.00 / 1.0675),
      affiliatePercent: 675n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_8',
      type: 'sale',
      name: 'Public Sale Tier 8',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000137),
      tokens: percentage(4.50 / 1.0650),
      saleMinPerWallet: 1_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(4.50),
      affiliateTotalAmount: percentage(4.50) - percentage(4.50 / 1.0650),
      affiliatePercent: 650n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_9',
      type: 'sale',
      name: 'Public Sale Tier 9',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000156),
      tokens: percentage(5.00 / 1.0625),
      saleMinPerWallet: 1_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(5.00),
      affiliateTotalAmount: percentage(5.00) - percentage(5.00 / 1.0625),
      affiliatePercent: 625n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_10',
      type: 'sale',
      name: 'Public Sale Tier 10',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000177),
      tokens: percentage(5.50 / 1.0600),
      saleMinPerWallet: 1_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(5.50),
      affiliateTotalAmount: percentage(5.50) - percentage(5.50 / 1.0600),
      affiliatePercent: 600n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_11',
      type: 'sale',
      name: 'Public Sale Tier 11',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000201),
      tokens: percentage(5.50 / 1.0575),
      saleMinPerWallet: 1_000_000n * 10n**18n,
      saleMaxPerWallet: percentage(5.50),
      affiliateTotalAmount: percentage(5.50) - percentage(5.50 / 1.0575),
      affiliatePercent: 575n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_12',
      type: 'sale',
      name: 'Public Sale Tier 12',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000227),
      tokens: percentage(5.50 / 1.0550),
      saleMinPerWallet: 500_000n * 10n**18n,
      saleMaxPerWallet: percentage(5.50),
      affiliateTotalAmount: percentage(5.50) - percentage(5.50 / 1.0550),
      affiliatePercent: 550n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_13',
      type: 'sale',
      name: 'Public Sale Tier 13',
      cooldownDuration,
      saleStartTime: 0n,
      salePrice: usdt(0.000258),
      tokens: percentage(5.50 / 1.0525),
      saleMinPerWallet: 500_000n * 10n**18n,
      saleMaxPerWallet: percentage(5.50),
      affiliateTotalAmount: percentage(5.50) - percentage(5.50 / 1.0525),
      affiliatePercent: 525n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'public_sale_14',
      type: 'sale',
      name: 'Public Sale Tier 14',
      cooldownDuration: 0n,
      saleStartTime: 0n,
      salePrice: usdt(0.000293),
      tokens: percentage(5.50 / 1.0500),
      saleMinPerWallet: 500_000n * 10n**18n,
      saleMaxPerWallet: percentage(5.50),
      affiliateTotalAmount: percentage(5.50) - percentage(5.50 / 1.0500),
      affiliatePercent: 500n * 100n,
      tgePercent: 500n * 100n,
      cliffDuration: months4,
      cliffPercent: 5n * 10_000n,
      linearDuration: months12,
    },
    {
      id: 'team',
      type: 'vesting',
      name: 'Squiggle Monster Team Pool',
      tokens: percentage(18),
      tgePercent: 0n,
      cliffDuration: months4,
      cliffPercent: 10n * 10_000n,
      linearDuration: months36,
    },
    {
      id: 'airdrop',
      type: 'vesting',
      name: 'Squiggle Monster Airdrops',
      tokens: percentage(1),
      tgePercent: 3n * 10_000n,
      cliffDuration: months4,
      cliffPercent: 10n * 10_000n,
      linearDuration: months24,
    },
    {
      id: 'marketing',
      type: 'vesting',
      name: 'Squiggle Monster Marketing Pool',
      tokens: percentage(6),
      tgePercent: 5n * 10_000n,
      cliffDuration: months4,
      cliffPercent: 10n * 10_000n,
      linearDuration: months24,
    },
    {
      id: 'liquidity_cex',
      type: 'account',
      address: '0x03d1ECec6513Da227C94Ca6E9a04BcB04A777D32',
      tokens: percentage(15) - percentage(liquidityDEXPercent)
    },
  ];

  const totalAllocated = allocations.reduce((a, b) => {
    if (b.type === 'sale') {
      return a + b.tokens + b.affiliateTotalAmount;
    } else {
      return a + b.tokens;
    }
  }, 0n);

  assert(totalAllocated < totalSupply, `allocations must add up to ${totalSupply} but is ${totalAllocated}`);

  allocations.push({
    id: 'liquidity_dex',
    type: 'liquidity',
    tokens: totalSupply - totalAllocated,
  });

  console.info(totalAllocated)

  const vestingContracts: CallableContractFuture<string>[] = [];

  const saleContract = m.contract('SaleContract', [
    process.env.BSC_LIQUIDITY_ROUTER!,
    57031n, // 5.7031%
    totalSupply - totalAllocated,
    allocations.filter(a => a.type === 'sale').map((allocation: any) => ({
      name: allocation.name,
      cooldownDuration: allocation.cooldownDuration,
      saleStartTime: allocation.saleStartTime,
      salePrice: allocation.salePrice,
      saleTotalAmount: allocation.tokens,
      saleBalance: allocation.tokens,
      saleMinPerWallet: allocation.saleMinPerWallet,
      saleMaxPerWallet: allocation.saleMaxPerWallet,
      affiliateTotalAmount: allocation.affiliateTotalAmount,
      affiliateBalance: allocation.affiliateTotalAmount,
      affiliatePercent: allocation.affiliatePercent,
      tgePercent: allocation.tgePercent,
      cliffDuration: allocation.cliffDuration,
      cliffPercent: allocation.cliffPercent,
      linearDuration: allocation.linearDuration,
    }))
  ], { id: 'SaleContract' })
  
  for (const allocation of allocations) {
    if (allocation.type === 'sale' || allocation.type === 'liquidity') {
      allocation.address = saleContract;
    } else if (allocation.type === 'vesting') {
      const vestingContract = m.contract('VestingContract', [
        allocation.name,
        saleContract,
        allocation.tgePercent,
        allocation.cliffDuration,
        allocation.cliffPercent,
        allocation.linearDuration,
      ], { id: allocation.id });

      allocation.address = vestingContract;
      vestingContracts.push(vestingContract);
    }
  }

  const addresses = allocations.filter(a => a.type === 'vesting' || a.type === 'account').map(a => a.address!);
  const tokens = allocations.filter(a => a.type === 'vesting' || a.type === 'account').map(a => a.tokens);

  const squiggle = m.contract('Squiggle', [
    [
      ...addresses,
      saleContract,
    ],
    [
      ...tokens,
      allocations.filter(a => a.type === 'sale' || a.type === 'liquidity').reduce((a, b) => {
        if (b.type === 'sale') {
          return a + b.tokens + b.affiliateTotalAmount;
        } else {
          return a + b.tokens;
        }
      }, 0n)
    ],
  ], { id: 'squiggle' });

  for (const allocation of allocations) {
    if (allocation.type === 'vesting') {
      m.call(allocation.address!, 'setToken', [squiggle]);
    }
  }
  m.call(saleContract, 'setToken', [squiggle]);
  m.call(saleContract, 'setUSDT', [USDT]);

  return { squiggle, saleContract, usdt: USDT, ...allocations.filter(b => b.type === 'vesting').reduce((a, b) => ({ ...a, [(b as any).id]: b.address }), {}) };
})