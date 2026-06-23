//+------------------------------------------------------------------+
//|                                                 SOC-EA-Scalp.mq5 |
//|                                                   Sons-Of-Christ |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Sons-Of-Christ"
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//|                                                UniversalScalp.mq5|
//|                        Multi-Timeframe EMA Scalping EA           |
//|                         Designed For Exness & All Instruments    |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"

//====================================================
// INPUTS
//====================================================

//--- Risk Settings
input double RiskPercent              = 1.0;
input bool   UseFixedLot              = false;
input double FixedLot                 = 0.01;

//--- EMA Settings
input int EMAFast                     = 20;
input int EMAMid                      = 50;
input int EMASlow                     = 200;

//--- ATR Settings
input int ATRPeriod                   = 14;
input double ATR_SL_Multiplier        = 1.5;
input double ATR_TP_Multiplier        = 2.0;
input double MinATR                   = 0.0005;

//--- Entry Settings
input bool UsePullbackEntries         = true;
input bool UseBreakoutEntries         = true;

input ENUM_TIMEFRAMES EntryTF1        = PERIOD_M1;
input ENUM_TIMEFRAMES EntryTF2        = PERIOD_M5;

input ENUM_TIMEFRAMES DirectionTF1    = PERIOD_M5;
input ENUM_TIMEFRAMES DirectionTF2    = PERIOD_M15;

//--- Trade Settings
input int MaxTradesPerSymbol          = 1;
input int CooldownMinutes             = 30;
input double MaxSpreadPoints          = 300;

//--- Sessions
input bool TradeLondon                = true;
input bool TradeNewYork               = true;
input bool TradeAsian                 = false;

//--- Dashboard
input bool EnableDashboard            = true;

//====================================================
// GLOBALS
//====================================================

datetime lastTradeTime = 0;

enum TREND
{
   TREND_BUY,
   TREND_SELL,
   TREND_NONE
};

//====================================================
// INITIALIZATION
//====================================================

int OnInit()
{
   Print("Universal Scalping EA Initialized");
   return(INIT_SUCCEEDED);
}

//====================================================
// MAIN LOOP
//====================================================

void OnTick()
{
   if(!TradingSessionAllowed())
      return;

   if(SpreadTooHigh())
      return;

   if(InCooldown())
      return;

   if(CountOpenPositions() >= MaxTradesPerSymbol)
      return;

   DrawDashboard();

   TREND direction = GetTrendBias();

   if(direction == TREND_NONE)
      return;

   double atr = GetATR(PERIOD_M5);

   if(atr < MinATR)
      return;

   if(direction == TREND_BUY)
   {
      if(CheckBuyEntry())
         OpenTrade(ORDER_TYPE_BUY, atr);
   }

   if(direction == TREND_SELL)
   {
      if(CheckSellEntry())
         OpenTrade(ORDER_TYPE_SELL, atr);
   }
}

//====================================================
// TREND LOGIC
//====================================================

TREND GetTrendBias()
{
   bool buy1 = EMAAlignment(DirectionTF1, true);
   bool buy2 = EMAAlignment(DirectionTF2, true);

   bool sell1 = EMAAlignment(DirectionTF1, false);
   bool sell2 = EMAAlignment(DirectionTF2, false);

   if(buy1 && buy2)
      return TREND_BUY;

   if(sell1 && sell2)
      return TREND_SELL;

   return TREND_NONE;
}

//====================================================
// EMA ALIGNMENT
//====================================================

bool EMAAlignment(ENUM_TIMEFRAMES tf, bool buy)
{
   double ema20 = iMA(Symbol(), tf, EMAFast, 0, MODE_EMA, PRICE_CLOSE);
   double ema50 = iMA(Symbol(), tf, EMAMid, 0, MODE_EMA, PRICE_CLOSE);
   double ema200 = iMA(Symbol(), tf, EMASlow, 0, MODE_EMA, PRICE_CLOSE);

   if(buy)
   {
      if(ema20 > ema50 && ema20 > ema200 && ema50 > ema200)
         return true;
   }
   else
   {
      if(ema20 < ema50 && ema20 < ema200 && ema50 < ema200)
         return true;
   }

   return false;
}

//====================================================
// BUY ENTRY
//====================================================

bool CheckBuyEntry()
{
   bool pullback = false;
   bool breakout = false;

   //--- Pullback
   if(UsePullbackEntries)
   {
      double ema20 = iMA(Symbol(), EntryTF1, EMAFast, 0, MODE_EMA, PRICE_CLOSE);
      double close1 = iClose(Symbol(), EntryTF1, 1);

      if(close1 <= ema20)
      {
         double bullish = iClose(Symbol(), EntryTF1, 0);
         double open0 = iOpen(Symbol(), EntryTF1, 0);

         if(bullish > open0)
            pullback = true;
      }
   }

   //--- Breakout
   if(UseBreakoutEntries)
   {
      double high1 = iHigh(Symbol(), EntryTF1, 1);
      double currentAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

      if(currentAsk > high1)
         breakout = true;
   }

   return (pullback || breakout);
}

//====================================================
// SELL ENTRY
//====================================================

bool CheckSellEntry()
{
   bool pullback = false;
   bool breakout = false;

   //--- Pullback
   if(UsePullbackEntries)
   {
      double ema20 = iMA(Symbol(), EntryTF1, EMAFast, 0, MODE_EMA, PRICE_CLOSE);
      double close1 = iClose(Symbol(), EntryTF1, 1);

      if(close1 >= ema20)
      {
         double close0 = iClose(Symbol(), EntryTF1, 0);
         double open0 = iOpen(Symbol(), EntryTF1, 0);

         if(close0 < open0)
            pullback = true;
      }
   }

   //--- Breakout
   if(UseBreakoutEntries)
   {
      double low1 = iLow(Symbol(), EntryTF1, 1);
      double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);

      if(bid < low1)
         breakout = true;
   }

   return (pullback || breakout);
}

//====================================================
// OPEN TRADE
//====================================================

void OpenTrade(ENUM_ORDER_TYPE type, double atr)
{
   MqlTradeRequest request;
   MqlTradeResult result;

   ZeroMemory(request);
   ZeroMemory(result);

   double lot = CalculateLotSize(atr);

   double price = 0;
   double sl = 0;
   double tp = 0;

   if(type == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

      sl = price - (atr * ATR_SL_Multiplier);
      tp = price + (atr * ATR_TP_Multiplier);
   }
   else
   {
      price = SymbolInfoDouble(Symbol(), SYMBOL_BID);

      sl = price + (atr * ATR_SL_Multiplier);
      tp = price - (atr * ATR_TP_Multiplier);
   }

   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol();
   request.volume = lot;
   request.type = type;
   request.price = NormalizeDouble(price, _Digits);
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   request.deviation = 20;
   request.magic = 777777;
   request.type_filling = ORDER_FILLING_FOK;

   if(OrderSend(request, result))
   {
      Print("Trade Opened");
      lastTradeTime = TimeCurrent();
   }
   else
   {
      Print("Trade Failed: ", result.comment);
   }
}

//====================================================
// ATR
//====================================================

double GetATR(ENUM_TIMEFRAMES tf)
{
   return iATR(Symbol(), tf, ATRPeriod);
}

//====================================================
// LOT SIZE
//====================================================

double CalculateLotSize(double atr)
{
   if(UseFixedLot)
      return FixedLot;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   double riskMoney = balance * (RiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);

   double stopDistance = atr * ATR_SL_Multiplier;

   if(stopDistance <= 0)
      return 0.01;

   double lots = riskMoney / (stopDistance / _Point * tickValue);

   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = NormalizeDouble(lots, 2);

   return lots;
}

//====================================================
// SPREAD FILTER
//====================================================

bool SpreadTooHigh()
{
   double spread =
      (SymbolInfoDouble(Symbol(), SYMBOL_ASK)
      - SymbolInfoDouble(Symbol(), SYMBOL_BID)) / _Point;

   return spread > MaxSpreadPoints;
}

//====================================================
// COOLDOWN
//====================================================

bool InCooldown()
{
   if((TimeCurrent() - lastTradeTime) < (CooldownMinutes * 60))
      return true;

   return false;
}

//====================================================
// COUNT POSITIONS
//====================================================

int CountOpenPositions()
{
   int total = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == Symbol())
         total++;
   }

   return total;
}

//====================================================
// TRADING SESSION FILTER
//====================================================

bool TradingSessionAllowed()
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   int hour = tm.hour;

   // Asian
   if(TradeAsian)
   {
      if(hour >= 2 && hour < 4)
         return true;
   }

   // London
   if(TradeLondon)
   {
      if(hour >= 9 && hour < 12)
         return true;
   }

   // New York
   if(TradeNewYork)
   {
      if(hour >= 14 && hour < 18)
         return true;
   }

   return false;
}

//====================================================
// DASHBOARD
//====================================================

void DrawDashboard()
{
   if(!EnableDashboard)
      return;

   string trend = "NONE";

   TREND t = GetTrendBias();

   if(t == TREND_BUY)
      trend = "BUY";

   if(t == TREND_SELL)
      trend = "SELL";

   double atr = GetATR(PERIOD_M5);

   double spread =
      (SymbolInfoDouble(Symbol(), SYMBOL_ASK)
      - SymbolInfoDouble(Symbol(), SYMBOL_BID)) / _Point;

   string text =
      "UNIVERSAL SCALP EA\n"
      + "====================\n"
      + "Symbol: " + Symbol() + "\n"
      + "Trend: " + trend + "\n"
      + "Spread: " + DoubleToString(spread,1) + "\n"
      + "ATR: " + DoubleToString(atr,_Digits) + "\n"
      + "Open Trades: " + IntegerToString(CountOpenPositions()) + "\n"
      + "Cooldown: " + (InCooldown() ? "YES" : "NO") + "\n";

   Comment(text);
}
//+------------------------------------------------------------------+