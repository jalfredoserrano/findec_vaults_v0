from ape import accounts, project, chain
from decimal import Decimal
from web3 import Web3, constants

max_uint = Web3.toInt(hexstr=constants.MAX_INT) 

dev = accounts.load("js_test")
gas_price=300*10**9
gas_limit=7000000

"""
USDC
"""
usdc = '0x04068DA6C83AFCFA0e13ba15A6696662335D5B75'
atoken = '0x0638546741f12fA55F840A763A5aEF9671C74Fc1'
poolid = 11

"""
DAI    
"""
dai = "0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E"
grainDai = "0x8e4bFB85962A63caCfa2C0fde5eaD86D9b120B16"
dai_poolid = 12

"""
FTM    
"""
debtftm = '0x0f7f11AA3C42aaa5e653EbEd07220B4392a976A4'
wftm = '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83'
grainftm = '0x98d5105370191D641f32589B35cDa9eCd367C74F'

"""
Roles and Admin
"""
strategist = '0xed094343893b4fca30b2eacefb609bb341c2d2b7'

"""
Strategy Params    
"""
strat_name = "ftm-dai-0"
tcr = Decimal('0.6')
mincr = Decimal('0.45')
maxcr =  Decimal('0.65')
maxallowedcr = Decimal('0.8')
exposure = Decimal('0.0')
maxshortexposure = Decimal('-0.25')
maxlongexposure = Decimal('0.25')
ethresh = Decimal('0.05')

"""
Tokens
"""
stable_token = dai
variable_token = wftm
a_token = grainDai
debt_token = debtftm
rewardtoken = '0x10b620b2dbAC4Faa7D7FFD71Da486f5D44cd86f9'

"""
Contracts Addressess    
"""
provider = '0x8b9D58E2Dc5e9b5275b62b1F30b3c0AC87138130'
router = '0xF491e7B69E4244ad4002BC14e878a34207E38c29'
factory = '0x152eE697f2E276fA89E96742e9bB9aB1F2E61bE3'
masterchef = '0x6e2ad6527901c9664f016466b8DA1357a004db0f'
rewarder = '0x7780e1a8321bd58bbc76594db494c7bfe8e87040'
poolid = dai_poolid

def main():
    # Deploy vault
    vlt = project.ERC4626DynamicHedgingVault.deploy(dai, sender=dev, gas_limit=gas_limit, gas_price=gas_price) 
    #vlt = chain.contracts.get_deployments(project.ERC4626DynamicHedgingVault)[-1]
    
    # Deploy lending vault
    lending_vlt = project.ERC4626LendingVault.deploy(wftm, sender=dev, gas_limit=gas_limit, gas_price=gas_price)
    #lending_vlt = chain.contracts.get_deployments(project.ERC4626LendingVault)[-1]
    
    # Deploy Strategy
    vault = vlt.address
    lendingvault = lending_vlt.address
    dyn = project.StrategyV1StableVariable.deploy(strat_name, vault, lendingvault, stable_token, variable_token, a_token, debt_token, rewardtoken, tcr, mincr,
                                           maxcr, maxallowedcr, exposure, ethresh, maxshortexposure, maxlongexposure, 
                                           sender=dev, gas_limit=gas_limit, gas_price=gas_price)
    
    # Approve tokens
    daiERC = project.ERC20.at(dai)
    wftmERC = project.ERC20.at(wftm)
    daiERC.approve(dyn.address, max_uint, sender=dev, gas_limit=gas_limit, gas_price=gas_price)
    daiERC.approve(vlt.address, max_uint, sender=dev, gas_limit=gas_limit, gas_price=gas_price)
    wftmERC.approve(lending_vlt.address, max_uint, sender=dev, gas_limit=gas_limit, gas_price=gas_price)
    
    # Initialize contracts
    vlt.initializeVault(dyn.address, sender=dev, gas_limit=gas_limit, gas_price=gas_price)
    lending_vlt.initializeVault(dyn.address, sender=dev, gas_limit=gas_limit, gas_price=gas_price)
    base_amount = 1*10**daiERC.decimals()
    secondary_token = wftm
    secondary_atoken = grainftm
    dyn.initializeStrategy(base_amount, factory, router, provider, rewarder, masterchef, poolid, secondary_token, secondary_atoken, sender=dev, gas_price=gas_price, gas_limit=gas_limit)
    
    # Print
    print('Vault Address: {}'.format(vlt.address))
    print('Lending Vault Address: {}'.format(lending_vlt.address))
    print('Strategy Address: {}'.format(dyn.address))
    