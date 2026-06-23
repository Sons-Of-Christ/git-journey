import streamlit as st
import pandas as pd
import yfinance as yf
from engine import calculate_edge_score

st.set_page_config(page_title="EdgeFinder Pro", layout="wide")
st.title("EdgeFinder Pro Custom Architecture")

# --- NEW: Live Data Fetching Function ---
@st.cache_data(ttl=3600) # Caches the data for 1 hour so it doesn't slow down your app
def get_live_trend(yahoo_ticker):
    try:
        # Download the last year of daily price data
        data = yf.download(yahoo_ticker, period="1y", progress=False)
        
        # Calculate the 200-day Simple Moving Average
        data['SMA_200'] = data['Close'].rolling(window=200).mean()
        
        # Get the most recent price and SMA
        current_price = float(data['Close'].iloc[-1])
        current_sma = float(data['SMA_200'].iloc[-1])
        
        # Determine if price is above or below the trend
        if current_price > current_sma:
            return "above"
        else:
            return "below"
    except Exception as e:
        return "above" # Fallback in case of error

st.write("Fetching live market data...")

# --- UPDATE: Mixing Live Data with our other manual metrics ---
# Note: Yahoo Finance uses specific ticker formats for Forex (e.g., EURUSD=X)
market_environment = {
    # --- Forex Majors & Exotics ---
    "EUR/USD": {"retail_long_pct": 28, "cot_net_bias": 1, "trend_sma_200": get_live_trend("EURUSD=X"), "interest_rate_diff": -1.2},
    "GBP/USD": {"retail_long_pct": 72, "cot_net_bias": -1, "trend_sma_200": get_live_trend("GBPUSD=X"), "interest_rate_diff": -0.5},
    "USD/JPY": {"retail_long_pct": 42, "cot_net_bias": 2, "trend_sma_200": get_live_trend("USDJPY=X"), "interest_rate_diff": 2.5},
    "AUD/USD": {"retail_long_pct": 55, "cot_net_bias": 0, "trend_sma_200": get_live_trend("AUDUSD=X"), "interest_rate_diff": -0.2},
    "USD/CAD": {"retail_long_pct": 60, "cot_net_bias": -1, "trend_sma_200": get_live_trend("USDCAD=X"), "interest_rate_diff": 0.1},
    "NZD/USD": {"retail_long_pct": 45, "cot_net_bias": 1, "trend_sma_200": get_live_trend("NZDUSD=X"), "interest_rate_diff": -0.4},
    "USD/CHF": {"retail_long_pct": 35, "cot_net_bias": 1, "trend_sma_200": get_live_trend("USDCHF=X"), "interest_rate_diff": 1.5},
    "USD/ZAR": {"retail_long_pct": 50, "cot_net_bias": 0, "trend_sma_200": get_live_trend("USDZAR=X"), "interest_rate_diff": 3.5},
    
    # --- JPY Crosses ---
    "EUR/JPY": {"retail_long_pct": 30, "cot_net_bias": 1, "trend_sma_200": get_live_trend("EURJPY=X"), "interest_rate_diff": 1.5},
    "GBP/JPY": {"retail_long_pct": 25, "cot_net_bias": 2, "trend_sma_200": get_live_trend("GBPJPY=X"), "interest_rate_diff": 2.0},
    "AUD/JPY": {"retail_long_pct": 40, "cot_net_bias": 0, "trend_sma_200": get_live_trend("AUDJPY=X"), "interest_rate_diff": 1.2},
    "CAD/JPY": {"retail_long_pct": 45, "cot_net_bias": 0, "trend_sma_200": get_live_trend("CADJPY=X"), "interest_rate_diff": 1.0},
    "NZD/JPY": {"retail_long_pct": 50, "cot_net_bias": -1, "trend_sma_200": get_live_trend("NZDJPY=X"), "interest_rate_diff": 0.8},
    "CHF/JPY": {"retail_long_pct": 20, "cot_net_bias": 1, "trend_sma_200": get_live_trend("CHFJPY=X"), "interest_rate_diff": 0.5},
    
    # --- Metals ---
    "Gold (XAU/USD)": {"retail_long_pct": 65, "cot_net_bias": 2, "trend_sma_200": get_live_trend("XAUUSD=X"), "interest_rate_diff": 0.0},
    "Silver (XAG/USD)": {"retail_long_pct": 70, "cot_net_bias": 1, "trend_sma_200": get_live_trend("XAGUSD=X"), "interest_rate_diff": 0.0},
    
    # --- Energy ---
    "US Oil (WTI Crude)": {"retail_long_pct": 55, "cot_net_bias": 1, "trend_sma_200": get_live_trend("CL=F"), "interest_rate_diff": 0.0},
    
    # --- US Indices ---
    "S&P 500": {"retail_long_pct": 40, "cot_net_bias": 2, "trend_sma_200": get_live_trend("^GSPC"), "interest_rate_diff": 0.0},
    "NASDAQ 100": {"retail_long_pct": 45, "cot_net_bias": 1, "trend_sma_200": get_live_trend("^NDX"), "interest_rate_diff": 0.0},
    "Dow Jones": {"retail_long_pct": 50, "cot_net_bias": 0, "trend_sma_200": get_live_trend("^DJI"), "interest_rate_diff": 0.0},
    
    # --- European Indices ---
    "DAX 40 (GER)": {"retail_long_pct": 55, "cot_net_bias": -1, "trend_sma_200": get_live_trend("^GDAXI"), "interest_rate_diff": 0.0},
    "FTSE 100 (UK)": {"retail_long_pct": 60, "cot_net_bias": 0, "trend_sma_200": get_live_trend("^FTSE"), "interest_rate_diff": 0.0},
    "CAC 40 (FRA)": {"retail_long_pct": 50, "cot_net_bias": 0, "trend_sma_200": get_live_trend("^FCHI"), "interest_rate_diff": 0.0},
    
    # --- Cryptocurrencies ---
    "Bitcoin (BTC)": {"retail_long_pct": 80, "cot_net_bias": -2, "trend_sma_200": get_live_trend("BTC-USD"), "interest_rate_diff": 0.0},
    "Ethereum (ETH)": {"retail_long_pct": 75, "cot_net_bias": -1, "trend_sma_200": get_live_trend("ETH-USD"), "interest_rate_diff": 0.0},
    "Ripple (XRP)": {"retail_long_pct": 60, "cot_net_bias": 0, "trend_sma_200": get_live_trend("XRP-USD"), "interest_rate_diff": 0.0},
    "Cardano (ADA)": {"retail_long_pct": 65, "cot_net_bias": 0, "trend_sma_200": get_live_trend("ADA-USD"), "interest_rate_diff": 0.0},
    "Polygon (POL)": {"retail_long_pct": 50, "cot_net_bias": 0, "trend_sma_200": get_live_trend("POL-USD"), "interest_rate_diff": 0.0}
}

st.subheader("Global Market Bias Overview")

# Compute current standings matrix
table_rows = []
for ticker, attributes in market_environment.items():
    total_score, breakdown = calculate_edge_score(attributes)
    
    if total_score >= 4:
        posture = "🟢 Strong Bullish Bias"
    elif total_score <= -4:
        posture = "🔴 Strong Bearish Bias"
    else:
        posture = "⚪ Neutral Allocation"
        
    table_rows.append({
        "Ticker Asset": ticker,
        "Composite Edge Score": f"{total_score} / 10",
        "Live Trend": attributes['trend_sma_200'].upper(), # Show the live trend in the table
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