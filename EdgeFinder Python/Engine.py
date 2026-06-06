def calculate_edge_score(metrics):
    """
    Computes an aggregated score from -10 to +10.
    Expects data format:
    {
        'retail_long_pct': float (0-100),
        'cot_net_bias': int (-2 to 2),
        'trend_sma_200': str ('above' or 'below'),
        'interest_rate_diff': float (yield spread)
    }
    """
    score = 0
    breakdown = {}
    
    # Factor 1: Retail Sentiment (Contrarian Execution Strategy)
    # High long volume yields a negative rating, low long volume yields a positive rating
    if metrics['retail_long_pct'] >= 65:
        score -= 2
        breakdown['Retail Sentiment'] = -2
    elif metrics['retail_long_pct'] <= 35:
        score += 2
        breakdown['Retail Sentiment'] = 2
    else:
        breakdown['Retail Sentiment'] = 0
        
    # Factor 2: Institutional Positioning (Commitment of Traders Data)
    cot_impact = metrics['cot_net_bias'] * 2
    score += cot_impact
    breakdown['Institutional (COT)'] = cot_impact
    
    # Factor 3: Structural Technical Trend (200-Period Simple Moving Average)
    if metrics['trend_sma_200'] == 'above':
        score += 2
        breakdown['Trend Alignment'] = 2
    else:
        score -= 2
        breakdown['Trend Alignment'] = -2
        
    # Factor 4: Macro Yield Differentials
    if metrics['interest_rate_diff'] >= 1.0:
        score += 2
        breakdown['Interest Rate Spread'] = 2
    elif metrics['interest_rate_diff'] <= -1.0:
        score -= 2
        breakdown['Interest Rate Spread'] = -2
    else:
        breakdown['Interest Rate Spread'] = 0
        
    return score, breakdown