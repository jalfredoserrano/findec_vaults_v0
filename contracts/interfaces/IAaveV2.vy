interface IAaveV2LendingPoolAddressProvider:
    def getLendingPool() -> address: view
    def getPriceOracle() -> address: view

interface IAaveV2WETHGateway:
    def depositETH(lendingPool: address, onBehalfOf: address, referralCode: uint256): payable
    def borrowETH(lendingPool: address, amount: uint256, interesRateMode: uint256, referralCode: uint256): nonpayable
    def repayETH(lendingPool: address, amount: uint256, rateMode: uint256, onBehalfOf: address): payable
    def withdrawETH(lendingPool: address, amount: uint256, to: address): nonpayable

interface IAaveV2LendingPool:
    def deposit(amount: uint256, onBehalfOf: address, referralCode: uint256): nonpayable
    def borrow(asset: address, amount: uint256, interestRateMode: uint256, referralCode: uint256, onBehalfOf: address): nonpayable
    def repay(asset: address, amount: uint256, rateMode: uint256, onBehalfOf: address): nonpayable
    def withdraw(asset: address, amount: uint256, to: address): nonpayable

interface IAaveV2Oracle:
    def getAssetPrice(asset: address) -> uint256: view
