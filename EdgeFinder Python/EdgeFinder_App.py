import streamlit as st
import pandas as pd
from engine import calculate_edge_score

st.set_page_config(page_title="Custom Edgefinder Dashboard", layout="wide")
st.title("Edgefinder Pro Custom Architecture")

# Normalized baseline environment matrix
market_environment = {
    "EUR/USD": {"retail_long_pct": 28, "cot_net_bias": 1, "trend_sma_200": "above", "interest_rate_diff": -1.2},
    "GBP/USD": {"retail_long_pct": 72, "cot_net_bias": -1, "trend_sma_200": "below", "interest_rate_diff": -0.5},
    "USD/JPY": {"retail_long_pct": 42, "cot_net_bias": 2, "trend_sma_200": "above", "interest_rate_diff": 2.5}
}

st.subheader("Global Market Bias Overview")

# Compute current standings matrix
table_rows = []
for ticker, attributes in market_environment.items():
    total_score, _ = calculate_edge_score(attributes)
    
    if total_score >= 4:
        posture = "Strong Bullish Bias"
    elif total_score <= -4:
        posture = "Strong Bearish Bias"
    else:
        posture = "Neutral Allocation"
        
    table_rows.append({
        "Ticker Asset": ticker,
        "Composite Edge Score": f"{total_score} / 10",
        "Strategic Posture": posture
    })

st.table(pd.DataFrame(table_rows))

st.markdown("---")
st.subheader("Granular Factor Analysis Breakdown")

target_asset = st.selectbox("Isolate Asset Profiles:", list(market_environment.keys()))
active_profile = market_environment[target_asset]
final_value, dimensional_weights = calculate_edge_score(active_profile)

col1, col2 = st.columns(2)
with col1:
    st.metric(label=f"Net Structural Score: {target_asset}", value=f"{final_value} points")
with col2:
    st.write("Component Vector Strengths:")
    st.json(dimensional_weights)