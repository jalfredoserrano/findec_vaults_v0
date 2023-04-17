import click
from ape import networks
from ape.cli import network_option, account_option
from decimal import Decimal

class NetworkGroup(click.Group):
    """ 
    Custom group command that will automatically set the network for the duration of the (sub)command execution.
    """
    def resolve_command(self, ctx, args):
        value = ctx.params.get("network") or networks.default_ecosystem.name
        with networks.parse_network_choice(value):
            _, cmd, args = super().resolve_command(ctx, args)
            return cmd.name, cmd, args


@click.command(cls=NetworkGroup)
@network_option()
def cli(network):
    print('Using network: {}/n'.format(network))

@cli.command()
@account_option()
def main(account):
    print('Test')
    
if __name__ == "__main__":
    cli()
    
    