//+------------------------------------------------------------------+
//|                                                 Scalp-ATR-EA.mq5 |
//|                                                   Sons-Of-Christ |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Sons-Of-Christ"
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//| Scalp-EA-2.mq5 (UNIVERSAL ADAPTIVE VERSION)                      |
//| Works on Forex, Gold, Indices, Crypto & Commodities              |
//+------------------------------------------------------------------+
#property version   "2.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//================ INPUTS =================//

input double LotSize               = 0.02;
input int    MaxTrades             = 2;

// SESSION CONTROL
input bool   UseSessionFilter      = true;

// COOL DOWN
input int    CooldownMinutes       = 30;

// EMA BIAS
input int    FastEMA               = 50;
input int    SlowEMA               = 200;

// ATR SETTINGS
input int    ATR_Period            = 14;

// UNIVERSAL ATR MULTIPLIERS
input double SL_ATR_Multiplier     = 1.5;
input double TP_ATR_Multiplier     = 3.0;

input double Pullback_ATR_Mult     = 0.30;
input double Breakout_ATR_Mult     = 0.10;

input double TrailStart_ATR_Mult   = 1.0;
input double TrailStep_ATR_Mult    = 0.50;

// VOLATILITY FILTER
input double MinATR_Points         = 100;

// SPREAD FILTER
input double MaxSpread_ATR_Percent = 20.0;

//================ GLOBALS =================//

double ask, bid;

datetime CooldownStartTime = 0;
datetime LastTradeCandle   = 0;

bool BuyBreakout  = false;
bool SellBreakout = false;

double BreakoutHigh = 0;
double BreakoutLow  = 0;

//+------------------------------------------------------------------+
// NORMALIZE PRICE
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   return NormalizeDouble(price, _Digits);
}

//+------------------------------------------------------------------+
// ATR
//+------------------------------------------------------------------+
double GetATR()
{
   return iATR(_Symbol, PERIOD_M1, ATR_Period);
}

//+------------------------------------------------------------------+
// EMA
//+------------------------------------------------------------------+
double EMA(int period, ENUM_TIMEFRAMES tf)
{
   return iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
}

//+------------------------------------------------------------------+
// COUNT SYMBOL TRADES
//+------------------------------------------------------------------+
int CountSymbolTrades()
{
   int count = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         count++;
   }

   return count;
}

//+------------------------------------------------------------------+
// COOLDOWN
//+------------------------------------------------------------------+
bool CooldownActive()
{
   if(CooldownStartTime == 0)
      return false;

   if((TimeCurrent() - CooldownStartTime) >= CooldownMinutes * 60)
   {
      CooldownStartTime = 0;
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
// HIGHER TIMEFRAME BIAS
//+------------------------------------------------------------------+
bool HTFBullish()
{
   return EMA(FastEMA, PERIOD_H1) > EMA(SlowEMA, PERIOD_H1) &&
          EMA(FastEMA, PERIOD_M15) > EMA(SlowEMA, PERIOD_M15);
}

bool HTFBearish()
{
   return EMA(FastEMA, PERIOD_H1) < EMA(SlowEMA, PERIOD_H1) &&
          EMA(FastEMA, PERIOD_M15) < EMA(SlowEMA, PERIOD_M15);
}

string BiasText()
{
   if(HTFBullish()) return "BULLISH";
   if(HTFBearish()) return "BEARISH";

   return "NEUTRAL";
}

//+------------------------------------------------------------------+
// VOLATILITY FILTER
//+------------------------------------------------------------------+
bool VolatilityOK()
{
   return (GetATR() / _Point) >= MinATR_Points;
}

//+------------------------------------------------------------------+
// DYNAMIC SPREAD FILTER
//+------------------------------------------------------------------+
bool SpreadOK()
{
   double spread = (ask - bid) / _Point;
   double atr    = GetATR() / _Point;

   if(atr <= 0)
      return false;

   double spreadPercent = (spread / atr) * 100.0;

   return spreadPercent <= MaxSpread_ATR_Percent;
}

//+------------------------------------------------------------------+
// SESSION FILTER
//+------------------------------------------------------------------+
bool TradingSession()
{
   if(!UseSessionFilter)
      return true;

   MqlDateTime t;
   TimeToStruct(TimeLocal(), t);

   int h = t.hour;

   if(h >= 2 && h < 4) return true;     // Asian
   if(h >= 9 && h < 10) return true;    // London
   if(h >= 14 && h < 17) return true;   // NY Morning
   if(h >= 20 && h < 22) return true;   // NY Afternoon

   return false;
}

//+------------------------------------------------------------------+
// ACTIVE SESSION
//+------------------------------------------------------------------+
string ActiveSession()
{
   if(!UseSessionFilter)
      return "ANYTIME MODE";

   MqlDateTime t;
   TimeToStruct(TimeLocal(), t);

   int h = t.hour;

   if(h >= 2 && h < 4) return "ASIAN";
   if(h >= 9 && h < 10) return "LONDON";
   if(h >= 14 && h < 17) return "NY MORNING";
   if(h >= 20 && h < 22) return "NY AFTERNOON";

   return "OFF";
}

//+------------------------------------------------------------------+
// HEDGE BLOCK
//+------------------------------------------------------------------+
bool HedgeBlocked(long type)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_TYPE) != type)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
// ATR TRAILING STOPS
//+------------------------------------------------------------------+
void TrailStops()
{
   double atr = GetATR();

   double trailStart = atr * TrailStart_ATR_Mult;
   double trailStep  = atr * TrailStep_ATR_Mult;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);

      // BUY
      if(type == POSITION_TYPE_BUY)
      {
         double profit = bid - open;

         if(profit >= trailStart)
         {
            double newSL = bid - trailStep;

            if(newSL > sl)
               trade.PositionModify(ticket,
                                    NormalizePrice(newSL),
                                    NormalizePrice(tp));
         }
      }

      // SELL
      if(type == POSITION_TYPE_SELL)
      {
         double profit = open - ask;

         if(profit >= trailStart)
         {
            double newSL = ask + trailStep;

            if(sl == 0 || newSL < sl)
               trade.PositionModify(ticket,
                                    NormalizePrice(newSL),
                                    NormalizePrice(tp));
         }
      }
   }
}

//+------------------------------------------------------------------+
// PROFESSIONAL DASHBOARD
//+------------------------------------------------------------------+
void DrawDashboard()
{
   double spread = (ask - bid) / _Point;
   double atr    = GetATR() / _Point;

   string cooldown =
      CooldownActive() ? "ACTIVE" : "OFF";

   string session =
      TradingSession() ? "OPEN" : "CLOSED";

   string volatility =
      VolatilityOK() ? "GOOD" : "LOW";

   string panel =
   "====================================\n"
   "   SOC UNIVERSAL ADAPTIVE EA v2.00\n"
   "====================================\n"
   "SYMBOL:        " + _Symbol + "\n"
   "SESSION:       " + ActiveSession() + "\n"
   "MARKET:        " + session + "\n"
   "BIAS:          " + BiasText() + "\n"
   "------------------------------------\n"
   "SPREAD:        " + DoubleToString(spread,1) + "\n"
   "ATR:           " + DoubleToString(atr,1) + "\n"
   "VOLATILITY:    " + volatility + "\n"
   "COOLDOWN:      " + cooldown + "\n"
   "------------------------------------\n"
   "BUY STATE:     " +
      (BuyBreakout ? "WAIT PULLBACK" : "IDLE") + "\n"
   "SELL STATE:    " +
      (SellBreakout ? "WAIT PULLBACK" : "IDLE") + "\n"
   "------------------------------------\n"
   "TRADES:        " +
      IntegerToString(CountSymbolTrades()) +
      " / " +
      IntegerToString(MaxTrades) + "\n"
   "====================================";

   Comment(panel);
}

//+------------------------------------------------------------------+
// MAIN
//+------------------------------------------------------------------+
void OnTick()
{
   ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   DrawDashboard();
   TrailStops();

   // FILTERS
   if(!TradingSession()) return;
   if(!SpreadOK()) return;
   if(!VolatilityOK()) return;

   int trades = CountSymbolTrades();

   // COOLDOWN
   if(trades >= MaxTrades)
   {
      if(CooldownStartTime == 0)
         CooldownStartTime = TimeCurrent();

      return;
   }

   if(CooldownActive())
      return;

   // ONE TRADE PER CANDLE
   datetime candle = iTime(_Symbol, PERIOD_M1, 0);

   if(candle == LastTradeCandle)
      return;

   // ATR VALUES
   double atr = GetATR();

   double breakoutBuffer = atr * Breakout_ATR_Mult;
   double pullbackSize   = atr * Pullback_ATR_Mult;

   double slDistance = atr * SL_ATR_Multiplier;
   double tpDistance = atr * TP_ATR_Multiplier;

   // PREVIOUS CANDLE
   double prevHigh = iHigh(_Symbol, PERIOD_M1, 1);
   double prevLow  = iLow (_Symbol, PERIOD_M1, 1);

   //================ BREAKOUT DETECTION =================//

   if(HTFBullish() &&
      ask > prevHigh + breakoutBuffer)
   {
      BuyBreakout = true;
      BreakoutHigh = ask;
   }

   if(HTFBearish() &&
      bid < prevLow - breakoutBuffer)
   {
      SellBreakout = true;
      BreakoutLow = bid;
   }

   //================ BUY PULLBACK ENTRY =================//

   if(BuyBreakout &&
      bid <= BreakoutHigh - pullbackSize &&
      HTFBullish() &&
      !HedgeBlocked(POSITION_TYPE_BUY))
   {
      double sl = NormalizePrice(ask - slDistance);
      double tp = NormalizePrice(ask + tpDistance);

      trade.Buy(
         LotSize,
         _Symbol,
         ask,
         sl,
         tp,
         "SOC BUY"
      );

      BuyBreakout = false;
      LastTradeCandle = candle;
   }

   //================ SELL PULLBACK ENTRY =================//

   if(SellBreakout &&
      ask >= BreakoutLow + pullbackSize &&
      HTFBearish() &&
      !HedgeBlocked(POSITION_TYPE_SELL))
   {
      double sl = NormalizePrice(bid + slDistance);
      double tp = NormalizePrice(bid - tpDistance);

      trade.Sell(
         LotSize,
         _Symbol,
         bid,
         sl,
         tp,
         "SOC SELL"
      );

      SellBreakout = false;
      LastTradeCandle = candle;
   }
}
//+------------------------------------------------------------------+
