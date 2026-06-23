//+------------------------------------------------------------------+
//|                                        ATR-IntraDay_Swing-EA.mq5 |
//|                                                   Sons-Of-Christ |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Sons-Of-Christ"
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//|      ATR Swing EA (D1 Bias + H4 Confirmation)                    |
//|      Sons-Of-Christ                                              |
//+------------------------------------------------------------------+
#property version   "1.30"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//================ INPUTS =================//
input double LotSize            = 0.10;
input int    MaxTrades          = 3;

input int    FastEMA            = 50;
input int    SlowEMA            = 200;

input int    ATR_Period         = 14;
input double SL_ATR_Multiplier  = 1.5;
input double TP_ATR_Multiplier  = 3.0;

input int    MaxSpread          = 2000;

// Sessions (SERVER TIME)
input bool   UseSessions        = true;
input int    LondonStart        = 8;
input int    LondonEnd          = 11;
input int    NYStart            = 14;
input int    NYEnd              = 18;

//================ GLOBALS =================//
double ask, bid;

// Indicator handles
int hD1FastEMA, hD1SlowEMA;
int hH4FastEMA, hH4SlowEMA;
int hATR;

//+------------------------------------------------------------------+
// OnInit
//+------------------------------------------------------------------+
int OnInit()
{
   hD1FastEMA = iMA(_Symbol, PERIOD_D1, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hD1SlowEMA = iMA(_Symbol, PERIOD_D1, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   hH4FastEMA = iMA(_Symbol, PERIOD_H4, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hH4SlowEMA = iMA(_Symbol, PERIOD_H4, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   hATR       = iATR(_Symbol, PERIOD_M15, ATR_Period);

   if(hD1FastEMA == INVALID_HANDLE || hATR == INVALID_HANDLE)
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
// OnDeinit
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(hD1FastEMA);
   IndicatorRelease(hD1SlowEMA);
   IndicatorRelease(hH4FastEMA);
   IndicatorRelease(hH4SlowEMA);
   IndicatorRelease(hATR);
}

//+------------------------------------------------------------------+
// Session Filter
//+------------------------------------------------------------------+
bool InSession()
{
   if(!UseSessions) return true;

   MqlDateTime t;
   TimeToStruct(TimeTradeServer(), t);

   if(t.hour >= LondonStart && t.hour < LondonEnd) return true;
   if(t.hour >= NYStart && t.hour < NYEnd) return true;

   return false;
}

//+------------------------------------------------------------------+
// Spread Filter
//+------------------------------------------------------------------+
bool SpreadOK()
{
   return ((ask - bid) / _Point <= MaxSpread);
}

//+------------------------------------------------------------------+
int CountTrades()
{
   return PositionsTotal();
}

//+------------------------------------------------------------------+
// Read EMA values
//+------------------------------------------------------------------+
bool GetEMAValues(int handleFast, int handleSlow, double &fast, double &slow)
{
   double f[1], s[1];
   if(CopyBuffer(handleFast, 0, 1, 1, f) <= 0) return false;
   if(CopyBuffer(handleSlow, 0, 1, 1, s) <= 0) return false;

   fast = f[0];
   slow = s[0];
   return true;
}

//+------------------------------------------------------------------+
// Get ATR
//+------------------------------------------------------------------+
double GetATR()
{
   double a[1];
   if(CopyBuffer(hATR, 0, 1, 1, a) <= 0) return 0;
   return a[0];
}

//+------------------------------------------------------------------+
// Dashboard
//+------------------------------------------------------------------+
void DrawPanel(bool d1Bull, bool h4Bull)
{
   string bias =
      d1Bull && h4Bull ? "D1+H4 BULLISH" :
      !d1Bull && !h4Bull ? "D1+H4 BEARISH" :
      "NO ALIGNMENT";

   Comment(
      "ATR SWING EA\n",
      "Symbol: ", _Symbol, "\n",
      "Trades: ", PositionsTotal(), "/", MaxTrades, "\n",
      "Bias: ", bias, "\n",
      "Session: ", InSession() ? "ACTIVE" : "OFF", "\n",
      "Spread: ", DoubleToString((ask - bid) / _Point, 0)
   );
}

//+------------------------------------------------------------------+
// OnTick
//+------------------------------------------------------------------+
void OnTick()
{
   ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(!SpreadOK()) return;
   if(!InSession()) return;
   if(CountTrades() >= MaxTrades) return;

   double d1Fast, d1Slow, h4Fast, h4Slow;
   if(!GetEMAValues(hD1FastEMA, hD1SlowEMA, d1Fast, d1Slow)) return;
   if(!GetEMAValues(hH4FastEMA, hH4SlowEMA, h4Fast, h4Slow)) return;

   bool d1Bull = d1Fast > d1Slow;
   bool d1Bear = d1Fast < d1Slow;
   bool h4Bull = h4Fast > h4Slow;
   bool h4Bear = h4Fast < h4Slow;

   DrawPanel(d1Bull, h4Bull);

   if(!(d1Bull && h4Bull) && !(d1Bear && h4Bear)) return;

   double atr = GetATR();
   if(atr <= 0) return;

   double sl = atr * SL_ATR_Multiplier;
   double tp = atr * TP_ATR_Multiplier;

   double prevHigh = iHigh(_Symbol, PERIOD_M15, 1);
   double prevLow  = iLow(_Symbol,  PERIOD_M15, 1);

   if(d1Bull && h4Bull && ask > prevHigh)
      trade.Buy(LotSize, _Symbol, ask, ask - sl, ask + tp, "Swing Buy");

   if(d1Bear && h4Bear && bid < prevLow)
      trade.Sell(LotSize, _Symbol, bid, bid + sl, bid - tp, "Swing Sell");
}
//+------------------------------------------------------------------+
