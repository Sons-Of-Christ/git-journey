//+------------------------------------------------------------------+
//|                                              Claude-Scalp-EA.mq5 |
//|                                                   Sons-Of-Christ |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Sons-Of-Christ"
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//| SOC_Scalp_EA_v2.1.mq5                                            |
//| Universal Adaptive EA — Gold-Optimised Build                     |
//| Improvements: SAST sessions, RSI confirmation, breakout expiry,  |
//| candle body filter, tick-safe ATR/EMA, equity guard              |
//+------------------------------------------------------------------+
#property version   "2.10"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//=================================================================//
//  INPUT GROUPS
//=================================================================//

// --- Position Sizing ---
input double LotSize               = 0.02;   // Lot size
input int    MaxTrades             = 2;       // Max concurrent trades

// --- Session Filter (SAST = UTC+2) ---
input bool   UseSessionFilter      = true;
input bool   TradeAsian            = false;   // 04:00–06:00 SAST (thin, skip for Gold)
input bool   TradeLondon           = true;    // 10:00–12:00 SAST
input bool   TradeNYMorning        = true;    // 15:30–18:00 SAST (best for Gold)
input bool   TradeNYAfternoon      = false;   // 20:30–22:30 SAST (optional)

// --- Cooldown ---
input int    CooldownMinutes       = 30;

// --- HTF Bias (EMA) ---
input int    FastEMA               = 50;
input int    SlowEMA               = 200;

// --- ATR ---
input int    ATR_Period            = 14;
input double SL_ATR_Multiplier     = 1.5;
input double TP_ATR_Multiplier     = 3.0;
input double Pullback_ATR_Mult     = 0.30;
input double Breakout_ATR_Mult     = 0.10;
input double TrailStart_ATR_Mult   = 1.0;
input double TrailStep_ATR_Mult    = 0.50;

// --- Volatility & Spread ---
input double MinATR_Points         = 100;     // Min ATR in points
input double MaxSpread_ATR_Percent = 20.0;    // Max spread as % of ATR

// --- RSI Confirmation (new) ---
input bool   UseRSIFilter          = true;
input int    RSI_Period            = 14;
input double RSI_BuyMin            = 50.0;    // RSI must be above this for buys
input double RSI_SellMax           = 50.0;    // RSI must be below this for sells
input double RSI_OverboughtBlock   = 75.0;    // Block buys above this level
input double RSI_OversoldBlock     = 25.0;    // Block sells below this level

// --- Candle Body Filter (new) ---
input bool   UseCandleBodyFilter   = true;
input double MinBodyRatio          = 0.40;    // Body must be >= 40% of candle range

// --- Breakout State Expiry (new) ---
input int    BreakoutExpiryBars    = 10;      // Cancel stale breakout after N M1 bars

// --- Equity / Drawdown Guard (new) ---
input bool   UseEquityGuard        = true;
input double MaxDailyDrawdownPct   = 3.0;     // Halt trading if daily DD exceeds this %

//=================================================================//
//  GLOBALS
//=================================================================//

double ask, bid;

datetime CooldownStartTime  = 0;
datetime LastTradeCandle    = 0;

bool     BuyBreakout        = false;
bool     SellBreakout       = false;
double   BreakoutHigh       = 0;
double   BreakoutLow        = 0;
datetime BreakoutBuyTime    = 0;   // When the buy breakout was detected
datetime BreakoutSellTime   = 0;   // When the sell breakout was detected

double   DayStartEquity     = 0;
datetime LastDayCheck       = 0;

// Indicator handles (cached on init — avoids recreating every tick)
int      hATR    = INVALID_HANDLE;
int      hFastH1 = INVALID_HANDLE;
int      hSlowH1 = INVALID_HANDLE;
int      hFastM15= INVALID_HANDLE;
int      hSlowM15= INVALID_HANDLE;
int      hRSI    = INVALID_HANDLE;

//=================================================================//
//  INIT / DEINIT
//=================================================================//

int OnInit()
{
   hATR     = iATR (_Symbol, PERIOD_M1,  ATR_Period);
   hFastH1  = iMA  (_Symbol, PERIOD_H1,  FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlowH1  = iMA  (_Symbol, PERIOD_H1,  SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hFastM15 = iMA  (_Symbol, PERIOD_M15, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlowM15 = iMA  (_Symbol, PERIOD_M15, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI     = iRSI (_Symbol, PERIOD_M15, RSI_Period, PRICE_CLOSE);

   if(hATR    == INVALID_HANDLE ||
      hFastH1 == INVALID_HANDLE ||
      hSlowH1 == INVALID_HANDLE ||
      hFastM15== INVALID_HANDLE ||
      hSlowM15== INVALID_HANDLE ||
      hRSI    == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles. EA will not run.");
      return INIT_FAILED;
   }

   DayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   Print("SOC Scalp EA v2.10 initialised on ", _Symbol);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hATR);
   IndicatorRelease(hFastH1);
   IndicatorRelease(hSlowH1);
   IndicatorRelease(hFastM15);
   IndicatorRelease(hSlowM15);
   IndicatorRelease(hRSI);
   Comment("");
}

//=================================================================//
//  SAFE INDICATOR READS  (returns 0 on failure — never crashes)
//=================================================================//

double ReadBuffer(int handle, int shift = 0)
{
   double buf[1];
   if(CopyBuffer(handle, 0, shift, 1, buf) <= 0)
      return 0;
   return buf[0];
}

double GetATR()    { return ReadBuffer(hATR); }
double GetRSI()    { return ReadBuffer(hRSI); }

double GetFastH1() { return ReadBuffer(hFastH1); }
double GetSlowH1() { return ReadBuffer(hSlowH1); }
double GetFastM15(){ return ReadBuffer(hFastM15);}
double GetSlowM15(){ return ReadBuffer(hSlowM15);}

//=================================================================//
//  PRICE HELPERS
//=================================================================//

double NormalizePrice(double price)
{
   return NormalizeDouble(price, _Digits);
}

//=================================================================//
//  HTF BIAS
//=================================================================//

bool HTFBullish()
{
   return GetFastH1() > GetSlowH1() &&
          GetFastM15() > GetSlowM15();
}

bool HTFBearish()
{
   return GetFastH1() < GetSlowH1() &&
          GetFastM15() < GetSlowM15();
}

string BiasText()
{
   if(HTFBullish()) return "BULLISH";
   if(HTFBearish()) return "BEARISH";
   return "NEUTRAL";
}

//=================================================================//
//  RSI CONFIRMATION (new)
//=================================================================//

bool RSIConfirmsBuy()
{
   if(!UseRSIFilter) return true;
   double rsi = GetRSI();
   return (rsi >= RSI_BuyMin && rsi < RSI_OverboughtBlock);
}

bool RSIConfirmsSell()
{
   if(!UseRSIFilter) return true;
   double rsi = GetRSI();
   return (rsi <= RSI_SellMax && rsi > RSI_OversoldBlock);
}

//=================================================================//
//  CANDLE BODY FILTER (new)
//  Ensures breakout candle has conviction — not a wick spike
//=================================================================//

bool CandleBodyOK(int shift = 1)
{
   if(!UseCandleBodyFilter) return true;

   double h = iHigh (_Symbol, PERIOD_M1, shift);
   double l = iLow  (_Symbol, PERIOD_M1, shift);
   double o = iOpen (_Symbol, PERIOD_M1, shift);
   double c = iClose(_Symbol, PERIOD_M1, shift);

   double range = h - l;
   if(range <= 0) return false;

   double body  = MathAbs(c - o);
   return (body / range) >= MinBodyRatio;
}

//=================================================================//
//  BREAKOUT EXPIRY CHECK (new)
//=================================================================//

bool BreakoutExpired(datetime breakoutTime)
{
   if(breakoutTime == 0) return false;
   datetime barTime = iTime(_Symbol, PERIOD_M1, 0);
   int barsDiff = (int)((barTime - breakoutTime) / PeriodSeconds(PERIOD_M1));
   return barsDiff >= BreakoutExpiryBars;
}

//=================================================================//
//  VOLATILITY FILTER
//=================================================================//

bool VolatilityOK()
{
   return (GetATR() / _Point) >= MinATR_Points;
}

//=================================================================//
//  DYNAMIC SPREAD FILTER
//=================================================================//

bool SpreadOK()
{
   double spread = (ask - bid) / _Point;
   double atr    = GetATR() / _Point;
   if(atr <= 0) return false;
   return ((spread / atr) * 100.0) <= MaxSpread_ATR_Percent;
}

//=================================================================//
//  SESSION FILTER — SAST (UTC+2) AWARE (improved)
//=================================================================//

bool TradingSession()
{
   if(!UseSessionFilter) return true;

   MqlDateTime t;
   TimeToStruct(TimeLocal(), t);
   int h = t.hour;
   int m = t.min;

   // Asian:        04:00–06:00 SAST
   if(TradeAsian && h >= 4 && h < 6) return true;

   // London Open:  10:00–12:00 SAST
   if(TradeLondon && h >= 10 && h < 12) return true;

   // NY Morning:   15:30–18:00 SAST  (prime Gold session)
   if(TradeNYMorning &&
      ((h == 15 && m >= 30) || (h == 16) || (h == 17))) return true;

   // NY Afternoon: 20:30–22:30 SAST
   if(TradeNYAfternoon &&
      ((h == 20 && m >= 30) || (h == 21) || (h == 22 && m == 0))) return true;

   return false;
}

string ActiveSession()
{
   if(!UseSessionFilter) return "ANYTIME";

   MqlDateTime t;
   TimeToStruct(TimeLocal(), t);
   int h = t.hour;
   int m = t.min;

   if(TradeAsian    && h >= 4 && h < 6) return "ASIAN";
   if(TradeLondon   && h >= 10 && h < 12) return "LONDON";
   if(TradeNYMorning &&
      ((h == 15 && m >= 30) || h == 16 || h == 17)) return "NY MORNING";
   if(TradeNYAfternoon &&
      ((h == 20 && m >= 30) || h == 21 ||
       (h == 22 && m == 0))) return "NY AFTERNOON";

   return "OFF";
}

//=================================================================//
//  EQUITY / DAILY DRAWDOWN GUARD (new)
//=================================================================//

bool EquityGuardTripped()
{
   if(!UseEquityGuard) return false;

   // Reset at start of new trading day
   MqlDateTime now, last;
   TimeToStruct(TimeCurrent(), now);
   TimeToStruct(LastDayCheck,  last);

   if(now.day != last.day)
   {
      DayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      LastDayCheck   = TimeCurrent();
   }

   if(DayStartEquity <= 0) return false;

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct = ((DayStartEquity - currentEquity) / DayStartEquity) * 100.0;

   return ddPct >= MaxDailyDrawdownPct;
}

//=================================================================//
//  POSITION HELPERS
//=================================================================//

int CountSymbolTrades()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol) count++;
   }
   return count;
}

bool HedgeBlocked(long type)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_TYPE) != type) return true;
   }
   return false;
}

//=================================================================//
//  COOLDOWN
//=================================================================//

bool CooldownActive()
{
   if(CooldownStartTime == 0) return false;
   if((TimeCurrent() - CooldownStartTime) >= CooldownMinutes * 60)
   {
      CooldownStartTime = 0;
      return false;
   }
   return true;
}

//=================================================================//
//  ATR TRAILING STOPS
//=================================================================//

void TrailStops()
{
   double atr        = GetATR();
   double trailStart = atr * TrailStart_ATR_Mult;
   double trailStep  = atr * TrailStep_ATR_Mult;

   for(int i = PositionsTotal()-1; i >= 0; i--)
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
      else if(type == POSITION_TYPE_SELL)
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

//=================================================================//
//  DASHBOARD
//=================================================================//

void DrawDashboard()
{
   double spread = (ask - bid) / _Point;
   double atr    = GetATR() / _Point;
   double rsi    = GetRSI();

   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct     = 0;
   if(DayStartEquity > 0)
      ddPct = ((DayStartEquity - equity) / DayStartEquity) * 100.0;

   string equityGuard = EquityGuardTripped() ? "*** HALTED ***" : "OK";

   // Breakout expiry countdowns
   string buyExpiry  = "";
   string sellExpiry = "";
   if(BuyBreakout  && BreakoutBuyTime  > 0)
   {
      int barsLeft = BreakoutExpiryBars -
         (int)((iTime(_Symbol,PERIOD_M1,0) - BreakoutBuyTime) /
               PeriodSeconds(PERIOD_M1));
      buyExpiry  = " [" + IntegerToString(MathMax(barsLeft,0)) + " bars]";
   }
   if(SellBreakout && BreakoutSellTime > 0)
   {
      int barsLeft = BreakoutExpiryBars -
         (int)((iTime(_Symbol,PERIOD_M1,0) - BreakoutSellTime) /
               PeriodSeconds(PERIOD_M1));
      sellExpiry = " [" + IntegerToString(MathMax(barsLeft,0)) + " bars]";
   }

   string panel =
   "====================================\n"
   "  SOC SCALP EA v2.10 — GOLD BUILD\n"
   "====================================\n"
   "SYMBOL:        " + _Symbol              + "\n"
   "SESSION:       " + ActiveSession()       + "\n"
   "MARKET:        " + (TradingSession() ? "OPEN" : "CLOSED") + "\n"
   "BIAS:          " + BiasText()            + "\n"
   "RSI (M15):     " + DoubleToString(rsi,1) + "\n"
   "------------------------------------\n"
   "SPREAD:        " + DoubleToString(spread,1)  + " pts\n"
   "ATR:           " + DoubleToString(atr,1)     + " pts\n"
   "VOLATILITY:    " + (VolatilityOK() ? "OK" : "LOW") + "\n"
   "SPREAD FILTER: " + (SpreadOK()     ? "OK" : "WIDE") + "\n"
   "COOLDOWN:      " + (CooldownActive() ? "ACTIVE" : "OFF") + "\n"
   "------------------------------------\n"
   "BUY STATE:     " + (BuyBreakout  ? "WAIT PULLBACK"+buyExpiry  : "IDLE") + "\n"
   "SELL STATE:    " + (SellBreakout ? "WAIT PULLBACK"+sellExpiry : "IDLE") + "\n"
   "------------------------------------\n"
   "TRADES:        " + IntegerToString(CountSymbolTrades()) +
                " / " + IntegerToString(MaxTrades)          + "\n"
   "DAILY DD:      " + DoubleToString(ddPct,2) + "%  " + equityGuard + "\n"
   "====================================";

   Comment(panel);
}

//=================================================================//
//  MAIN TICK
//=================================================================//

void OnTick()
{
   ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   DrawDashboard();
   TrailStops();

   //--- Core filters ---
   if(!TradingSession())  return;
   if(!SpreadOK())        return;
   if(!VolatilityOK())    return;
   if(EquityGuardTripped()) return;

   int trades = CountSymbolTrades();

   if(trades >= MaxTrades)
   {
      if(CooldownStartTime == 0)
         CooldownStartTime = TimeCurrent();
      return;
   }

   if(CooldownActive()) return;

   //--- One trade per M1 candle ---
   datetime candle = iTime(_Symbol, PERIOD_M1, 0);
   if(candle == LastTradeCandle) return;

   //--- ATR distances ---
   double atr           = GetATR();
   double breakoutBuffer = atr * Breakout_ATR_Mult;
   double pullbackSize   = atr * Pullback_ATR_Mult;
   double slDistance    = atr * SL_ATR_Multiplier;
   double tpDistance    = atr * TP_ATR_Multiplier;

   //--- Previous candle OHLC ---
   double prevHigh = iHigh (_Symbol, PERIOD_M1, 1);
   double prevLow  = iLow  (_Symbol, PERIOD_M1, 1);

   //=== BREAKOUT EXPIRY — auto-reset stale states ===//
   if(BuyBreakout  && BreakoutExpired(BreakoutBuyTime))
   {
      BuyBreakout    = false;
      BreakoutHigh   = 0;
      BreakoutBuyTime = 0;
   }
   if(SellBreakout && BreakoutExpired(BreakoutSellTime))
   {
      SellBreakout    = false;
      BreakoutLow     = 0;
      BreakoutSellTime = 0;
   }

   //=== BREAKOUT DETECTION ===//
   // Buy breakout: price breaks above prev high + buffer, with bullish HTF bias
   // AND candle body confirms conviction (no wick spikes)
   if(!BuyBreakout &&
      HTFBullish() &&
      ask > prevHigh + breakoutBuffer &&
      CandleBodyOK(1))
   {
      BuyBreakout     = true;
      BreakoutHigh    = ask;
      BreakoutBuyTime = candle;
   }

   // Sell breakout: price breaks below prev low - buffer, bearish HTF bias
   if(!SellBreakout &&
      HTFBearish() &&
      bid < prevLow - breakoutBuffer &&
      CandleBodyOK(1))
   {
      SellBreakout     = true;
      BreakoutLow      = bid;
      BreakoutSellTime = candle;
   }

   //=== BUY PULLBACK ENTRY ===//
   if(BuyBreakout                          &&
      bid <= BreakoutHigh - pullbackSize   &&
      HTFBullish()                         &&
      RSIConfirmsBuy()                     &&
      !HedgeBlocked(POSITION_TYPE_BUY))
   {
      double sl = NormalizePrice(ask - slDistance);
      double tp = NormalizePrice(ask + tpDistance);

      if(trade.Buy(LotSize, _Symbol, ask, sl, tp, "SOC BUY v2.1"))
      {
         BuyBreakout     = false;
         BreakoutHigh    = 0;
         BreakoutBuyTime = 0;
         LastTradeCandle = candle;
      }
   }

   //=== SELL PULLBACK ENTRY ===//
   if(SellBreakout                         &&
      ask >= BreakoutLow + pullbackSize    &&
      HTFBearish()                         &&
      RSIConfirmsSell()                    &&
      !HedgeBlocked(POSITION_TYPE_SELL))
   {
      double sl = NormalizePrice(bid + slDistance);
      double tp = NormalizePrice(bid - tpDistance);

      if(trade.Sell(LotSize, _Symbol, bid, sl, tp, "SOC SELL v2.1"))
      {
         SellBreakout     = false;
         BreakoutLow      = 0;
         BreakoutSellTime = 0;
         LastTradeCandle  = candle;
      }
   }
}
//+------------------------------------------------------------------+