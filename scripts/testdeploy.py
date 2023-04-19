from ape import accounts, project
from decimal import Decimal
from web3 import Web3, constants

max_uint = Web3.toInt(hexstr=constants.MAX_INT) 

dev = accounts.load("js_test")
gas_price=300*10**9
gas_limit=7000000

usdc = '0x04068DA6C83AFCFA0e13ba15A6696662335D5B75'

def main():
    # Deploy vault
    vlt = project.TestERC4626.deploy(usdc, sender=dev, gas_limit=gas_limit, gas_price=gas_price) 
    
    print('Address: {}'.format(vlt.address))
    