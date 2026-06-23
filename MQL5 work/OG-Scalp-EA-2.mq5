//+------------------------------------------------------------------+
//|                                                   Scalp-EA-2.mq5 |
//|                     FIXED: PER-SYMBOL TRADE CONTROL              |
//+------------------------------------------------------------------+
#property copyright "Sons-Of-Christ"
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//| Scalp-EA-2.mq5 (Cooldown after Max Trades FIXED)                |
//+------------------------------------------------------------------+
#property version   "1.40"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//================ INPUTS =================//
input double LotSize          = 0.02;
input int    MaxTrades        = 2;

input int    StopLossPoints   = 500;
input int    TakeProfitPoints = 1000;

input int    TrailStart       = 500;
input int    TrailStep        = 300;

input int    MaxSpread        = 1500;

input int    CooldownMinutes  = 30;

//================ GLOBALS =================//
double ask, bid;
datetime CooldownStartTime = 0;

//+------------------------------------------------------------------+
// COUNT TRADES PER SYMBOL
//+------------------------------------------------------------------+
int CountSymbolTrades()
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         count++;
   }

   return count;
}

//+------------------------------------------------------------------+
// COOLDOWN AFTER MAX TRADES
//+------------------------------------------------------------------+
bool CooldownActive()
{
   if(CooldownStartTime == 0)
      return false;

   int secondsPassed = (int)(TimeCurrent() - CooldownStartTime);

   if(secondsPassed >= CooldownMinutes * 60)
   {
      CooldownStartTime = 0; // reset
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
// HTF Bias
//+------------------------------------------------------------------+
bool HTFBullish()
{
   return iClose(_Symbol, PERIOD_H1, 1) > iOpen(_Symbol, PERIOD_H1, 1);
}

bool HTFBearish()
{
   return iClose(_Symbol, PERIOD_H1, 1) < iOpen(_Symbol, PERIOD_H1, 1);
}

string BiasText()
{
   if(HTFBullish()) return "BULLISH";
   if(HTFBearish()) return "BEARISH";
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
// SESSION (GMT+2 + ASIAN)
//+------------------------------------------------------------------+
bool TradingSession()
{
   MqlDateTime t;
   TimeToStruct(TimeLocal(), t);

   int h = t.hour;

   if(h >= 2 && h < 4) return true;     // Asian
   if(h >= 9 && h < 10) return true;    // London
   if(h >= 14 && h < 17) return true;   // NY Morning
   if(h >= 20 && h < 22) return true;   // NY Afternoon

   return false;
}

string ActiveSession()
{
   MqlDateTime t;
   TimeToStruct(TimeLocal(), t);

   int h = t.hour;

   if(h >= 2 && h < 4) return "Asian";
   if(h >= 9 && h < 10) return "London";
   if(h >= 14 && h < 17) return "NY Morning";
   if(h >= 20 && h < 22) return "NY Afternoon";

   return "OFF";
}

//+------------------------------------------------------------------+
// Spread Filter
//+------------------------------------------------------------------+
bool SpreadOK()
{
   return ((ask - bid) / _Point <= MaxSpread);
}

//+------------------------------------------------------------------+
// Hedge Block
//+------------------------------------------------------------------+
bool HedgeBlocked(long newType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_TYPE) != newType)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// Trailing Stops
//+------------------------------------------------------------------+
void TrailStops()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long   type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);

      if(type == POSITION_TYPE_BUY)
      {
         double profit = (bid - open) / _Point;
         if(profit >= TrailStart)
         {
            double newSL = bid - TrailStep * _Point;
            if(newSL > sl)
               trade.PositionModify(_Symbol, newSL, tp);
         }
      }

      if(type == POSITION_TYPE_SELL)
      {
         double profit = (open - ask) / _Point;
         if(profit >= TrailStart)
         {
            double newSL = ask + TrailStep * _Point;
            if(sl == 0 || newSL < sl)
               trade.PositionModify(_Symbol, newSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
// Dashboard (UNCHANGED)
//+------------------------------------------------------------------+
void DrawDashboard()
{
   string panel =
      "SOC SCALP EA\n"
      "-----------------\n"
      "Symbol: " + _Symbol + "\n"
      "Session: " + ActiveSession() + "\n"
      "HTF Bias: " + BiasText() + "\n"
      "Spread: " + DoubleToString((ask - bid) / _Point, 1) + "\n"
      "Symbol Trades: " + IntegerToString(CountSymbolTrades()) +
      " / " + IntegerToString(MaxTrades);

   Comment(panel);
}

//+------------------------------------------------------------------+
// OnTick
//+------------------------------------------------------------------+
void OnTick()
{
   ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   DrawDashboard();
   TrailStops();

   if(!TradingSession()) return;
   if(!SpreadOK()) return;

   int trades = CountSymbolTrades();

   // ✅ START COOLDOWN WHEN MAX TRADES HIT
   if(trades >= MaxTrades)
   {
      if(CooldownStartTime == 0)
         CooldownStartTime = TimeCurrent();

      return;
   }

   // ✅ BLOCK DURING COOLDOWN
   if(CooldownActive()) return;

   double prevHigh = iHigh(_Symbol, PERIOD_M1, 1);
   double prevLow  = iLow (_Symbol, PERIOD_M1, 1);

   // BUY
   if(HTFBullish() && ask > prevHigh && !HedgeBlocked(POSITION_TYPE_BUY))
   {
      trade.Buy(LotSize, _Symbol, ask,
                ask - StopLossPoints * _Point,
                ask + TakeProfitPoints * _Point,
                "SOC Buy");
   }

   // SELL
   if(HTFBearish() && bid < prevLow && !HedgeBlocked(POSITION_TYPE_SELL))
   {
      trade.Sell(LotSize, _Symbol, bid,
                 bid + StopLossPoints * _Point,
                 bid - TakeProfitPoints * _Point,
                 "SOC Sell");
   }
}
//+------------------------------------------------------------------+