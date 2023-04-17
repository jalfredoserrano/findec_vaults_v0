from vyper.interfaces import ERC20

######################################
#            INTERFACES 
######################################
interface StrategyV1StableVariable:
    def withdraw(assets: uint256): nonpayable   
    def totalBalance() -> uint256: view


######################################
#               ERC20 
######################################

totalSupply: public(uint256)
balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])

NAME: constant(String[10]) = "DynHdgVlt"
SYMBOL: constant(String[5]) = "fdVlt"
DECIMALS: constant(uint8) = 18

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    amount: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    allowance: uint256

######################################
#               ERC4626 
######################################

strategy_address: public(address)
Strategy: public(StrategyV1StableVariable)
asset: public(address)
Iasset: public(ERC20)
depositFee: constant(uint256) = 10
BASE_UNIT: constant(uint256) = 10000
performanceFees: constant(decimal) = 0.15
entrySharePrice: public(HashMap[address, decimal])

event Deposit:
    depositor: indexed(address)
    receiver: indexed(address)
    assets: uint256
    shares: uint256

event Withdraw:
    withdrawer: indexed(address)
    receiver: indexed(address)
    owner: indexed(address)
    assets: uint256
    shares: uint256

# Admin
paused: public(bool)
owner: public(address)
initialized: public(bool)

@external
def __init__(_asset: address):
    self.asset = _asset
    self.Iasset = ERC20(_asset)
    self.paused = False
    self.initialized = False
    self.owner = msg.sender

@external
def initializeVault(_strategy: address):
    assert msg.sender == self.owner, "!owner"
    assert self.initialized == False, "vaut already initialized"
    self.strategy_address = _strategy
    self.Strategy = StrategyV1StableVariable(_strategy)
    self.initialized = True

######################################
#               ERC20 
######################################

@view
@external
def name() -> String[10]:
    return NAME

@view
@external
def symbol() -> String[5]:
    return SYMBOL

@view
@external
def decimals() -> uint8:
    return DECIMALS

@external
def transfer(receiver: address, amount: uint256) -> bool:
    self.balanceOf[msg.sender] -= amount
    self.balanceOf[receiver] += amount
    log Transfer(msg.sender, receiver, amount)
    return True

@external
def approve(spender: address, amount: uint256) -> bool:
    self.allowance[msg.sender][spender] = amount
    log Approval(msg.sender, spender, amount)
    return True

@external
def transferFrom(sender: address, receiver: address, amount: uint256) -> bool:
    self.allowance[sender][msg.sender] -= amount
    self.balanceOf[sender] -= amount
    self.balanceOf[receiver] += amount
    log Transfer(sender, receiver, amount)
    return True

######################################
#       ERC4626 - Accounting Logic
######################################

@view
@internal
def _totalAssets() -> uint256:
    return self.Strategy.totalBalance()

@view
@external
def totalAssets() -> uint256:
    return self._totalAssets()

@view
@internal
def _convertToAssets(shareAmount: uint256) -> uint256:
    totalSupply: uint256 = self.totalSupply
    if totalSupply == 0:
        return 0

    # NOTE: `shareAmount = 0` is extremely rare case, not optimizing for it
    # NOTE: `totalAssets = 0` is extremely rare case, not optimizing for it
    return shareAmount * self._totalAssets() / totalSupply

@view
@external
def convertToAssets(shareAmount: uint256) -> uint256:
    return self._convertToAssets(shareAmount)

@view
@internal
def _convertToShares(assetAmount: uint256) -> uint256:
    totalSupply: uint256 = self.totalSupply
    totalAssets: uint256 = self._totalAssets()
    if totalAssets == 0 or totalSupply == 0:
        return assetAmount  # 1:1 price

    # NOTE: `assetAmount = 0` is extremely rare case, not optimizing for it
    return assetAmount * totalSupply / totalAssets

@view
@external
def convertToShares(assetAmount: uint256) -> uint256:
    return self._convertToShares(assetAmount)

@view
@external
def maxDeposit(owner: address) -> uint256:
    return max_value(uint256)

@view
@internal
def _pricePerShare() -> decimal:
    totalSupply: uint256 = self.totalSupply
    totalAssets: uint256 = self._totalAssets()
    if totalAssets == 0 or totalSupply == 0:
        return 1.0
    return convert(totalAssets, decimal) / convert(totalSupply, decimal)

@external
@view
def pricePerShare() -> decimal:
    return self._pricePerShare()

######################################
#       ERC4626 - Deposit/Withdraw
######################################

@internal
def chargePerformanceFees(owner: address):
    """
    Function is used to charge performance fees.
    If return generated is negative no fee is charged.
    Returns the amount of shares to charge as performance fee
    """
    if owner != self.owner:
        # Get entry and final share price
        _shares: uint256 = self.balanceOf[owner]
        _entry_price: decimal = self.entrySharePrice[owner]
        _final_price: decimal = self._pricePerShare()

        # Check if return is negative
        if _entry_price < _final_price:
            # Calculate shares to charge as fees
            _s: decimal = convert(_shares, decimal)*(1.0 - _entry_price/_final_price)*performanceFees*convert(BASE_UNIT, decimal)
            s: uint256 = convert(_s, uint256)/BASE_UNIT

            self.balanceOf[owner] -= s
            self.balanceOf[self.owner] += s
    else:
        pass

    
@view
@external
def previewDeposit(assets: uint256) -> uint256:
    # @Note: Take into account fees to return accurate deposit amount
    return self._convertToShares(assets)

@external
def deposit(assets: uint256, receiver: address=msg.sender) -> uint256:
    assert self.initialized == True, "vaut not initialized"
    assert self.paused == False, "Vault paused"

    # Get shares to be minted given assets
    shares: uint256 = self._convertToShares(assets)

    # Charge deposit fee
    shares = (shares*(BASE_UNIT - depositFee))/BASE_UNIT

    # Check if receiver has shares outstanding and charge performance fees
    if self.balanceOf[receiver] > 0:
        self.chargePerformanceFees(receiver)

    # Transfer assets and update balance
    self.entrySharePrice[receiver] = self._pricePerShare()
    self.Iasset.transferFrom(msg.sender, self, assets)
    self.totalSupply += shares
    self.balanceOf[receiver] += shares
    
    # Deposit into strategy
    self.Iasset.transfer(self.strategy_address, assets)

    log Deposit(msg.sender, receiver, assets, shares)
    return shares

@view
@external
def maxMint(owner: address) -> uint256:
    return max_value(uint256)

@view
@external
def previewMint(shares: uint256) -> uint256:
    assets: uint256 = self._convertToAssets(shares)

    # NOTE: Vyper does lazy eval on if, so this avoids SLOADs most of the time
    if assets == 0 and self._totalAssets() == 0:
        return shares  # NOTE: Assume 1:1 price if nothing deposited yet

    return assets

@external
def mint(shares: uint256, receiver: address=msg.sender) -> uint256:
    assert self.initialized == True, "vaut not initialized"
    assert self.paused == False, "Vault paused"
    _shares: uint256 = shares
    assets: uint256 = self._convertToAssets(_shares)

    if assets == 0 and self._totalAssets() == 0:
        assets = _shares  # NOTE: Assume 1:1 price if nothing deposited yet

    # Charge deposit fee
    _shares = (_shares*(BASE_UNIT - depositFee))/BASE_UNIT

    # Check if receiver has shares outstanding and charge performance fees
    if self.balanceOf[receiver] > 0:
        self.chargePerformanceFees(receiver)

    # Transfer assets and update balances
    self.entrySharePrice[receiver] = self._pricePerShare()
    self.Iasset.transferFrom(msg.sender, self, assets)
    self.totalSupply += _shares
    self.balanceOf[receiver] += _shares
    
    # Deposit into strategy
    self.Iasset.transfer(self.strategy_address, assets)

    log Deposit(msg.sender, receiver, assets, _shares)
    return assets

@view
@external
def maxWithdraw(owner: address) -> uint256:
    return max_value(uint256)  # real max is `self.asset.balanceOf(self)`

@view
@external
def previewWithdraw(assets: uint256) -> uint256:
    shares: uint256 = self._convertToShares(assets)

    # NOTE: Vyper does lazy eval on if, so this avoids SLOADs most of the time
    if shares == assets and self.totalSupply == 0:
        return 0  # NOTE: Nothing to redeem

    return shares

@external
def withdraw(assets: uint256, receiver: address=msg.sender, owner: address=msg.sender) -> uint256:
    assert self.initialized == True, "vaut not initialized"
    _assets: uint256 = assets
    shares: uint256 = self._convertToShares(_assets)

    # NOTE: Vyper does lazy eval on if, so this avoids SLOADs most of the time
    if shares == _assets and self.totalSupply == 0:
        raise  # Nothing to redeem

    if owner != msg.sender:
        self.allowance[owner][msg.sender] -= shares

    # Charge performance fees
    self.chargePerformanceFees(owner)

    # Check if shares > balanceOf
    curr_bal: uint256 = self.balanceOf[owner]
    if shares > curr_bal:
        shares = curr_bal
        _assets = self._convertToAssets(shares)

    self.balanceOf[owner] -= shares
    self.totalSupply -= shares
    
    # Withdraw from strategy
    asset_balance_before: uint256 = self.Iasset.balanceOf(self)
    self.Strategy.withdraw(_assets)
    asset_balance_after: uint256 = self.Iasset.balanceOf(self)
    assets_withdraw: uint256 = asset_balance_after-asset_balance_before

    self.Iasset.transfer(receiver, assets_withdraw)
    log Withdraw(msg.sender, receiver, owner, assets_withdraw, shares)
    return shares

@view
@external
def maxRedeem(owner: address) -> uint256:
    return max_value(uint256)  # real max is `self.totalSupply`

@view
@external
def previewRedeem(shares: uint256) -> uint256:
    return self._convertToAssets(shares)

@external
def redeem(shares: uint256, receiver: address=msg.sender, owner: address=msg.sender) -> uint256:
    assert self.initialized == True, "vaut not initialized"
    _shares: uint256 = shares
    assets: uint256 = self._convertToAssets(_shares)

    if owner != msg.sender:
        self.allowance[owner][msg.sender] -= _shares

    # Charge performance fees
    self.chargePerformanceFees(owner)

    # Check if shares > balanceOf
    curr_bal: uint256 = self.balanceOf[owner]
    if _shares > curr_bal:
        _shares = curr_bal
        assets = self._convertToAssets(_shares)

    self.balanceOf[owner] -= _shares
    self.totalSupply -= _shares
    
    # Withdraw from strategy
    asset_balance_before: uint256 = self.Iasset.balanceOf(self)
    self.Strategy.withdraw(assets)
    asset_balance_after: uint256 = self.Iasset.balanceOf(self)
    assets_withdraw: uint256 = asset_balance_after-asset_balance_before

    self.Iasset.transfer(receiver, assets_withdraw)
    log Withdraw(msg.sender, receiver, owner, assets_withdraw, _shares)
    return assets

######################################
#               ADMIN 
######################################

@external
def pause():
    assert msg.sender == self.owner, "!owner"
    self.paused = True

@external
def unpause():
    assert msg.sender == self.owner, "!owner"
    self.paused = False

@external
def send_idle():
    assert msg.sender == self.owner, "!owner"
    bal: uint256 = self.Iasset.balanceOf(self)
    self.Iasset.transfer(self.strategy_address, bal)

@external
def sweep(_token: address, _to: address):
    assert msg.sender == self.owner, "!owner"
    assert _token != self.asset, "can't sweep underlying"
    _qty: uint256 = ERC20(_token).balanceOf(self)
    ERC20(_token).transfer(_to, _qty)