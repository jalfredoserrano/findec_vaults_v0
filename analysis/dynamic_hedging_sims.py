# -*- coding: utf-8 -*-

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

#=========================================#
# SIMULATE STRATEGIES

# Functions
#   Get want state
#   Set target exposure and collateral ratio
#   Update collateral
#   Update debt
#   Update liquidity pool
#   Collateral rebalance
#   Exposure rebalance
#   Update exposure
#   run simulation

# NOTE: need to work on updating rebal functions to support weigthed pools
# NOTE: w1 represents the variable token weight
#=========================================#


# Get want state
def want_state(t: float, tcr: float, te: float, w: float=0.5):
    """
    Function returns the want state of the strategy given a target collateral ratio and target exposure.

    Parameters
    ----------
    t : float
        Total amount to split b/w positions.
    tcr : float
        Target collateral ratio (b/w 0 to 1).
    te : float
        Target exposure(b/w -0.5 to 0.5).

    Returns
    -------
    _c : float
        Collateral value.
    _d : float
        Debt value.
    _l : float
        LP value.
    """
    
    _te = te*t    
    _c = (t - _te/w)/(1 - tcr*(1 - 1/w))
    _d = _c*tcr
    _l = t - _c + _d
        
    return _c, _d, _l

# Get state
def get_state(c:float, d: float, l:float, w: float=0.5):
    _cr = d/c
    _e = (l*w - d)/(c-d+l)
    return _cr, _e

# Update collateral
def update_collateral(c: float, r: float):
    return c*(1+r)

# Update debt
def update_debt(d: float, p_chg: float, r: float):
    return d*(1+p_chg)*(1+r)

# Update lp
def update_lp(l: float, r: float, p1_chg: float, p2_chg: float=0, w1: float=0.5, w2: float=0.5):
    return l*(1+r)*((1+p1_chg)**w1)*(1+p2_chg)**w2

# Update all positions
def update_all(c:float, d: float, l:float, rc: float, rd: float, rl: float, p1_chg: float, p2_chg: float=0, w1: float=0.5, w2: float=0.5):
    _c = update_collateral(c, rc)
    _d = update_debt(d, p1_chg, rd)
    _l = update_lp(l, rl, p1_chg, p2_chg, w1, w2)
    return _c, _d, _l

# Collateral rebalance
def cr_rebal(c:float, d: float, l:float, tcr: float):
    _a = (d-c*tcr)/(1+tcr)
    _c = c + _a
    _d = d - _a
    _l = l - 2*_a
    return _a, _c, _d, _l

# Exposure rebalance
def exposure_rebal(c:float, d: float, l:float, te: float, w: float=0.5, swapfee: float=0.0025):
    _e = (c-d+l)*te
    _a = 2*(_e-w*l+d)
    _c = c
    _d = d - _a*(1-swapfee/2) # divide swapfee by 2 since only 50% of the liquidity removed will be swapped
    _l = l - _a
    return _e, _a, _c, _d, _l

#Update exposure
def update_exposure(c:float, d: float, l:float, te: float, tcr: float, swapfee: float=0.0025):
    # Get new want state given target exposure
    _t = c - d + l
    _c, _d, _l = want_state(_t, tcr, te)
    
    # remove all liquidity
    _token1 = l/2
    _token2 = l/2
    
    # Check if collateral needs to be added
    _c_add = _c - c
    if _c_add > 0:
        if _token1 >= _c_add:
            _token1 -= _c_add
            c_fnl = c + _c_add
        else:
            _c_missing = _c_add - _token1
            _token2 -= _c_missing
            _token1 += _c_missing*(1-swapfee)
            c_fnl = c + _token1
            _token1 = 0
            
    # Check if debt must be repaid
    _d_repay = d - _d
    if _d_repay > 0:
        if _token2 >= _d_repay:
            _token2 -= _d_repay
            d_fnl = d - _d_repay
        else:
            _d_missing = _d_repay - _token2
            _token1 -= _d_missing
            _token2 += _d_missing*(1-swapfee)
            d_fnl = d - _token2
            _token2 = 0
            
    # Check if collateral needs to be removed
    _c_remove = c - _c
    if _c_remove > 0:
        c_fnl = c - _c_remove
        _token1 += _c_remove
        
    # Check if need to borrow
    _d_borrow = _d - d
    if _d_borrow > 0:
        d_fnl = d + _d_borrow
        _token2 += _d_borrow
        
    # Add remaining assets to liquidity pool
    if _token1 > _token2:
        _swap_qty = (_token1 - _token2)/2
        _token1 -= _swap_qty
        _token2 += _swap_qty*(1-swapfee)
    elif _token2 > _token1:
        _swap_qty = (_token2 - _token1)/2
        _token2 -= _swap_qty
        _token1 += _swap_qty*(1-swapfee)        
    l_fnl = _token1 + _token2
    
    return c_fnl, d_fnl, l_fnl, _c, _d, _l



class SimulateStrat:
    
    def __init__(self, t: float, tcr: float, te: float, w1: float=0.5, w2: float=0.5, swapfee: float=0.0025):
        # Set key params
        self.tcr = tcr
        self.te = te
        self.w1 = w1
        self.w2 = w2
        self.swapfee = swapfee
        
        # Get initial state
        _c, _d, _l = self.want_state(t)
        self.c = _c
        self.d = _d
        self.l = _l
                
    def reset_strat(self, t: float):
        _c, _d, _l = self.want_state(t)
        self.c = _c
        self.d = _d
        self.l = _l
        
    def want_state(self, t):
        return want_state(t, self.tcr, self.te, self.w1)
    
    def get_state(self):
        return get_state(self.c, self.d, self.l, self.w1)
    
    def get_total(self):
        return self.c-self.d+self.l
    
    def update_all(self, rc: float, rd: float, rl: float, p1_chg: float, p2_chg: float=0):
         _c, _d, _l = update_all(self.c, self.d, self.l, rc, rd, rl, p1_chg, p2_chg, self.w1, self.w2)
         self.c = _c
         self.d = _d
         self.l = _l

    def cr_rebal(self):
        _a, _c, _d, _l = cr_rebal(self.c, self.d, self.l, self.tcr)
        self.c = _c
        self.d = _d
        self.l = _l

    def exposure_rebal(self):
        _e, _a, _c, _d, _l = exposure_rebal(self.c, self.d, self.l, self.te, self.w1, self.swapfee)
        self.c = _c
        self.d = _d
        self.l = _l

    def update_exposure(self, te: float):
        c_fnl, d_fnl, l_fnl, _c, _d, _l = update_exposure(self.c, self.d, self.l, te, self.tcr, self.swapfee)
        self.te = te
        self.c = c_fnl
        self.d = d_fnl
        self.l = l_fnl

    def run(self, pricefeed: list[float], c_apr: float, d_apr: float, l_apr: float, min_per_step: float, max_cr: float, e_thresh: float, min_cr: float, update_exposure: list[float]=[]):
        
        # Get yield per step
        steps_per_year = 365*24*60/min_per_step
        c_yield = c_apr/steps_per_year
        d_yield = d_apr/steps_per_year
        l_yield = l_apr/steps_per_year
        
        # Get price percentage change
        pricechange = np.array(pricefeed)
        pricechange = np.diff(pricechange) / np.abs(pricechange[:-1])
        
        # Save initial state
        _cr, _e = self.get_state()
        c_feed = [self.c]
        d_feed = [self.d]
        l_feed = [self.l]
        t_feed = [self.get_total()]
        cr_feed = [_cr]
        e_feed = [_e]
        updt_cr_feed = [_cr]
        updt_e_feed = [_e]
        action_feed = ['No Action']
        te_feed = [self.te]

        if len(update_exposure) == 0:
            update_exposure = [self.te]*len(pricechange)
        elif len(update_exposure) == len(pricechange)+1:
            update_exposure.pop(0)
        
        for p, u in zip(pricechange, update_exposure):
            # Update state with given price change
            self.update_all(c_yield, d_yield, l_yield, p)
            _cr, _e = self.get_state()
            cr_feed.append(_cr)
            e_feed.append(_e)
            
            # Check if exposure needs to be updated
            u_rebal = False
            if u != self.te:
                self.update_exposure(u)
                u_rebal = True
                _cr, _e = self.get_state()
            
            # Check if exposure needs to be rebalanced
            e_rebal = False
            if abs(self.te - _e) > e_thresh:
                self.exposure_rebal()
                e_rebal = True
                _cr, _e = self.get_state()
                
            # Check if collateral needs to be rebalanced
            cr_rebal = False
            if _cr > max_cr or _cr < min_cr:
                self.cr_rebal()
                cr_rebal = True
                
            # Save state
            _cr, _e = self.get_state()
            c_feed.append(self.c)
            d_feed.append(self.d)
            l_feed.append(self.l)
            t_feed.append(self.get_total())
            updt_cr_feed.append(_cr)
            updt_e_feed.append(_e)
            te_feed.append(self.te)
            if e_rebal == True and cr_rebal == True:
                action = 'Both'
            elif u_rebal == True:
                action = 'Updated Exposure'
            elif e_rebal == True:
                action = 'Exposure'
            elif cr_rebal == True:
                action = 'Collateral'
            else:
                action = 'No Action'
            action_feed.append(action)
        
        # Save feeds
        self.c_feed = c_feed
        self.d_feed = d_feed
        self.l_feed = l_feed
        self.t_feed = t_feed
        self.cr_feed = cr_feed
        self.e_feed = e_feed
        self.updt_cr_feed = updt_cr_feed
        self.updt_e_feed = updt_e_feed
        self.action_feed = action_feed
        self.pricefeed = pricefeed
        self.pricechange = np.insert(pricechange, 0, 0).tolist()
        self.te_feed = te_feed
        
        # Feeds to df
        self.simdf = pd.DataFrame({
            'Collateral': c_feed,
            'Debt': d_feed,
            'LP': l_feed,
            'Total': t_feed,
            'CR': cr_feed,
            'Exposure': e_feed,
            'Updated CR': updt_cr_feed,
            'Updated Exposure': updt_e_feed,
            'Action': action_feed,
            'Price': pricefeed,
            'Price Change': self.pricechange,
            'Target Exposure': self.te_feed
        }).reset_index()
        
        # Daily and weekly returns
        periods_per_day = 24*60/min_per_step
        self.simdf['daily_return'] = self.simdf['Total'].pct_change(int(periods_per_day))
        periods_per_week = 7*24*60/min_per_step
        self.simdf['weekly_return'] = self.simdf['Total'].pct_change(int(periods_per_week))
        
        # Save sim params
        self.min_per_step = min_per_step
        self.max_cr = max_cr
        self.e_thresh = e_thresh
        self.min_cr = min_cr
        
    def print_sim_stats(self):
        initial_value = self.t_feed[0]
        final_value = self.t_feed[-1]
        
        print('\n----------------------Strategy Total----------------------')
        print('Strategy Initial: ${0:.2f}'.format(initial_value))
        print('Strategy Final: ${0:.2f}'.format(final_value))
        print('Strategy Max: ${0:.2f}'.format(max(self.t_feed)))
        print('Strategy Min: ${0:.2f}'.format(min(self.t_feed)))
        
        print('\n--------------------Strategy Timeframe--------------------')
        total_days = self.min_per_step*len(self.pricefeed)/(60*24)
        print('Total time in days: {}'.format(total_days))
        
        print('\n--------------------Strategy Returns--------------------')
        total_return = final_value - initial_value
        yearly_return = 365*(total_return/total_days)/initial_value
        print('Return: {0:.3f}%'.format(100*total_return/initial_value))  
        print('Total Return: ${0:.5f}'.format(total_return))        
        print('Annualized Return: {0:.3f}%'.format(100*yearly_return)) 
        print('Max Daily Return: {0:.3f}%'.format(100*self.simdf['daily_return'].max())) 
        print('Min Daily Return: {0:.3f}%'.format(100*self.simdf['daily_return'].min()))         
        print('Max Weekly Return: {0:.3f}%'.format(100*self.simdf['weekly_return'].max())) 
        print('Min Weekly Return: {0:.3f}%'.format(100*self.simdf['weekly_return'].min()))  

        print('\n---------------------Strategy Params----------------------')
        print('Max Collateral Ratio: {0:.2f}'.format(max(self.cr_feed)))
        print('Max Exposure: {0:.2f}'.format(max(self.e_feed)))
        print('Min Collateral Ratio: {0:.2f}'.format(min(self.cr_feed)))
        print('Min Exposure: {0:.2f}'.format(min(self.e_feed)))   
        
        print('\n---------------------Strategy Actions----------------------')
        print('Count of Collateral Rebalance: {}'.format(sum([x == 'Collateral' for x in self.action_feed])))
        print('Count of Exposure Rebalance: {}'.format(sum([x == 'Exposure' for x in self.action_feed])))
        print('Count of Both Rebalance: {}'.format(sum([x == 'Both' for x in self.action_feed])))
        print('Count of Exposure Update: {}'.format(sum([x == 'Updated Exposure' for x in self.action_feed])))
        
    def plot_totals(self, include_positions: bool = False, save_fig: bool = False):      
        df = self.simdf
        
        # Plot
        fig, ax = plt.subplots()
        fig.set_size_inches(20,10)
        
        ax.plot(df['Total'], color = 'black', label = 'Total Value' )
        ax.legend(loc = 'lower left')
        ax.set_ylabel('Strategy Total Value')
        
        if include_positions == True:
            ax2 = ax.twinx()
            ax2.plot(df['Collateral'], color = 'blue', label = 'Collateral')
            ax2.plot(df['Debt'], color = 'red', label = 'Debt')
            ax2.plot(df['LP'], color = 'green', label = 'LP')
            ax2.ticklabel_format(useOffset=False, style='plain')
            ax2.legend(loc = 'lower right')
            ax2.set_ylabel('Positions Value')
        
        if save_fig ==  False:
            plt.show()    
        else:
            plt.savefig('sim_totals.png')
        
    def plot_totals_with_rebalance_points(self, save_fig: bool = False):
        df = self.simdf
        
        # Create rebalance points to plot
        df['rebal_plot'] = np.where(df['Action'] == 'No Action', np.nan, df['Total'])

        # Plot        
        fig, ax = plt.subplots()
        fig.set_size_inches(20,10)
        
        ax.plot('index', 'Total', data=df, color = 'black', label = 'Total Value', alpha=0.75)
        color_palette = {"Collateral":"blue", "Exposure":"orange", "Both":"purple", "No Action":"white", "Updated Exposure":"red"}
        sns.scatterplot(x='index', y='rebal_plot', data=df, hue="Action", ax=ax, palette=color_palette, s=100)
        ax.legend(loc = 'lower right')
        ax.set_ylabel('Strategy Total Value')
        
        ax2 = ax.twinx()
        ax2.plot('index', 'Price', data=df, label = 'Price', color = 'red')      
        ax2.legend(loc = 'lower left')  
        ax2.set_ylabel('FTM Price')

        if save_fig ==  False:
            plt.show()    
        else:
            plt.savefig('sim_with_rebal.png')

    def plot_total_vs_price(self, save_fig: bool = False):
        df = self.simdf
        
        # Plot 
        fig, ax = plt.subplots()
        fig.set_size_inches(20,10)
        
        ax.plot('index', 'Total', data=df, color = 'black', label = 'Total Value' )
        ax.legend(loc = 'lower left')   
        ax.set_ylabel('Strategy Total Value')
        ax2 = ax.twinx()
        ax2.plot('index', 'Price', data=df, label = 'Price', color = 'green')      
        ax2.legend(loc = 'lower right')  
        ax2.set_ylabel('FTM Price')
        
        if save_fig ==  False:
            plt.show()    
        else:
            plt.savefig('sim_vs_price.png')
            
    def plot_cr_exposure(self, save_fig: bool = False):
        df = self.simdf
        
        # Create rebalance points to plot
        df['rebal_cr'] = np.where(df['Action'] == 'Collateral', df['CR'], np.nan)
        df['rebal_exposure'] = np.where(df['Action'] == 'Exposure', df['Exposure'], np.nan)
        
        # Plot 
        fig, ax = plt.subplots()
        fig.set_size_inches(20,10)

        ax.plot('index', 'CR', data=df, color='blue', label='CR' )
        ax.plot('index', 'rebal_cr', data=df, markersize=10, color='green', linestyle='', marker='o', label='Collateral Rebalance')
        ax.axhline(y = self.max_cr, color = 'purple', linestyle = '--', label='Max CR')
        ax.axhline(y = self.min_cr, color = 'purple', linestyle = '--', label='Min CR')
        ax.legend(loc = 'lower right')   
        ax.set_ylabel('Collateral Ratio')
        
        ax2 = ax.twinx()
        ax2.plot('index', 'Exposure', data=df, color='orange', label='Exposure')      
        ax2.plot('index', 'rebal_exposure', data=df, markersize=10, color='red', linestyle='', marker='o', label='Exposure Rebalance')
        ax2.axhline(y = self.te+self.e_thresh, color = 'y', linestyle = '--', label='Max Exposure')
        ax2.axhline(y = self.te-self.e_thresh, color = 'y', linestyle = '--', label='Min Exposure')
        ax2.legend(loc = 'lower left')  
        ax2.set_ylabel('Exposure')
        
        if save_fig ==  False:
            plt.show()    
        else:
            plt.savefig('cr_and_exposure.png')
 
    def plot_te_with_price_levels(self, price_ranges, save_fig: bool = False):
        df = self.simdf

        fig, ax = plt.subplots()
        fig.set_size_inches(20,10)
        
        ax.plot('index', 'Target Exposure', data=df, color='black', label='te' )
        ax.legend(loc = 'lower right')
        ax.set_ylabel('Target Exposure')
        
        ax2 = ax.twinx()
        ax2.plot('index', 'Price', data=df, label='Price', color='red')      
        ax2.legend(loc = 'lower left')  
        ax2.set_ylabel('FTM Price')
        
        for k, v in price_ranges.items():
            ax2.axhline(y=k, color='purple', linestyle = '--')
        
        if save_fig ==  False:
            plt.show()    
        else:
            plt.savefig('cr_and_exposure.png')
    





















































