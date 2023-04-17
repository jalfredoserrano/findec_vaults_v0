# SPDX-License-Identifier: MIT
# @version ^0.3.3

#""""""""""""""""""""""""""""""""
#            INTERFACES
#""""""""""""""""""""""""""""""""
interface IERC20:
    def totalSupply() -> uint256: view
    def balanceOf(_owner: address) -> uint256: view
    def allowance(_owner: address, _spender: address) -> uint256: view
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def name() -> String[1]: view
    def symbol() -> String[1]: view
    def decimals() -> uint256: view

interface IUniswapV2Factory:
    def getPair(_tokenA: address, _tokenB: address) -> address: view

interface IUniswapV2Router:
    def swapExactTokensForTokens(_amountIn: uint256, _amountOutMin: uint256, _path: DynArray[address, 3], _to: address, _deadline: uint256) -> DynArray[uint256, 3]: nonpayable
    def swapExactTokensForETH(_amountIn: uint256, _amountOutMin: uint256, _path: DynArray[address, 3], _to: address, _deadline: uint256) -> DynArray[uint256, 3]: nonpayable
    def removeLiquidityETH(_token: address, _liquidity: uint256, _amountTokenMin: uint256, _amountETHMin: uint256, _to: address, _deadline: uint256) -> (uint256, uint256): nonpayable
    def addLiquidity(_tokenA: address,_tokenB: address,_amountADesired: uint256,_amountBDesired: uint256,_amountAMin: uint256,_amountBMin: uint256,_to: address,_deadline: uint256) -> (uint256, uint256, uint256): nonpayable
    def removeLiquidity(_tokenA: address,_tokenB: address,_liquidity: uint256,_amountAMin: uint256,_amountBMin: uint256,_to: address,_deadline: uint256) -> (uint256, uint256): nonpayable
    def getAmountsOut(_amountIn: uint256,_path: DynArray[address, 3]) -> DynArray[uint256, 3]: view


interface IUniswapV2Pair:
    def name() -> String[10]: pure
    def symbol() -> String[10]: pure
    def decimals() -> uint8: pure
    def totalSupply() -> uint256: view
    def getReserves() -> (uint112, uint112, uint32): view
    def balanceOf(_owner: address) -> uint256: view
    def token0() -> address: view
    def token1() -> address: view

interface IAaveV2LendingPoolAddressProvider:
    def getLendingPool() -> address: view
    def getPriceOracle() -> address: view

interface IAaveV2LendingPool:
    def deposit(asset: address, amount: uint256, onBehalfOf: address, referralCode: uint16): nonpayable
    def borrow(asset: address, amount: uint256, interestRateMode: uint256, referralCode: uint16, onBehalfOf: address): nonpayable
    def repay(asset: address, amount: uint256, rateMode: uint256, onBehalfOf: address): nonpayable
    def withdraw(asset: address, amount: uint256, to: address): nonpayable

interface IAaveV2Oracle:
    def getAssetPrice(asset: address) -> uint256: view
    def BASE_CURRENCY_UNIT() -> uint256: view

struct UserInfo:
    amount: uint256
    rewardDebt: int128

interface IMasterChefV2:
    def userInfo(_pid: uint256, _user: address) -> UserInfo: view
    def pendingLqdr(_pid: uint256, _user: address) -> uint256: view
    def deposit(pid: uint256, amount: uint256, to: address): nonpayable
    def withdraw(pid: uint256, amount: uint256, to: address): nonpayable
    def harvest(pid: uint256, to: address): nonpayable

interface IAaveRewarder:
    def claimAllRewards(assets: DynArray[address, 5], to: address) -> (DynArray[address, 5], DynArray[uint256, 5]): nonpayable

uniswap_factory: public(IUniswapV2Factory)
uniswap_pair: public(IUniswapV2Pair)
uniswap_router: public(IUniswapV2Router)
aave_provider: public(IAaveV2LendingPoolAddressProvider)
aave_lending_pool: public(IAaveV2LendingPool)
aave_oracle: public(IAaveV2Oracle)
masterchef: public(IMasterChefV2)
aave_rewarder: public(IAaveRewarder)


######################################
#            VARS / EVENTS 
######################################

event Harvest:
    sender: indexed(address)
    reward_amount: uint256

event CollateralRebalance:
    sender: indexed(address)
    cr: decimal
    initial_balance: uint256
    final_balance: uint256

event ExposureRebalance:
    sender: indexed(address)
    exposure: decimal
    initial_balance: uint256
    final_balance: uint256  

enum Contracts:
    ROUTER
    LENDINGPOOL
    MASTERCHEF

enum PriceOracles:
    CHAINLINK
    LP

# Tokens
stableToken: public(address)
variableToken: public(address)
aToken: public(address)
debtToken: public(address)
lpToken: public(address)
rewardToken: public(address)
stableERC: public(IERC20)
variableERC: public(IERC20)
secondaryToken: public(address)
secondaryaToken: public(address)
secondaryRewardstoTokenSwapPath: public(DynArray[address, 3])

# Strategy parameters
initialized: public(bool)
stratName: public(String[40])
targetCollatRatio: public(decimal)
maxCollatRatio: public(decimal)
maxAllowedCollatRatio: public(decimal)
priceExposure: public(decimal)
shortAllowedExposure: public(decimal)
longAllowedExposure: public(decimal)
slippage: public(uint256)
priceProtectionPerc: public(decimal)
strategistFee: public(uint256)
secondaryFee: public(uint256)

# Admin and roles
owner: public(address)
vault: public(address)
lendingvault: public(address)
strategists: public(HashMap[address, bool])
keepers: public(HashMap[address, bool])

# Constants and key variables
poolid: public(uint256)
decimalsVariable: public(decimal)
decimalsStable: public(decimal)
_one: constant(decimal) = 1.0
_two: constant(decimal) = 2.0
_neg_one: constant(decimal) = -1.0
BASE_UNIT: constant(uint256) = 10000

# Swap paths
_path_variable_to_stable: public(DynArray[address, 3])
_path_stable_to_variable: public(DynArray[address, 3])
_path_reward_to_stable: public(DynArray[address, 3])

@external
def __init__(_strat_name: String[40], _vault: address, _lendingvault: address, _stable_token: address, _variable_token: address, _a_token: address, _debt_token: address, _reward_token: address, _tcr: decimal, _maxcr: decimal, _maxallowedcr: decimal, _exposure: decimal, _maxshortexposure: decimal, _maxlongexposure: decimal):
    self.stratName = _strat_name

    # Set admin and roles
    self.owner = msg.sender
    self.vault = _vault
    self.lendingvault = _lendingvault
    self.strategists[msg.sender] = True

    # Set tokens
    self.stableToken = _stable_token
    self.variableToken = _variable_token
    self.aToken = _a_token
    self.debtToken = _debt_token
    self.rewardToken = _reward_token

    # Set params
    self.targetCollatRatio = _tcr
    self.maxCollatRatio = _maxcr
    self.maxAllowedCollatRatio = _maxallowedcr
    self.priceExposure = _exposure
    self.shortAllowedExposure = _maxshortexposure
    self.longAllowedExposure = _maxlongexposure
    self.slippage = 9950
    self.priceProtectionPerc = 0.02
    self.strategistFee = 500
    self.secondaryFee = 500

    # Set other key variables
    self.stableERC = IERC20(_stable_token)
    self.variableERC = IERC20(_variable_token)
    self.decimalsStable = convert(10**self.stableERC.decimals(), decimal)
    self.decimalsVariable = convert(10**self.variableERC.decimals(), decimal)

    # Set swap paths
    self._path_variable_to_stable = [_variable_token, _stable_token]
    self._path_stable_to_variable = [_stable_token, _variable_token]
    self._path_reward_to_stable = [self.rewardToken, _variable_token, _stable_token]


######################################
#               CORE 
######################################

@external
def initializeStrategy(_base_amount: uint256, _uniswap_factory: address, _uniswap_router: address, _aave_provider: address, _aave_rewarder: address, _masterchef: address, _poolid: uint256, _secondary_token: address, _secondary_atoken: address, _secondary_swap_path: DynArray[address, 3] = []):
    assert self.initialized == False, "strategy already initialized"    
    assert self.owner == msg.sender, "!owner"
    self.initialized = True
    self.stableERC.transferFrom(msg.sender, self, _base_amount)
    self.set_uniswap_interfaces(_uniswap_factory, _uniswap_router)
    self.set_aave_interfaces(_aave_provider, _aave_rewarder)
    self.set_masterchef_interfaces(_masterchef, _poolid)
    self.approve_all()
    self.approve_secondary_collateral(_secondary_token, _secondary_atoken, _secondary_swap_path)
    self._deployIdle()

@internal
def _deployIdle():
    """
    Function deploys stable balance to protocols.
    Lends, borrows, deposits into lp and farm.
    """
    assert self.initialized == True, "!initialized"
    assert self.strategists[msg.sender]==True or self.keepers[msg.sender]==True, "not authorized"

    stable_bal: uint256 = self.stableERC.balanceOf(self)
    if stable_bal > 0:
        # Determine position sizes
        _c: uint256 = 0
        _d: uint256 = 0
        _lp: uint256 = 0
        _c, _d, _lp = self._asset_allocation(stable_bal)

        # Add collateral and borrow
        self._add_collateral(_c)
        _borrow_amount_in_variable: uint256 = self._stableToVariable(_d)
        self._borrow(_borrow_amount_in_variable)

        # Deposit into pool and farm
        self._split5050andAddLiquidity()

        # Repay debt with remaining variable token balance
        _variable_bal: uint256 = self.variableERC.balanceOf(self)
        if _variable_bal > 0:
            self._repay(_variable_bal)


@external
def deployIdle():
    self._deployIdle()

@internal
def _rebalance_collateral():
    """
    Function executes rebalance collateral logic.

    NOTE: '_a' is positive if: collat ratio > target collat ratio because d > tcr*c. 
        Then only time '_a' can be negative is inside the withdrawal function.
    """
    cr: decimal = self._getCollateralRatio()
    tcr: decimal = self.targetCollatRatio
    if cr > tcr+0.02 or cr < tcr-0.02:
        # Determine amount to remove from lp ('_a': half of the lp amount to remove)
        _d: decimal = convert(self._getDebtBalance(), decimal)
        _c: decimal = convert(self._getCollateralBalance(), decimal)
        _a: decimal = (_d - tcr*_c)/(_one + tcr) 

        # Go through normal logic. Reducing collateral raito to target.
        if _a >= 0.0:
            # Determine liquidity amount to remove
            _lp: decimal = convert(self._getLpBalance(True), decimal)
            _a_as_perc_of_lp: decimal = _two*_a/_lp
            self._withdraw_lp_by_perc(_a_as_perc_of_lp)

            # Repay debt and add to collateral
            _stable_bal: uint256 = self.stableERC.balanceOf(self)
            self._add_collateral(_stable_bal)
            _variable_bal: uint256 = self.variableERC.balanceOf(self)
            self._repay(_variable_bal)

        # Go through secondary logic. Increasing collateral ratio to target.
        else:
            # Remove and borrow '_a' from collateral and debt respectively
            a: uint256 = convert(_a, uint256)
            a_in_variable: uint256 = self._stableToVariable(a)
            self._remove_collateral(a)
            self._borrow(a_in_variable)
            
            # Add to AMM
            self._split5050andAddLiquidity()

@external
def rebalance_collateral():
    """
    Function rebalances collateral ratio to target value.
    Prioritizes adding idle assets as collateral.
    If collateral still needs rebalancing, then withdraw from farm, repay and deposit collateral.
    """
    assert self.initialized == True, "!initialized"
    assert self.strategists[msg.sender]==True or self.keepers[msg.sender]==True, "!strategist"
    _initial_cr: decimal = self._getCollateralRatio()
    assert _initial_cr > self.maxCollatRatio, "Collateral Ratio within valid range"

    _initial_balance: uint256 = self._totalBalance()

    # Prioritize adding collateral
    self._prioritizeCollateral()

    # Check if collateral still needs rebalancing
    if self._getCollateralRatio() > self.targetCollatRatio+0.02:
        self._rebalance_collateral()

    _final_balance: uint256 = self._totalBalance()

    log CollateralRebalance(msg.sender, _initial_cr, _initial_balance, _final_balance)

@external
def withdraw(_assets: uint256):
    """
    Withdraws from strategy.
    First tries to satisfy withdrawal using idle assets.
    If not enough, try to satisfy withdrawal by removing excess collateral.
        Only remove collateral if enough to satisfy withdrawal.
    If not enough,
        Rebalance collateral.
        Get remaining amount to withdraw as percentage of deployed balance.
        Remove from AMM = lp * withdrawal percentage.
        Repay = debt * withdrawal percentage.
        Remove from collateral = collateral * withdrawal percentage.

    NOTE: we rebalance collateral to simplify the withdrawal process. This is because strategy can be at various different states.
    """
    assert self.initialized == True, "!initialized"
    assert self.vault == msg.sender or self.owner == msg.sender, "!vault"
    
    _remaining_to_withdraw: uint256 = 0

    # Withdraw from idle assets
    _idle_balance: uint256 = self.stableERC.balanceOf(self)
    if _idle_balance >= _assets:
        self.stableERC.transfer(self.vault, _assets)
    else:
        _remaining_to_withdraw = _assets - _idle_balance
        
        
    # Withdraw from excess collateral
    if _remaining_to_withdraw > 0:
        if self._getCollateralRatio() < self.targetCollatRatio:
            _c: decimal = convert(self._getCollateralBalance(), decimal)
            _d: decimal = convert(self._getDebtBalance(), decimal)
            _c_to_remove: uint256 = convert(_c - (_d/self.targetCollatRatio), uint256)
            if _c_to_remove >= _assets:
                self._remove_collateral(_assets)
                self.stableERC.transfer(self.vault, _assets)
                _remaining_to_withdraw = 0

    # Withdraw remaining amount
    if _remaining_to_withdraw > 0:
        # Rebalance collateral
        self._rebalance_collateral()
        _total_balance: uint256 = self._totalBalance()
        _withdraw_percentage: decimal = convert(_assets, decimal)/convert(_total_balance, decimal)

        # Remove from AMM
        self._withdraw_lp_by_perc(_withdraw_percentage)

        # Repay
        _repay_amount: uint256 = convert(_withdraw_percentage*convert(self._getDebtBalance(), decimal), uint256)
        _repay_in_variable: uint256 = self._stableToVariable(_repay_amount)
        _variable_balance: uint256 = self.variableERC.balanceOf(self)
        if _repay_in_variable > _variable_balance:
            self._swap_to_variable(_repay_in_variable - _variable_balance)
            self._repay(self.variableERC.balanceOf(self))
        else:
            self._repay(_repay_in_variable)

        # Remove collateral
        _c_remove_amount: uint256 = convert(_withdraw_percentage*convert(self._getCollateralBalance(), decimal), uint256)
        self._remove_collateral(_c_remove_amount)

        # Swap remaining variable tokens to stable
        _variable_balance_1: uint256 = self.variableERC.balanceOf(self)
        if _variable_balance_1 > 0:
            self._swap_to_stable(_variable_balance_1)

        # Transfer all idle assets to vault
        _idle_assets: uint256 = self.stableERC.balanceOf(self)
        self.stableERC.transfer(self.vault, _idle_assets)


@external
def harvest():
    """
    Harvests farm rewards and swap to stable token.
    Deploys idle assets.

    NOTE: we repay debt first with idle variable token to ensure secondary vault doesn't canibalize main vault.
    """
    assert self.initialized == True, "!initialized"
    assert self.strategists[msg.sender] == True or self.keepers[msg.sender]==True, "not authorized"

    # Repay debt with any idle variable tokens
    _variable_bal: uint256 = self.variableERC.balanceOf(self)
    if _variable_bal > 0:
        self._repay(_variable_bal)

    # Get before stable balance
    _before_bal: uint256 = self.stableERC.balanceOf(self)

    # Harvest
    self.masterchef.harvest(self.poolid, self)

    # Swap to secondary
    if IERC20(self.secondaryaToken).balanceOf(self) > 0:
        _reward_balance: uint256 = IERC20(self.rewardToken).balanceOf(self)
        _secondary_fees: uint256 = _reward_balance*self.secondaryFee/BASE_UNIT
        self._swap_reward_to_secondary_and_deposit(_secondary_fees)

    # Swap remaining rewards to stable
    _reward_balance_1: uint256 = IERC20(self.rewardToken).balanceOf(self)
    self._swap_reward(_reward_balance_1)

    # Get after stable balance
    _after_bal: uint256 = self.stableERC.balanceOf(self)
    _harvested_amount: uint256 = _after_bal - _before_bal

    # Send fees to owner
    _owner_fees: uint256 = (_after_bal-_before_bal)*self.strategistFee/BASE_UNIT
    self.stableERC.transfer(self.owner, _owner_fees)

    # Deploy idle assets
    self._deployIdle()

    log Harvest(msg.sender, _harvested_amount)

@external
def harvest_aave(_assets: DynArray[address, 5]):
    """
    Function claims rewards from lending protocol.
    Rewards are sent as management fee to the owner.

    NOTE: think we can get creative with this. 
    One option is to give all these rewards to users lending secondary collateral. 
    Swap may be complicated so may have to set a rewarder contract.
    """
    assert self.initialized == True, "!initialized"
    assert self.owner == msg.sender, "!owner"    
    self.aave_rewarder.claimAllRewards(_assets, self)
    for a in _assets:
        _qty: uint256 = IERC20(a).balanceOf(self)
        IERC20(a).transfer(msg.sender, _qty)

@external
def rebalance_exposure(_new_exposure: decimal):
    """
    Function rebalanes strategy state given a new price exposure.
    All liquidity is removed from the AMM. 
    Only the required amount is swapped to minimize slippage.

    NOTE: look into ways of rebalancing without withdrawing all liquidity. Not possible for all cases, but may be possible for most.
    """
    assert self.initialized == True, "!initialized"
    assert self.strategists[msg.sender] == True, "!strategist"
    if _new_exposure != self.priceExposure:
        assert self.shortAllowedExposure < _new_exposure, "exposure too low"
        assert self.longAllowedExposure > _new_exposure, "exposure too high"
        self.priceExposure = _new_exposure

    # Get current and new state
    _I: uint256 = self._totalBalance()
    _c_new: uint256 = 0
    _d_new: uint256 = 0
    _lp_new: uint256 = 0
    _c_new, _d_new, _lp_new = self._asset_allocation(_I)
    _c_current: uint256 = self._getCollateralBalance()
    _d_current: uint256 = self._getDebtBalance()
    _lp_current: uint256 = self._getLpBalance(True)

    # Remove all liquidity
    self._withdraw_lp_by_perc(1.0)

    # Check if collateral needs to be added
    if _c_new > _c_current:
        _c_to_add: uint256 = _c_new - _c_current
        _c_balance: uint256 = self.stableERC.balanceOf(self)
        if _c_balance >= _c_to_add:
            self._add_collateral(_c_to_add)
        else:
            _c_missing: uint256 = _c_to_add - _c_balance
            self._swap_to_stable(self._stableToVariable(_c_missing))  
            self._add_collateral(self.stableERC.balanceOf(self))

    # Check if debt must be repaid
    if _d_new < _d_current:
        _d_required: uint256 = self._stableToVariable(_d_current-_d_new)
        _d_balance: uint256 = self.variableERC.balanceOf(self)
        if _d_balance >= _d_required:
            self._repay(_d_required)
        else:
            _d_missing: uint256 = _d_required - _d_balance
            self._swap_to_variable(self._variableToStable(_d_missing))
            self._repay(self.variableERC.balanceOf(self))

    # Check if collateral needs to be removed
    if _c_new < _c_current:
        _c_to_remove: uint256 = _c_current - _c_new
        self._remove_collateral(_c_to_remove)

    # Check if need to borrow
    if _d_new > _d_current:
        _d_to_borrow: uint256 = self._stableToVariable(_d_new-_d_current)
        self._borrow(_d_to_borrow)

    # Add liquidity
    self._split5050andAddLiquidity()

    _final_balance: uint256 = self._totalBalance()

    log ExposureRebalance(msg.sender, _new_exposure, _I, _final_balance)



######################################
#               VIEWERS 
######################################

@internal
@view
def _getIdleBalance() -> uint256:
    """
    Returns idle balance of stable token.
    """
    return self.stableERC.balanceOf(self)

@external
@view
def getIdleBalance() -> uint256:
    return self._getIdleBalance()

@internal
@view
def _getCollateralBalance() -> uint256:
    """
    Returns value of collateral.
    """
    return IERC20(self.aToken).balanceOf(self)

@external
@view
def getCollateralBalance() -> uint256:
    return self._getCollateralBalance()

@internal
@view
def _getDebtBalance() -> uint256:
    """
    Returns debt balance in terms of stable token.
    """
    debt_balance: uint256 = IERC20(self.debtToken).balanceOf(self)
    return self._variableToStable(debt_balance)

@external
@view
def getDebtBalance() -> uint256:
    return self._getDebtBalance()

@internal
@view
def _getLpBalance(_in_farm: bool = False) -> uint256:
    """
    Returns lp balance in terms of stable token.
    _in_farm: if lp balance should come from farm or AMM.
    """
    _weth_liquidity: uint256 = 0
    _stable_liquidity: uint256 = 0
    (_weth_liquidity, _stable_liquidity) = self._quoteLiquidityOut(_in_farm)
    return self._variableToStable(_weth_liquidity) + _stable_liquidity

@external
@view
def getLpBalance(_in_farm: bool = False) -> uint256:
    return self._getLpBalance(_in_farm)

@internal
@view
def _totalBalance() -> uint256:
    """
    Returns total balance held by the strategy in terms of stable token.
    """
    return self._deployedBalance() + self._getIdleBalance()

@external
@view
def totalBalance() -> uint256:
    return self._totalBalance()


@internal
@view
def _deployedBalance() -> uint256:
    """
    Returns the deployed balance.
    """
    return self._getCollateralBalance() - self._getDebtBalance() + self._getLpBalance(False) + self._getLpBalance(True)

@external
@view
def deployedBalance() -> uint256:
    return self._deployedBalance()

@internal
@view
def _getCollateralRatio() -> decimal:
    """
    Returns current collateral ratio.
    """
    return convert(self._getDebtBalance(), decimal)/convert(self._getCollateralBalance(), decimal)

@external
@view
def getCollateralRatio() -> decimal:
    return self._getCollateralRatio()

@internal
@view
def _quoteLiquidityOut(_in_farm: bool = False) -> (uint256, uint256):
    """
    Quotes tokens that would be returned if all liquidity would be withdrawn.
    _in_farm: if qoute shoud use farm liquidity or AMM liquidity.

    NOTE: Need to add price protection mecanism.
    """
    # Run price protection
    self._price_protection()

    # Get liquidity owned
    _liquidity: uint256 = 0
    if _in_farm == False:
        _liquidity = IERC20(self.lpToken).balanceOf(self)
    else:
        _userinfo: UserInfo = self.masterchef.userInfo(self.poolid, self)
        _liquidity = _userinfo.amount
    
    if _liquidity == 0:
        return (0, 0)

    # Get total supply of lp and percentage owned    
    _supply: uint256 = IERC20(self.lpToken).totalSupply()
    _liquidity_percentage: decimal = convert(_liquidity, decimal)/convert(_supply, decimal)

    # get reserves
    _variable_reserves: uint112 = 0
    _stable_reserves: uint112 = 0
    _: uint32 = 0
    if self.uniswap_pair.token0() == self.variableToken:
        (_variable_reserves, _stable_reserves, _) = self.uniswap_pair.getReserves()
    else:
        (_stable_reserves, _variable_reserves, _) = self.uniswap_pair.getReserves()

    # get liquidity out
    _variable_out: uint256 = convert(convert(_variable_reserves, decimal)*_liquidity_percentage, uint256)
    _stable_out: uint256 = convert(convert(_stable_reserves, decimal)*_liquidity_percentage, uint256)
    return (_variable_out, _stable_out)

@internal
@view
def _variableToStable(_qty: uint256, _using_oracle: bool=True) -> uint256:
    """
    Returns balance of a given variable token amount in terms of stable token.
    _using_oracle: used to get price from oracle or lp.
    """
    variable_price: decimal = 0.0
    if _using_oracle == True:
        variable_price = self._get_variable_price_oracle()
    else:
        variable_price = self._get_variable_price_lp()
    balance_in_stable: decimal = convert(_qty, decimal)*variable_price*self.decimalsStable/self.decimalsVariable
    return convert(balance_in_stable, uint256)

@internal
@view
def _stableToVariable(_qty: uint256, _using_oracle: bool=True) -> uint256:
    """
    Returns balance of a given stable token amount in terms of variable token.
    _using_oracle: used to get price from oracle or lp.
    """
    variable_price: decimal = 0.0
    if _using_oracle == True:
        variable_price = self._get_variable_price_oracle()
    else:
        variable_price = self._get_variable_price_lp()
    balance_in_variable: decimal = (convert(_qty, decimal)/variable_price)*(self.decimalsVariable/self.decimalsStable)
    return convert(balance_in_variable, uint256)


######################################
#            PRICE ORACLES 
######################################

@internal
@view
def _get_variable_price(_from: PriceOracles) -> decimal:
    """
    Returns price of variable asset.
    Can choose either chainlink price of lp price.
    """
    if _from == PriceOracles.CHAINLINK:
        return self._get_variable_price_oracle()
    elif _from == PriceOracles.LP:
        return self._get_variable_price_lp()
    else:
        return max_value(decimal)

@external
@view
def get_variable_price(_from: PriceOracles) -> decimal:
    return self._get_variable_price(_from)

@internal
@view
def _get_variable_price_oracle() -> decimal:
    """
    Returns chainlink price of variable token.
    """
    _price: uint256 = self.aave_oracle.getAssetPrice(self.variableToken)
    _base_unit: uint256 = self.aave_oracle.BASE_CURRENCY_UNIT()
    _decimal_price: decimal = convert(BASE_UNIT*_price/_base_unit, decimal)/convert(BASE_UNIT, decimal)
    return _decimal_price

@internal
@view
def _get_variable_price_lp() -> decimal:
    """
    Returns LP price of variable token.
    """
    _amounts_out: DynArray[uint256, 3] = self.uniswap_router.getAmountsOut(10**self.variableERC.decimals(), self._path_variable_to_stable)
    _price: decimal = convert(_amounts_out[1], decimal)/self.decimalsStable
    return _price


@internal
@view
def _price_protection():
    """
    MEV price protection.
    """
    _oracle_price: decimal = self._get_variable_price_oracle()
    _lp_price: decimal = self._get_variable_price_lp()
    if _oracle_price>=_lp_price:
        assert (_oracle_price/_lp_price)-1.0 <= self.priceProtectionPerc, "Significant price discrepancy between oracle and lp"
    elif _oracle_price<_lp_price:
        assert (_lp_price/_oracle_price)-1.0 <= self.priceProtectionPerc, "Significant price discrepancy between oracle and lp"

######################################
#               HELPERS 
######################################

@internal
@view
def _asset_allocation(_I: uint256) -> (uint256, uint256, uint256): 
    """
    Calculates optimal asset distribution given the current parameters.
    """
    
    _i: decimal = convert(_I, decimal)
    _tcr: decimal = self.targetCollatRatio
    _e: decimal = self.priceExposure*_i
    
    # Determine collateral, debt and lp allocations
    _c: decimal = (_i - _two*_e)/(_one + _tcr)
    _d: decimal = _c*_tcr
    _lp: decimal = _i - _c + _d

    return convert(_c, uint256), convert(_d, uint256), convert(_lp, uint256)

@external
@view
def asset_allocation(_I: uint256) -> (uint256, uint256, uint256):
    return self._asset_allocation(_I)

@internal
def _swap_to_stable(_qty: uint256):
    """
    Swaps _qty from variable to stable.
    Uses slippage to prevent sandwich attacks.
    No need to use chainlink price for _amountmin calc since we are calling _price_protection.
    """
    self._price_protection()
    _deadline: uint256 = block.timestamp+300
    _amountmin: uint256 = self._variableToStable(_qty, False)*self.slippage/BASE_UNIT
    self.uniswap_router.swapExactTokensForTokens(_qty, _amountmin, self._path_variable_to_stable, self, _deadline)

@internal
def _swap_to_variable(_qty: uint256):
    """
    Swaps _qty from stable to variable.
    Uses slippage to prevent sandwich attacks.
    No need to use chainlink price for _amountmin calc since we are calling _price_protection.
    """
    self._price_protection()
    _deadline: uint256 = block.timestamp+300
    _amountmin: uint256 = self._stableToVariable(_qty, False)*self.slippage/BASE_UNIT
    self.uniswap_router.swapExactTokensForTokens(_qty, _amountmin, self._path_stable_to_variable, self, _deadline)

@internal
def _swap_reward(_qty: uint256):
    """
    Swaps reward token to stable.
    Currently, no MEV protection.
    """
    _deadline: uint256 = block.timestamp+300
    self.uniswap_router.swapExactTokensForTokens(_qty, 0, self._path_reward_to_stable, self, _deadline)

@internal
def _add_collateral(_c: uint256):
    """
    Adds stable token as collateral to Aave.
    """
    self.aave_lending_pool.deposit(self.stableToken, _c, self, 0)

#=======ONLY FOR DEVELOPMENT AND TESTING===========#
@external
def add_collateral(_c: uint256):
    self._add_collateral(_c)

@internal
def _borrow(_d: uint256):
    """
    Borrows variable token from Aave.
    """
    self.aave_lending_pool.borrow(self.variableToken, _d, 2, 0, self)

#=======ONLY FOR DEVELOPMENT AND TESTING===========#
@external
def borrow(_d: uint256):
    self._borrow(_d)

@internal
def _lp_deposit(_stable_qty: uint256, _variable_qty: uint256):
    """
    Deposits liquidity to Uniswap.
    Uses slippage for MEV protection.
    """
    # Deposit assets into lp
    _deadline: uint256 = block.timestamp+300
    # @note: double check and deep dive into desired/min calculation
    _stable_desired: uint256 = _stable_qty*self.slippage/BASE_UNIT
    _variable_desired: uint256 = _variable_qty*self.slippage/BASE_UNIT
    _stable_min: uint256 = _stable_desired*self.slippage*95/(BASE_UNIT*100)
    _variable_min: uint256 = _variable_desired*self.slippage*95/(BASE_UNIT*100)
    self.uniswap_router.addLiquidity(self.stableToken, self.variableToken, _stable_desired, _variable_desired, _stable_min, _variable_min, self, _deadline)

#=======ONLY FOR DEVELOPMENT AND TESTING===========#
@external
def lp_deposit(_stable_qty: uint256, _variable_qty: uint256):
    self._lp_deposit(_stable_qty, _variable_qty)

@internal
def _farm_deposit():
    """
    Deposits liquidity into farm.
    """
    _liquidity: uint256 = self.uniswap_pair.balanceOf(self)
    self.masterchef.deposit(self.poolid, _liquidity, self)

#=======ONLY FOR DEVELOPMENT AND TESTING===========#
@external
def farm_deposit():
    self._farm_deposit()

@internal
def _withdraw_lp_by_perc(_lp_perc_to_remove: decimal):
    """
    Withdraws liquidity from farm and AMM.
    _lp_perc_to_remove: decimal from 0 to 1 that represents the percentage of total liquidity to remove.
    """
    # Determine liquidity amount to remove
    _userinfo: UserInfo = self.masterchef.userInfo(self.poolid, self)
    _amount: uint256 = convert(convert(_userinfo.amount, decimal)*_lp_perc_to_remove, uint256)        

    # remove liquidity
    self._farm_withdraw(_amount)
    _liquidity: uint256 = IERC20(self.lpToken).balanceOf(self)
    self._lp_withdraw(_liquidity)

#=======ONLY FOR DEVELOPMENT AND TESTING===========#
@external
def withdraw_lp_by_perc(_lp_perc_to_remove: decimal):
    self._withdraw_lp_by_perc(_lp_perc_to_remove)

@internal
def _farm_withdraw(_amount: uint256):
    """
    Withdraws liquidity from farm.
    """
    self.masterchef.withdraw(self.poolid, _amount, self)

#=======ONLY FOR DEVELOPMENT AND TESTING===========#
@external
def farm_withdraw(_amount: uint256):
    self._farm_withdraw(_amount)

@internal
def _lp_withdraw(_liquidity: uint256):
    """
    Withdraws liquidity from AMM.
    Uses slippage to prevent MEV attacks.
    """
    _deadline: uint256 = block.timestamp+300
    _amount_stable_min: uint256 = 0
    _amount_variable_min: uint256 = 0
    _amount_variable_min, _amount_stable_min = self._quoteLiquidityOut()
    _liquidity_balance: uint256 = IERC20(self.lpToken).balanceOf(self)
    _amount_variable_min  = (_amount_variable_min*_liquidity*self.slippage/_liquidity_balance)/BASE_UNIT
    _amount_stable_min = (_amount_stable_min*_liquidity*self.slippage/_liquidity_balance)/BASE_UNIT
    self.uniswap_router.removeLiquidity(self.stableToken, self.variableToken, _liquidity, _amount_stable_min, _amount_variable_min, self, _deadline)

#=======ONLY FOR DEVELOPMENT AND TESTING===========#
@external
def lp_withdraw(_liquidity: uint256):
    self._lp_withdraw(_liquidity)

@internal
def _repay(_r: uint256):
    """
    Repays debt.
    """
    self.aave_lending_pool.repay(self.variableToken, _r, 2, self)

#=======ONLY FOR DEVELOPMENT AND TESTING===========#
@external
def repay(_r: uint256):
    self._repay(_r)

@internal
def _remove_collateral(_c: uint256):
    """
    Removes collateral.
    """
    self.aave_lending_pool.withdraw(self.stableToken, _c, self)

#=======ONLY FOR DEVELOPMENT AND TESTING===========#
@external
def remove_collateral(_c: uint256):
    self._remove_collateral(_c)

@internal
def _split5050andAddLiquidity():
    """
    Function is used to split idle assets 50/50 so they can be deposited in the AMM.
    """
    # Ensure 50/50 split between remaining stable and variable 
    _stable_balance: uint256 = self.stableERC.balanceOf(self)
    _variable_balance_in_stable: uint256 = self._variableToStable(self.variableERC.balanceOf(self))

    # Get idle balances percentage difference
    _s: decimal = convert(_stable_balance, decimal)
    _v: decimal = convert(_variable_balance_in_stable, decimal)
    _perc_diff: decimal = 1.0
    if _s > 0.0:
        _perc_diff = (_v/_s)-1.0

    # If difference is less than 0.25% then dont swap
    if _variable_balance_in_stable > 0 and _perc_diff > -0.0025 and _perc_diff < 0.0025:
        pass
    # Else swap so idle assets balances are 50/50
    else:
        if _stable_balance > _variable_balance_in_stable:
            _swap_qty: uint256 = (_stable_balance - _variable_balance_in_stable)/2
            self._swap_to_variable(_swap_qty)
        elif _stable_balance < _variable_balance_in_stable:
            _swap_qty: uint256 = (_variable_balance_in_stable - _stable_balance)/2
            _swap_qty_in_variable: uint256 = self._stableToVariable(_swap_qty)
            self._swap_to_stable(_swap_qty_in_variable)  

    # Add liquidity
    _stable_qty: uint256 = self.stableERC.balanceOf(self)
    _variable_qty: uint256 = self.variableERC.balanceOf(self)
    self._lp_deposit(_stable_qty, _variable_qty)
    self._farm_deposit()

#=======ONLY FOR DEVELOPMENT AND TESTING===========#
@external
def split5050andAddLiquidity():
    self._split5050andAddLiquidity()

######################################
#        SECONDARY COLLATERAL 
######################################

@external
@view
def secondaryBalance() -> uint256:
    """
    Returns total amount of assets held by the strategy of the given secondary collateral token.
    """
    return IERC20(self.secondaryaToken).balanceOf(self)

@external
def depositSecondary():
    """
    Function called by lending vault to deposit assets as collateral.
    """
    assert self.initialized == True, "!initialized"
    assert self.lendingvault == msg.sender, "!lending vault"
    _amount: uint256 = IERC20(self.secondaryToken).balanceOf(self)
    self.aave_lending_pool.deposit(self.secondaryToken, _amount, self, 0)

@external
def withdrawSecondary(_assets: uint256):
    """
    Function called by lending vault to withdraw assets.
    """
    assert self.initialized == True, "!initialized"
    assert self.lendingvault == msg.sender, "!lending vault"
    self.aave_lending_pool.withdraw(self.secondaryToken, _assets, self)
    IERC20(self.secondaryToken).transfer(self.lendingvault, _assets)

@internal
def approve_secondary_collateral(_token: address, _atoken: address, _swap_path: DynArray[address, 3] = []):
    """
    Approves usage of secondary collateral.
    """
    self._approve_erc20(_token, Contracts.LENDINGPOOL)
    self._approve_erc20(_atoken, Contracts.LENDINGPOOL)
    self.secondaryToken = _token
    self.secondaryaToken = _atoken
    if len(_swap_path) == 0:
        self.secondaryRewardstoTokenSwapPath = [self.rewardToken, self.variableToken]
    else:
        self.secondaryRewardstoTokenSwapPath = _swap_path

@internal
def _swap_reward_to_secondary_and_deposit(_qty: uint256):
    """
    Swaps reward token to secondary collateral.
    Currently, no MEV protection.
    """
    _deadline: uint256 = block.timestamp+300
    self.uniswap_router.swapExactTokensForTokens(_qty, 0, self.secondaryRewardstoTokenSwapPath, self, _deadline)
    _amount: uint256 = IERC20(self.secondaryToken).balanceOf(self)
    self.aave_lending_pool.deposit(self.secondaryToken, _amount, self, 0)


######################################
#               ADMIN 
######################################
@internal
def _approve_erc20(_token: address, _contract: Contracts):
    """
    Internal function used to approve tokens transfers.
    Address contract can't be passed as arg for security purposes.
    """
    assert msg.sender == self.owner, "!owner"
    if _contract == Contracts.ROUTER: #1
        IERC20(_token).approve(self.uniswap_router.address, max_value(uint256))
    elif _contract == Contracts.LENDINGPOOL: #2
        IERC20(_token).approve(self.aave_lending_pool.address, max_value(uint256))
    elif _contract == Contracts.MASTERCHEF: #4
        IERC20(_token).approve(self.masterchef.address, max_value(uint256))

@internal
def approve_all():
    """
    Approve tokens helper function.
    Called conce during initiliazation.
    """
    self._approve_erc20(self.variableToken, Contracts.ROUTER)
    self._approve_erc20(self.variableToken, Contracts.LENDINGPOOL)
    self._approve_erc20(self.stableToken, Contracts.ROUTER)
    self._approve_erc20(self.stableToken, Contracts.LENDINGPOOL)
    self._approve_erc20(self.lpToken, Contracts.ROUTER)
    self._approve_erc20(self.lpToken, Contracts.MASTERCHEF)
    self._approve_erc20(self.aToken, Contracts.LENDINGPOOL)
    self._approve_erc20(self.rewardToken, Contracts.ROUTER)

@internal
def set_uniswap_interfaces(_uniswap_factory: address, _uniswap_router: address):
    """
    Sets Uniswap contracts.
    Called conce during initiliazation.
    """
    assert msg.sender == self.owner, "!owner"
    self.uniswap_factory = IUniswapV2Factory(_uniswap_factory)
    self.uniswap_router = IUniswapV2Router(_uniswap_router)
    self.lpToken = self.uniswap_factory.getPair(self.stableToken, self.variableToken)
    self.uniswap_pair = IUniswapV2Pair(self.lpToken)

@internal
def set_aave_interfaces(_aave_provider: address, _aave_rewarder: address):
    """
    Sets Aave contracts.
    Called conce during initiliazation.
    """
    assert msg.sender == self.owner, "!owner"
    self.aave_provider = IAaveV2LendingPoolAddressProvider(_aave_provider)
    _lending_pool: address = self.aave_provider.getLendingPool()
    self.aave_lending_pool = IAaveV2LendingPool(_lending_pool)
    _oracle: address = self.aave_provider.getPriceOracle()
    self.aave_oracle = IAaveV2Oracle(_oracle)
    self.aave_rewarder = IAaveRewarder(_aave_rewarder)

@internal
def set_masterchef_interfaces(_masterchef: address, _poolid: uint256):
    """
    Sets farm contract.
    Called conce during initiliazation.
    """
    assert msg.sender == self.owner, "!owner"
    self.masterchef = IMasterChefV2(_masterchef) 
    self.poolid = _poolid

@external
def set_rewards_strat(_path: DynArray[address, 3]):
    """
    Set path to swap reward token to stable.
    """
    assert msg.sender == self.owner, "!owner"
    self._path_reward_to_stable = _path

@external
def set_owner(_owner: address):
    assert msg.sender == self.owner, "!owner"
    assert _owner != empty(address), "owner = zero"
    self.owner = _owner

@external
def set_strategist(_strategist: address):
    assert msg.sender == self.owner, "!owner"
    assert _strategist != empty(address), "owner = zero"
    _current_status: bool = self.strategists[_strategist]
    self.strategists[_strategist] = not _current_status

@external
def set_keeper(_keeper: address):
    assert msg.sender == self.owner, "!owner"
    assert _keeper != empty(address), "owner = zero"
    _current_status: bool = self.keepers[_keeper]
    self.keepers[_keeper] = not _current_status

@external
def set_target_collat_ratio(_tcr: decimal):
    assert self.strategists[msg.sender] == True, "!strategist"
    assert self.maxAllowedCollatRatio > _tcr, "collateral ratio too high"
    self.targetCollatRatio = _tcr

@external
def set_max_collat_ratio(_maxcr: decimal):
    assert self.strategists[msg.sender] == True, "!strategist"
    assert self.maxAllowedCollatRatio > _maxcr, "collateral ratio too high"
    self.maxCollatRatio = _maxcr

@external
def set_max_allowed_collat_ratio(_maxcr: decimal):
    assert msg.sender == self.owner, "!owner"
    self.maxAllowedCollatRatio = _maxcr

@external
def set_exposure(_exposure: decimal):
    assert self.strategists[msg.sender] == True, "!strategist"
    assert self.shortAllowedExposure < _exposure, "exposure too low"
    assert self.longAllowedExposure > _exposure, "exposure too high"
    self.priceExposure = _exposure

@external
def set_max_allowed_exposure(_shortexposure: decimal, _longexposure: decimal):
    assert msg.sender == self.owner, "!owner"
    self.shortAllowedExposure = _shortexposure
    self.longAllowedExposure = _longexposure

@external
def set_slippage(_slippage: uint256):
    assert self.strategists[msg.sender] == True, "!strategist"
    assert _slippage > 9000 and _slippage < 10000, "slippage not allowed"
    self.slippage = _slippage

@external
def sweep(_token: address, _qty: uint256, _to: address):
    assert msg.sender == self.owner, "!owner"
    #assert _token not in [self.stableToken, self.variableToken, self.rewardToken, self.lpToken], "can't sweep underlying assets"
    #assert  self.secondaryTokens[_token] == False, "can't sweep secondary collateral"
    IERC20(_token).transfer(_to, _qty)

@external
def sweep_eth():
    assert msg.sender == self.owner, "!owner"
    raw_call(msg.sender, b"", value=self.balance)

@external
@payable
def __default__():
    pass
