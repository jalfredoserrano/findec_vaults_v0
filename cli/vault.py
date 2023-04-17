import click
from click import Context
from ape import networks
from ape.cli import network_option, account_option, ape_cli_context
import decimal
from decimal import Decimal
from web3 import Web3, constants
import questionary

# Set common variables
max_uint = Web3.toInt(hexstr=constants.MAX_INT) 
gas_price=200
gas_limit=7000000
ln_break = '\n-------------------'

# Helper functions
def get_token_balance(token, account):
    bal = token.balanceOf(account)
    decimals = token.decimals()
    return bal/(10**decimals)

def update_gasprice(ctx, param, value):
    return value*10**9

# Network bound command
class NetworkCommand(click.Command):
    """
    A command that uses the :meth:`~ape.cli.options.network_option`.
    It will automatically set the network for the duration of the command execution.
    """
    def invoke(self, ctx: Context):
        value = ctx.obj.get("network") or networks.default_ecosystem.name
        with networks.parse_network_choice(value):
            super().invoke(ctx)
        
# Pretty choice selection    
class QuestionaryOption(click.Option):
    def __init__(self, param_decls=None, **attrs):
        click.Option.__init__(self, param_decls, **attrs)
        if not isinstance(self.type, click.Choice):
            raise Exception('ChoiceOption type arg must be click.Choice')

    def prompt_for_value(self, ctx):
        val = questionary.select(self.prompt, choices=self.type.choices).unsafe_ask()
        return val

            
# Common options
def gasprice_option():
    return click.option('--gasprice', default=gas_price, show_default=True, callback=update_gasprice, help="Gas price used for sending tx.")
def gaslimit_option():
    return click.option('--gaslimit', default=gas_limit, show_default=True, help="Gas limit used for sending tx.")

# Group command     
@click.group()
@network_option()
@click.pass_context
def cli(ctx, network):
    print('\nUsing Network: {}'.format(network)+ln_break)
    ctx.obj = {
        'network': network
    }
    
# Account balances
@cli.command(cls=NetworkCommand)
@ape_cli_context()
@account_option()
def balances(context, account):
    # DAI balance
    _project = context.project_manager
    dai = _project.ERC20.at('0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E')
    dai_bal = get_token_balance(dai, account)
    print('DAI Balance: {:0.2f}'.format(dai_bal))
    # WFTM balance
    wftm = _project.ERC20.at('0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83')
    wftm_bal = get_token_balance(wftm, account)
    print('WFTM Balance: {:0.2f}'.format(wftm_bal))

#=====================#    
# Interact with vaults
# as a User
#=====================#  
@cli.command(cls=NetworkCommand)
@ape_cli_context()
@account_option()
@click.option('-vlt', '--vault', type=click.Choice(['DYNAMIC','LENDING'], case_sensitive=False), prompt='Select vault', cls=QuestionaryOption)
@click.option('-a', '--action', type=click.Choice(['DISPLAY','DEPOSIT','WITHDRAW'], case_sensitive=False), prompt='Select Action', cls=QuestionaryOption)
@gasprice_option()
@gaslimit_option()
def vaults(context, account, vault, action, gasprice, gaslimit):
    _project = context.project_manager
    _chain = context.chain_manager 
    # Set selected vault
    if vault == 'DYNAMIC':
        vlt = _chain.contracts.get_deployments(_project.ERC4626DynamicHedgingVault)[-1]
    elif vault == 'LENDING':
        vlt = _chain.contracts.get_deployments(_project.ERC4626LendingVault)[-1]
    print('\nInteracting with {} vault'.format(vault)+ln_break)   
        
    # Print User Vault Details
    _price_per_share = vlt.pricePerShare()
    _shares = vlt.balanceOf(account)
    _decimals = vlt.decimals()
    _balance = Decimal(_shares/10**_decimals)*_price_per_share
    print('Current Balance in Vault: $ {:0.4f}'.format(_balance))
    print('Price per Share: {:0.4f}'.format(_price_per_share))
    
    
    # Check if user approved vault asset for transfer
    _asset = vlt.asset()
    asset = _project.ERC20.at(_asset)
    _allowance = asset.allowance(account, vlt.address)
    if _allowance == 0:
        value = click.prompt('You havent approved the vault to transfer the asset. Do you want to approve the vault?', type=bool)
        if value == True:
            asset.approve(vlt.address, max_uint, sender=account, gas_limit=gaslimit, gas_price=gasprice)
    
    # Display Vault State
    if action == 'DISPLAY':
        _name = vlt.name()
        _supply = vlt.totalSupply()
        _assets = vlt.totalAssets()
        print('\nVault Details'+ln_break)   
        print('Vault Name: {}'.format(_name))
        print('Vault asset: {}'.format(_asset))
        print('Total Supply: {}'.format(_supply))
        print('Total Assets: {}'.format(_assets))
        print('Number of shares owned: {:0.4f}'.format(_shares/10**_decimals))
            
    # Deposit logic
    if action == 'DEPOSIT':
        asset_decimals = asset.decimals()
        asset_bal = get_token_balance(asset, account)
        print('\nDeposit into Vault'+ln_break) 
        print('Current Asset balance: {:0.2f}'.format(asset_bal))
        value = click.prompt('Enter amount to deposit', type=int)
        vlt.deposit(value*10**asset_decimals, sender=account, gas_limit=gaslimit, gas_price=gasprice)
        
    # Withdraw logic
    if action == 'WITHDRAW':
        print('\nWithdraw from Vault'+ln_break) 
        print('Number of shares owned: {:0.4f}'.format(_shares/10**_decimals))
        value = click.prompt('Enter number of shares to withdraw (enter 0 for max withdraw)', type=float)
        _r = _shares if value == 0 else value*10**_decimals
        vlt.redeem(int(_r), sender=account, gas_limit=gaslimit, gas_price=gasprice)

#=====================#    
# Display Strategy Info
#=====================#  
@cli.command(cls=NetworkCommand)
@ape_cli_context()
@click.option("--info", is_flag=True, show_default=True, help="Display strategy information")
@click.option("--state", is_flag=True, show_default=True, help="Display strategy positions state")
@click.option("--params", is_flag=True, show_default=True, help="Display strategy key parameters")
@click.option("--norm-values", is_flag=True, show_default=True, default=True, help="To display balances normalized by decimals")
def stratinfo(context, info, state, params, norm_values):
    _project = context.project_manager
    _chain = context.chain_manager 
    dyn = _chain.contracts.get_deployments(_project.StrategyV1StableVariable)[-1]    
    
    # Print strategy base info
    print('\nBase Info'+ln_break)
    print('Name: {}'.format(dyn.stratName()))
    print('Address: {}'.format(dyn.address))
    print('Owner: {}'.format(dyn.owner()))
    print('Vault: {}'.format(dyn.vault()))
    print('Lending Vault: {}'.format(dyn.lendingvault()))
    
    # Print strategy detailed info
    if info == True:
        print('\nDetailed Info'+ln_break)
        print('UniswapV2 Contracts:')
        print(' -> Factory: {} , Router: {}'.format(dyn.uniswap_factory(), dyn.uniswap_router()))
        print('AaveV2 Contracts:')
        print(' -> Provider: {} , Lending Pool: {} , Oracle: {}'.format(dyn.aave_provider(), dyn.aave_lending_pool(), dyn.aave_oracle()))
        print('MasterchefV2 Contract:')
        print(' -> Masterchef: {} , PoolId: {}'.format(dyn.masterchef(), dyn.poolid()))     
        print('Tokens:')
        print(' -> Stable: {} , aStable: {}'.format(dyn.stableToken(), dyn.aToken()))
        print(' -> Variable: {} , debtVariable: {}'.format(dyn.variableToken(), dyn.debtToken()))
        print(' -> LP: {} , Reward: {}'.format(dyn.lpToken(), dyn.rewardToken()))
        #print(' -> Secondary: {} , aSecondary: {}'.format(dyn.secondaryToken(), dyn.secondaryaToken()))

    # Print strategy state
    if state == True:
        if norm_values == True:
            _token = _project.ERC20.at(dyn.stableToken())
            _d = 10**int(_token.decimals())
        else:
            _d = 1
        print('\nStrategy State'+ln_break)
        print('Positions Balances:')
        print(' -> Total: {:0.4f}'.format(dyn.totalBalance()/_d))
        print(' -> Idle: {:0.4f} , Deployed: {:0.4f}'.format(dyn.getIdleBalance()/_d, dyn.deployedBalance()/_d))
        print(' -> Collateral: {:0.4f} , Debt: {:0.4f} , LP: {:0.4f}'.format(dyn.getCollateralBalance()/_d, dyn.getDebtBalance()/_d, dyn.getLpBalance(True)/_d))
        print('Collateral Ratio and Exposure State:')
        print(' -> Target Collateral Ratio: {:0.4f}'.format(dyn.targetCollatRatio()))
        print(' -> Price Exposure: {:0.2f}'.format(dyn.priceExposure()))
        print(' -> Current Collateral Ratio: {:0.4f}'.format(dyn.getCollateralRatio()))
        print(' -> Max Collateral Ratio: {:0.4f}'.format(dyn.maxCollatRatio()))
        print('Variable Token Price:')
        print(' -> Chainlink price: {:0.4f}'.format(dyn.get_variable_price(1)))
        print(' -> LP price: {:0.4f}'.format(dyn.get_variable_price(2)))
        
    # Print strategy params
    if params == True:
        print('\nStrategy Params'+ln_break)
        print('Max Allowed Params:')
        print(' -> Max Collateral Ratio Allowed: {:0.4f}'.format(dyn.maxAllowedCollatRatio()))
        print(' -> Short Max Exposure Allowed: {:0.4f} , Long Max Exposure Allowed: {:0.4f}'.format(dyn.shortAllowedExposure(), dyn.longAllowedExposure()))
        print('Swaps and Fees Params:')
        print(' -> Swaps Slippage: {:0.2f}%'.format(100*dyn.slippage()/10000))
        print(' -> Owner Fees: {:0.2f}%'.format(100*dyn.strategistFee()/10000))
        print(' -> Secondary Asset Fee: {:0.2f}%'.format(100*dyn.secondaryFee()/10000))
        print(' -> Price Protection Percentage: {:0.2f}%'.format(100*dyn.priceProtectionPerc()))

#=====================#    
# Interact with Strategy 
# as Strategist
#=====================#  
action_choices = ['DEPLOY_IDLE','REBALANCE_COLLATERAL','HARVEST','REBALANCE_EXPOSURE','SET_TARGET_CR','SET_MAX_CR','SET_EXPOSURE','SET_SLIPPAGE']
@cli.command(cls=NetworkCommand)
@ape_cli_context()
@account_option()
@click.option('-a', '--action', prompt='Choose Action', type=click.Choice(action_choices, case_sensitive=False), cls=QuestionaryOption)
@gasprice_option()
@gaslimit_option()
def strategist(context, account, action, gasprice, gaslimit):
    _project = context.project_manager
    _chain = context.chain_manager 
    dyn = _chain.contracts.get_deployments(_project.StrategyV1StableVariable)[-1]  
    
    # Check if account has strategist role
    if dyn.strategists(account) == False:
        click.echo("\nERROR - Account selected doesn't have strategist role")
        raise click.Abort()

    if action == 'DEPLOY_IDLE':
        print('Previous idle balance: {}\n'.format(dyn.getIdleBalance()))
        dyn.deployIdle(sender=account, gas_limit=gaslimit, gas_price=gasprice)
        print('\nUpdated idle balance: {}'.format(dyn.getIdleBalance()))
    
    elif action == 'REBALANCE_COLLATERAL':
        _previous_bal = dyn.totalBalance()
        _cr = dyn.getCollateralRatio()
        _maxcr = dyn.maxCollatRatio()
        if _cr < _maxcr:
            print('\nCurrent CR {:0.4f} less than MAX CR {:0.4f}'.format(_cr, _maxcr))
            raise click.Abort()
        print('Previous collateral ratio: {:0.4f}\n'.format(_cr))
        dyn.rebalance_collateral(sender=account, gas_limit=gaslimit, gas_price=gasprice)
        _updated_bal = dyn.totalBalance()
        print('\nUpdated collateral ratio: {:0.4f}'.format(dyn.getCollateralRatio()))    
        print('Rebalance loss: {:0.4f}%'.format(100*(_previous_bal-_updated_bal)/_previous_bal))

    elif action == 'HARVEST':
        _previous_bal = dyn.totalBalance()
        print('Previous total balance: {}\n'.format(_previous_bal))
        dyn.harvest(sender=account, gas_limit=gaslimit, gas_price=gasprice)
        _updated_bal = dyn.totalBalance()
        print('\nUpdated total balance: {}'.format(_updated_bal))      
        print('Harvest return: {:0.4f}%'.format(100*(_updated_bal-_previous_bal)/_previous_bal))
        
    elif action == 'REBALANCE_EXPOSURE':
        _previous_bal = dyn.totalBalance()
        print('Previous price exposure: {:0.4f}\n'.format(dyn.priceExposure()))
        value = click.prompt('Enter new exposure', type=float)
        dyn.rebalance_exposure(round(Decimal(value), 4), sender=account, gas_limit=gaslimit, gas_price=gasprice)
        _updated_bal = dyn.totalBalance()
        print('\nUpdated price exposure: {:0.4f}'.format(dyn.priceExposure()))
        print('Rebalance loss: {:0.4f}%'.format(100*(_previous_bal-_updated_bal)/_previous_bal))
        
    elif action == 'SET_TARGET_CR':
        print('Previous target cr: {:0.4f}\n'.format(dyn.targetCollatRatio()))
        value = click.prompt('Enter new target cr', type=float)
        dyn.set_target_collat_ratio(round(Decimal(value), 4), sender=account, gas_limit=gaslimit, gas_price=gasprice)
        print('\nUpdated target cr: {:0.4f}'.format(dyn.targetCollatRatio()))
    
    elif action == 'SET_MAX_CR':
        print('Previous max cr: {:0.4f}\n'.format(dyn.maxCollatRatio()))
        value = click.prompt('Enter new max cr', type=float)
        dyn.set_max_collat_ratio(round(Decimal(value), 4), sender=account, gas_limit=gaslimit, gas_price=gasprice)
        print('\nUpdated max cr: {:0.4f}'.format(dyn.maxCollatRatio()))  
        
    elif action == 'SET_EXPOSURE':
        print('Previous price exposure: {:0.4f}\n'.format(dyn.priceExposure()))
        value = click.prompt('Enter new exposure', type=float)
        dyn.set_exposure(round(Decimal(value), 4), sender=account, gas_limit=gaslimit, gas_price=gasprice)
        print('\nUpdated price exposure: {:0.4f}'.format(dyn.priceExposure()))
        
    elif action == 'SET_SLIPPAGE':
        print('Previous slippage: {}\n'.format(dyn.slippage()))
        value = click.prompt('Enter new exposure (must be b/w 9000 and 10000)', type=int)
        dyn.set_slippage(value, sender=account, gas_limit=gaslimit, gas_price=gasprice)
        print('\nUpdated slippage: {}'.format(dyn.slippage()))    
        
        

#=====================#    
# Interact with Strategy 
# as Owner
#=====================#  
action_choices = ['SET_OWNER','SET_STRATEGIST','SET_KEEPER','SET_MAX_ALLOWED_CR','SET_MAX_ALLOWED_EXPOSURE']
@cli.command(cls=NetworkCommand)
@ape_cli_context()
@account_option()
@click.option('-a', '--action', prompt='Choose Action', type=click.Choice(action_choices, case_sensitive=False), cls=QuestionaryOption)
@gasprice_option()
@gaslimit_option()
def owner(context, account, action, gasprice, gaslimit):
    _project = context.project_manager
    _chain = context.chain_manager 
    dyn = _chain.contracts.get_deployments(_project.StrategyV1StableVariable)[-1]  
    
    # Check if account is owner
    if dyn.owner() != account:
        click.echo("\nERROR - Account selected is not the owner")
        raise click.Abort()

    if action == 'SET_OWNER':
        value = click.prompt('Enter address for new owner', type=str)
        dyn.set_owner(value, sender=account, gas_limit=gaslimit, gas_price=gasprice)
        print('\nUpdated owner: {}'.format(dyn.owner()))
    
    elif action == 'SET_STRATEGIST':
        value = click.prompt('Enter address to update strategist status', type=str)
        dyn.set_strategist(value, sender=account, gas_limit=gaslimit, gas_price=gasprice)
        print('\nUpdated strategist status: {}'.format(dyn.strategists(value)))

    elif action == 'SET_KEEPER':
        value = click.prompt('Enter address to update keeper status', type=str)
        dyn.set_keeper(value, sender=account, gas_limit=gaslimit, gas_price=gasprice)
        print('\nUpdated keeper status: {}'.format(dyn.strategists(value)))

    elif action == 'SET_MAX_ALLOWED_CR':
        print('Previous max allowed cr: {:0.4f}\n'.format(dyn.maxAllowedCollatRatio()))
        value = click.prompt('Enter max allowed cr', type=float)
        dyn.set_max_allowed_collat_ratio(round(Decimal(value), 4), sender=account, gas_limit=gaslimit, gas_price=gasprice)
        print('\nUpdated max allowed cr: {:0.4f}'.format(dyn.maxAllowedCollatRatio()))

    elif action == 'SET_MAX_ALLOWED_EXPOSURE':
        print('Previous max allowed cr: short {:0.4f} , long {:0.4f}\n'.format(dyn.shortAllowedExposure(),dyn.longAllowedExposure()))
        short_value = click.prompt('Enter SHORT max allowed cr', type=float)
        long_value = click.prompt('Enter LONG max allowed cr', type=float)
        dyn.set_max_allowed_exposure(round(Decimal(short_value), 4), round(Decimal(long_value), 4), sender=account, gas_limit=gaslimit, gas_price=gasprice)
        print('\nUpdated max allowed cr: short {:0.4f} , long {:0.4f}\n'.format(dyn.shortAllowedExposure(),dyn.longAllowedExposure()))



if __name__ == "__main__":
    cli()