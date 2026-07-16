//+------------------------------------------------------------------+
//|                     SOC Swing EA Pro                             |
//|     Strategy 1 (EMA Pullback) + Strategy 2 (BOS/CHOCH Retest)   |
//|  EMA 21/55/200 | 4H+1H Direction | Daily S&R | All Exec Modes   |
//|                  Compatible: All Instruments                     |
//|                     Broker: Exness MT5                           |
//+------------------------------------------------------------------+
#property copyright "Sons-Of-Christ"
#property version   "1.20"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade        Trade;
CPositionInfo PosInfo;

//==========================================================
//  ENUMS
//==========================================================
enum ENUM_EXEC_MODE
{
   EXEC_PENDING  = 0,   // Pending Orders (fully automated)
   EXEC_MANUAL   = 1,   // Manual Execution (alert + dashboard button)
   EXEC_HYBRID   = 2    // Hybrid (auto pending + manual override)
};

enum ENUM_TREND  { TREND_UP, TREND_DOWN, TREND_NONE };
enum ENUM_SIGNAL { SIG_BUY, SIG_SELL, SIG_NONE };

//==========================================================
//  INPUTS
//==========================================================
input group "=== EXECUTION MODE ==="
input ENUM_EXEC_MODE InpExecMode      = EXEC_HYBRID;   // Execution mode
input bool           InpUseBuyLimit   = true;          // Use Limit orders for pullbacks
input bool           InpUseBuyStop    = true;          // Use Stop orders for breakouts
input int            InpOrderExpBars  = 10;            // Pending order expiry (4H bars)

input group "=== RISK MANAGEMENT ==="
input bool   InpAutoLot               = true;          // Auto lot (% risk) or fixed
input double InpLotSize               = 0.10;          // Fixed lot size
input double InpRiskPercent           = 1.0;           // Risk % per trade
input int    InpMaxTrades             = 3;             // Max simultaneous swing trades
input int    InpMaxSpread             = 50;            // Max spread in points (wider for swing)

input group "=== EMA SETTINGS ==="
input int    InpEMA_Fast              = 21;            // Fast EMA  (21 - Fibonacci)
input int    InpEMA_Mid               = 55;            // Mid EMA   (55 - Fibonacci)
input int    InpEMA_Slow              = 200;           // Slow EMA  (200 - Macro anchor)

input group "=== ATR / SL / TP ==="
input int    InpATR_Period            = 14;            // ATR period
input double InpSL_ATR_Multi          = 2.0;           // SL = ATR x this (wider for swing)
input double InpTP_ATR_Multi          = 4.0;           // TP = ATR x this (1:2 minimum)
input int    InpFallbackSL            = 1500;          // Fallback SL points
input int    InpFallbackTP            = 3000;          // Fallback TP points

input group "=== STRUCTURE SETTINGS (Strategy 2) ==="
input int    InpStructLookback        = 50;            // Bars to scan for BOS/CHOCH on 4H
input double InpStructZonePct         = 0.002;         // Structure zone width as % of price
input bool   InpUseBOS                = true;          // Use Break of Structure entries
input bool   InpUseCHOCH              = true;          // Use Change of Character entries

input group "=== EMA PULLBACK SETTINGS (Strategy 1) ==="
input bool   InpUsePullbackEMA21      = true;          // Pullback to EMA 21 entries
input bool   InpUsePullbackEMA55      = true;          // Pullback to EMA 55 entries
input double InpPullbackZonePct       = 0.001;         // Pullback zone around EMA as % price

input group "=== HTF FILTERS ==="
input bool   InpUse4HFilter           = true;          // 4H EMA alignment filter (primary direction)
input bool   InpUse1HFilter           = true;          // 1H EMA alignment filter (confirmation)

input group "=== DAILY S&R SETTINGS ==="
input bool   InpUseDailySR            = true;          // Use Daily S&R zones as confluence
input int    InpDailySR_Lookback      = 30;            // Daily bars to scan for swing highs/lows
input double InpDailySR_ZonePct       = 0.004;         // Daily S&R zone width as % of price
input bool   InpDailyEMA200_SR        = true;          // Use Daily EMA200 as S&R zone
input double InpDailySR_LotBoost      = 1.5;           // Lot multiplier when near Daily S&R (1.0=off)

input group "=== TRADE MANAGEMENT ==="
input bool   InpUseBreakEven          = true;          // Move SL to break-even
input double InpBreakEvenAt           = 1.0;           // Trigger BE at X * SL dist in profit
input bool   InpUseTrailing           = true;          // Trailing stop
input double InpTrailATRMulti         = 1.5;           // Trail = ATR x this
input bool   InpUsePartialClose       = true;          // Partial close at first TP
input double InpPartialClosePct       = 50.0;          // % of position to close at TP1
input double InpTP1_ATR_Multi         = 2.0;           // TP1 (partial) = ATR x this

input group "=== ALERTS ==="
input bool   InpAlertScreen           = true;          // Screen alert on signal
input bool   InpAlertEmail            = false;         // Email alert on signal
input bool   InpAlertPush             = false;         // Push notification on signal

input group "=== DASHBOARD ==="
input bool   InpShowDash              = true;          // Show dashboard
input int    InpDashX                 = 15;            // Dashboard X position
input int    InpDashY                 = 30;            // Dashboard Y position

//==========================================================
//  GLOBALS
//==========================================================
// Daily handles
int hFast_D1,  hMid_D1,  hSlow_D1;
// 4H handles
int hFast_H4,  hMid_H4,  hSlow_H4,  hATR_H4;
// 1H handles
int hFast_H1,  hMid_H1,  hSlow_H1;

// Buffers
double emaFast_D1[], emaMid_D1[], emaSlow_D1[];
double emaFast_H4[], emaMid_H4[], emaSlow_H4[];
double emaFast_H1[], emaMid_H1[], emaSlow_H1[];
double atr_H4[];

datetime LastBar_H4    = 0;
datetime LastBar_D1    = 0;
double   DailySR_Support  = 0;   // nearest daily support level
double   DailySR_Resist   = 0;   // nearest daily resistance level
double   DailyEMA200      = 0;   // daily EMA200 current value
bool     NearDailySR      = false;
datetime LastBar_H1    = 0;
double   ask, bid;
bool     PartialDone   = false;

// Manual mode — pending signal waiting for button press
ENUM_SIGNAL PendingManualSig  = SIG_NONE;
double      PendingEntryPrice = 0;
double      PendingSL         = 0;
double      PendingTP         = 0;
double      PendingTP1        = 0;
double      PendingLots       = 0;
string      PendingReason     = "";

// Pending order tracking
ulong  PendingOrderTicket     = 0;
datetime PendingOrderExpiry   = 0;

string DashPfx = "SOCSW_";
string EaName  = "SOC Swing EA Pro";
string EaVer   = "v1.20";

// Button names
string BtnBuy  = "SOCSW_BTN_BUY";
string BtnSell = "SOCSW_BTN_SELL";
string BtnCancel="SOCSW_BTN_CANCEL";

//==========================================================
//  INIT
//==========================================================
int OnInit()
{
   Trade.SetExpertMagicNumber(212155);
   Trade.SetDeviationInPoints(50);
   Trade.SetTypeFilling(ORDER_FILLING_RETURN);

   // Daily EMA200 only — used as S&R zone, not for direction
   hSlow_D1 = iMA(_Symbol, PERIOD_D1,  InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hFast_D1 = hSlow_D1; // alias — not used independently
   hMid_D1  = hSlow_D1; // alias — not used independently

   // 4H EMAs + ATR
   hFast_H4 = iMA(_Symbol, PERIOD_H4,  InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hMid_H4  = iMA(_Symbol, PERIOD_H4,  InpEMA_Mid,  0, MODE_EMA, PRICE_CLOSE);
   hSlow_H4 = iMA(_Symbol, PERIOD_H4,  InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hATR_H4  = iATR(_Symbol, PERIOD_H4, InpATR_Period);

   // 1H EMAs
   hFast_H1 = iMA(_Symbol, PERIOD_H1,  InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hMid_H1  = iMA(_Symbol, PERIOD_H1,  InpEMA_Mid,  0, MODE_EMA, PRICE_CLOSE);
   hSlow_H1 = iMA(_Symbol, PERIOD_H1,  InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   if(hSlow_D1==INVALID_HANDLE ||
      hFast_H4==INVALID_HANDLE || hMid_H4==INVALID_HANDLE || hSlow_H4==INVALID_HANDLE ||
      hFast_H1==INVALID_HANDLE || hMid_H1==INVALID_HANDLE || hSlow_H1==INVALID_HANDLE ||
      hATR_H4==INVALID_HANDLE)
   { Print("ERROR: Indicator handle failed."); return INIT_FAILED; }

   ArraySetAsSeries(emaFast_D1, true); ArraySetAsSeries(emaMid_D1, true); ArraySetAsSeries(emaSlow_D1, true);
   ArraySetAsSeries(emaFast_H4, true); ArraySetAsSeries(emaMid_H4, true); ArraySetAsSeries(emaSlow_H4, true);
   ArraySetAsSeries(emaFast_H1, true); ArraySetAsSeries(emaMid_H1, true); ArraySetAsSeries(emaSlow_H1, true);
   ArraySetAsSeries(atr_H4,     true);

   if(InpShowDash) CreateDashboard();
   Print(EaName, " ", EaVer, " initialized on ", _Symbol);
   return INIT_SUCCEEDED;
}

//==========================================================
//  DEINIT
//==========================================================
void OnDeinit(const int reason)
{
   int h[]={hFast_D1,hMid_D1,hSlow_D1,hFast_H4,hMid_H4,hSlow_H4,hFast_H1,hMid_H1,hSlow_H1,hATR_H4};
   for(int i=0;i<ArraySize(h);i++) IndicatorRelease(h[i]);
   DeleteDashboard();
}

//==========================================================
//  ON TICK
//==========================================================
void OnTick()
{
   ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   ManageOpenTrades();
   CheckPendingOrderExpiry();
   if(InpShowDash) UpdateDashboard();

   if(!SpreadOK()) return;
   if(CountMyTrades() >= InpMaxTrades) return;

   // 4H bar gate — strategy evaluation
   datetime curH4 = iTime(_Symbol, PERIOD_H4, 0);
   if(curH4 != LastBar_H4)
   {
      LastBar_H4 = curH4;
      if(RefreshData()) EvaluateSetup();
   }

   // 1H bar gate — confirmation check
   datetime curH1 = iTime(_Symbol, PERIOD_H1, 0);
   if(curH1 != LastBar_H1)
   {
      LastBar_H1 = curH1;
      if(RefreshData()) CheckConfirmation();
   }
}

//==========================================================
//  ON CHART EVENT — Manual button clicks
//==========================================================
void OnChartEvent(const int id, const long& lparam,
                  const double& dparam, const string& sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   if(sparam == BtnBuy && PendingManualSig == SIG_BUY)
   {
      ExecuteMarketOrder(ORDER_TYPE_BUY, PendingLots, PendingSL, PendingTP, PendingReason);
      ClearManualSignal();
   }
   else if(sparam == BtnSell && PendingManualSig == SIG_SELL)
   {
      ExecuteMarketOrder(ORDER_TYPE_SELL, PendingLots, PendingSL, PendingTP, PendingReason);
      ClearManualSignal();
   }
   else if(sparam == BtnCancel)
   {
      // Cancel pending order if hybrid mode
      if(PendingOrderTicket > 0)
      {
         Trade.OrderDelete(PendingOrderTicket);
         PendingOrderTicket = 0;
         Print("Pending order cancelled by user.");
      }
      ClearManualSignal();
   }
}

//==========================================================
//  REFRESH DATA
//==========================================================
bool RefreshData()
{
   int b = InpEMA_Slow + InpStructLookback + 10;
   // Daily — EMA200 only for S&R
   if(CopyBuffer(hSlow_D1, 0,0,b,emaSlow_D1) <=0) return false;
   if(CopyBuffer(hFast_H4, 0,0,b,emaFast_H4) <=0) return false;
   if(CopyBuffer(hMid_H4,  0,0,b,emaMid_H4)  <=0) return false;
   if(CopyBuffer(hSlow_H4, 0,0,b,emaSlow_H4) <=0) return false;
   if(CopyBuffer(hFast_H1, 0,0,b,emaFast_H1) <=0) return false;
   if(CopyBuffer(hMid_H1,  0,0,b,emaMid_H1)  <=0) return false;
   if(CopyBuffer(hSlow_H1, 0,0,b,emaSlow_H1) <=0) return false;
   if(CopyBuffer(hATR_H4,  0,0,10,atr_H4)    <=0) return false;
   return true;
}

//==========================================================
//  TREND
//  EMA21 > EMA200 AND EMA55 > EMA200 = BULL
//  EMA21 < EMA200 AND EMA55 < EMA200 = BEAR
//==========================================================
ENUM_TREND GetTrend(double fast, double mid, double slow)
{
   if(fast > slow && mid > slow) return TREND_UP;
   if(fast < slow && mid < slow) return TREND_DOWN;
   return TREND_NONE;
}

//==========================================================
//  STRATEGY EVALUATION (runs on new 4H bar)
//==========================================================
void EvaluateSetup()
{
   // Already have a signal waiting
   if(PendingManualSig != SIG_NONE) return;
   if(PendingOrderTicket > 0) return;

   // --- Primary direction: 4H EMA alignment ---
   ENUM_TREND t4H = GetTrend(emaFast_H4[1], emaMid_H4[1], emaSlow_H4[1]);
   if(InpUse4HFilter && t4H == TREND_NONE) return;

   // --- Secondary direction: 1H EMA must agree with 4H ---
   ENUM_TREND t1H_dir = GetTrend(emaFast_H1[1], emaMid_H1[1], emaSlow_H1[1]);
   if(InpUse1HFilter && (t1H_dir == TREND_NONE || t1H_dir != t4H)) return;

   ENUM_TREND trend = t4H;

   // --- Daily S&R confluence detection ---
   NearDailySR = false;
   double dailyZoneW = bid * InpDailySR_ZonePct;

   // Daily EMA200 as S&R
   if(InpDailyEMA200_SR && ArraySize(emaSlow_D1) > 1)
   {
      DailyEMA200 = emaSlow_D1[1];
      if(MathAbs(bid - DailyEMA200) <= dailyZoneW * 2)
         NearDailySR = true;
   }

   // Daily swing high/low S&R scan
   if(InpUseDailySR)
   {
      double nearestSupport  = 0;
      double nearestResist   = DBL_MAX;

      for(int i = 2; i < InpDailySR_Lookback; i++)
      {
         double dLow  = iLow (_Symbol, PERIOD_D1, i);
         double dHigh = iHigh(_Symbol, PERIOD_D1, i);

         // Swing low = support
         if(dLow < iLow(_Symbol,PERIOD_D1,i-1) && dLow < iLow(_Symbol,PERIOD_D1,i+1))
         {
            if(dLow > nearestSupport && dLow < bid)
               nearestSupport = dLow;
         }
         // Swing high = resistance
         if(dHigh > iHigh(_Symbol,PERIOD_D1,i-1) && dHigh > iHigh(_Symbol,PERIOD_D1,i+1))
         {
            if(dHigh < nearestResist && dHigh > bid)
               nearestResist = dHigh;
         }
      }

      DailySR_Support = nearestSupport;
      DailySR_Resist  = (nearestResist == DBL_MAX) ? 0 : nearestResist;

      // Check if current price is near a daily S&R zone
      if(nearestSupport > 0 && MathAbs(bid - nearestSupport) <= dailyZoneW)
         NearDailySR = true;
      if(nearestResist < DBL_MAX && MathAbs(ask - nearestResist) <= dailyZoneW)
         NearDailySR = true;

      // Draw Daily S&R zones on chart
      if(nearestSupport > 0)
         DrawDailySRZone(nearestSupport - dailyZoneW,
                         nearestSupport + dailyZoneW, true,  "SUP");
      if(nearestResist < DBL_MAX)
         DrawDailySRZone(nearestResist  - dailyZoneW,
                         nearestResist  + dailyZoneW, false, "RES");
      if(InpDailyEMA200_SR && DailyEMA200 > 0)
         DrawDailySRZone(DailyEMA200 - dailyZoneW * 2,
                         DailyEMA200 + dailyZoneW * 2, (bid > DailyEMA200), "EMA200");
   }
   double atr = atr_H4[1];
   if(atr <= 0) return;

   string reason = "";
   double entryPrice = 0, slPrice = 0, tpPrice = 0, tp1Price = 0;
   ENUM_SIGNAL sig = SIG_NONE;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDist = atr * InpSL_ATR_Multi;
   double tpDist = atr * InpTP_ATR_Multi;
   double tp1Dist= atr * InpTP1_ATR_Multi;

   // -------------------------------------------------------
   // STRATEGY 1: EMA PULLBACK
   // Price pulls back to EMA21 or EMA55 on 4H in trend dir
   // -------------------------------------------------------
   if(trend == TREND_UP)
   {
      double ema21 = emaFast_H4[1];
      double ema55 = emaMid_H4[1];
      double close1= iClose(_Symbol, PERIOD_H4, 1);
      double low1  = iLow  (_Symbol, PERIOD_H4, 1);
      double zoneW = ask * InpPullbackZonePct;

      // Pullback to EMA21
      if(InpUsePullbackEMA21 &&
         low1 <= ema21 + zoneW && low1 >= ema21 - zoneW &&
         close1 > ema21)
      {
         entryPrice = ema21 + zoneW;
         slPrice    = NormalizeDouble(ema55 - atr * 0.5, digits);
         tpPrice    = NormalizeDouble(entryPrice + tpDist, digits);
         tp1Price   = NormalizeDouble(entryPrice + tp1Dist, digits);
         sig        = SIG_BUY;
         reason     = "Pullback to EMA21";
      }
      // Pullback to EMA55
      else if(InpUsePullbackEMA55 &&
              low1 <= ema55 + zoneW && low1 >= ema55 - zoneW &&
              close1 > ema55)
      {
         entryPrice = ema55 + zoneW;
         slPrice    = NormalizeDouble(ema55 - atr * 1.0, digits);
         tpPrice    = NormalizeDouble(entryPrice + tpDist, digits);
         tp1Price   = NormalizeDouble(entryPrice + tp1Dist, digits);
         sig        = SIG_BUY;
         reason     = "Pullback to EMA55";
      }
   }
   else if(trend == TREND_DOWN)
   {
      double ema21 = emaFast_H4[1];
      double ema55 = emaMid_H4[1];
      double close1= iClose(_Symbol, PERIOD_H4, 1);
      double high1 = iHigh (_Symbol, PERIOD_H4, 1);
      double zoneW = bid * InpPullbackZonePct;

      if(InpUsePullbackEMA21 &&
         high1 >= ema21 - zoneW && high1 <= ema21 + zoneW &&
         close1 < ema21)
      {
         entryPrice = ema21 - zoneW;
         slPrice    = NormalizeDouble(ema55 + atr * 0.5, digits);
         tpPrice    = NormalizeDouble(entryPrice - tpDist, digits);
         tp1Price   = NormalizeDouble(entryPrice - tp1Dist, digits);
         sig        = SIG_SELL;
         reason     = "Pullback to EMA21";
      }
      else if(InpUsePullbackEMA55 &&
              high1 >= ema55 - zoneW && high1 <= ema55 + zoneW &&
              close1 < ema55)
      {
         entryPrice = ema55 - zoneW;
         slPrice    = NormalizeDouble(ema55 + atr * 1.0, digits);
         tpPrice    = NormalizeDouble(entryPrice - tpDist, digits);
         tp1Price   = NormalizeDouble(entryPrice - tp1Dist, digits);
         sig        = SIG_SELL;
         reason     = "Pullback to EMA55";
      }
   }

   // -------------------------------------------------------
   // STRATEGY 2: BOS / CHOCH RETEST
   // Detects Break of Structure or Change of Character on 4H
   // then waits for price to retest the broken level
   // -------------------------------------------------------
   if(sig == SIG_NONE)
   {
      double bosLevel = 0;
      string bosType  = "";

      if(trend == TREND_UP)
      {
         // BOS: Find last significant swing high that was broken
         double swingHigh = 0;
         int    swingBar  = 0;
         for(int i = 3; i < InpStructLookback; i++)
         {
            double hi = iHigh(_Symbol, PERIOD_H4, i);
            if(hi > iHigh(_Symbol, PERIOD_H4, i-1) &&
               hi > iHigh(_Symbol, PERIOD_H4, i+1) &&
               hi > swingHigh)
            { swingHigh = hi; swingBar = i; }
         }

         // CHOCH: Previous structure high broken = change of character
         if(InpUseBOS && swingHigh > 0)
         {
            double recentClose = iClose(_Symbol, PERIOD_H4, 1);
            double zoneW = swingHigh * InpStructZonePct;
            // Price broke above swing high and is now retesting it
            if(recentClose > swingHigh &&
               bid >= swingHigh - zoneW && bid <= swingHigh + zoneW * 2)
            {
               bosLevel   = swingHigh;
               bosType    = "BOS Retest";
               entryPrice = swingHigh + zoneW;
               slPrice    = NormalizeDouble(swingHigh - atr * InpSL_ATR_Multi, digits);
               tpPrice    = NormalizeDouble(entryPrice + tpDist, digits);
               tp1Price   = NormalizeDouble(entryPrice + tp1Dist, digits);
               sig        = SIG_BUY;
               reason     = bosType + " (Buy)";
               DrawStructureZone(bosLevel, bosLevel + zoneW*2, true);
            }
         }
      }
      else if(trend == TREND_DOWN)
      {
         double swingLow = DBL_MAX;
         int    swingBar = 0;
         for(int i = 3; i < InpStructLookback; i++)
         {
            double lo = iLow(_Symbol, PERIOD_H4, i);
            if(lo < iLow(_Symbol, PERIOD_H4, i-1) &&
               lo < iLow(_Symbol, PERIOD_H4, i+1) &&
               lo < swingLow)
            { swingLow = lo; swingBar = i; }
         }

         if(InpUseBOS && swingLow < DBL_MAX)
         {
            double recentClose = iClose(_Symbol, PERIOD_H4, 1);
            double zoneW = swingLow * InpStructZonePct;
            if(recentClose < swingLow &&
               ask <= swingLow + zoneW && ask >= swingLow - zoneW * 2)
            {
               bosLevel   = swingLow;
               bosType    = "BOS Retest";
               entryPrice = swingLow - zoneW;
               slPrice    = NormalizeDouble(swingLow + atr * InpSL_ATR_Multi, digits);
               tpPrice    = NormalizeDouble(entryPrice - tpDist, digits);
               tp1Price   = NormalizeDouble(entryPrice - tp1Dist, digits);
               sig        = SIG_SELL;
               reason     = bosType + " (Sell)";
               DrawStructureZone(swingLow - zoneW*2, swingLow, false);
            }
         }
      }
   }

   // No setup found
   if(sig == SIG_NONE) return;

   // -------------------------------------------------------
   // 1H EMA ALIGNMENT FILTER (v1.10)
   // Before accepting any setup, the 1H EMA stack must agree
   // with the signal direction. Both EMA21 and EMA55 on 1H
   // must be on the correct side of the 1H EMA200.
   // This replaces the old "candle body only" check and makes
   // 1H EMAs the primary confirmation layer.
   // -------------------------------------------------------
   ENUM_TREND t1H_check = GetTrend(emaFast_H1[1], emaMid_H1[1], emaSlow_H1[1]);
   if(sig == SIG_BUY  && t1H_check != TREND_UP)   return; // 1H not bullish — skip
   if(sig == SIG_SELL && t1H_check != TREND_DOWN)  return; // 1H not bearish — skip

   // Additional 1H momentum check: EMA21 must be pulling away from EMA55
   // in the correct direction (momentum alignment)
   bool h1_bull_momentum = (emaFast_H1[1] > emaMid_H1[1]) &&
                           (emaFast_H1[1] > emaFast_H1[2]); // EMA21 rising
   bool h1_bear_momentum = (emaFast_H1[1] < emaMid_H1[1]) &&
                           (emaFast_H1[1] < emaFast_H1[2]); // EMA21 falling

   if(sig == SIG_BUY  && !h1_bull_momentum) return;
   if(sig == SIG_SELL && !h1_bear_momentum) return;

   double lots = CalcLotSize(MathAbs(entryPrice - slPrice));
   if(lots <= 0) return;

   // Boost lot size when setup aligns with Daily S&R zone
   if(NearDailySR && InpDailySR_LotBoost > 1.0)
   {
      double boostedLots = lots * InpDailySR_LotBoost;
      double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      boostedLots = MathFloor(boostedLots / step) * step;
      lots = MathMin(boostedLots, maxL);
      reason = reason + " [+Daily S&R]";
   }

   // Fire alert
   FireAlert(reason, sig);

   // Execute based on mode
   if(InpExecMode == EXEC_PENDING)
   {
      PlacePendingOrder(sig, entryPrice, slPrice, tpPrice, lots, reason);
   }
   else if(InpExecMode == EXEC_MANUAL)
   {
      // Store signal — wait for button press
      PendingManualSig  = sig;
      PendingEntryPrice = entryPrice;
      PendingSL         = slPrice;
      PendingTP         = tpPrice;
      PendingTP1        = tp1Price;
      PendingLots       = lots;
      PendingReason     = reason;
      ShowManualButtons(sig);
   }
   else if(InpExecMode == EXEC_HYBRID)
   {
      // Place pending order AND show manual buttons
      PlacePendingOrder(sig, entryPrice, slPrice, tpPrice, lots, reason);
      PendingManualSig  = sig;
      PendingEntryPrice = entryPrice;
      PendingSL         = slPrice;
      PendingTP         = tpPrice;
      PendingTP1        = tp1Price;
      PendingLots       = lots;
      PendingReason     = reason;
      ShowManualButtons(sig);
   }
}

//==========================================================
//  1H CONFIRMATION CHECK  (v1.10 — upgraded)
//  Three-layer 1H confirmation:
//  Layer 1 — 1H EMA stack aligned (21 & 55 vs 200)
//  Layer 2 — 1H EMA21 momentum direction (rising/falling)
//  Layer 3 — 1H candle closed with body > 50% of range
//  ALL THREE must pass for confirmed status
//==========================================================
void CheckConfirmation()
{
   if(PendingManualSig == SIG_NONE && PendingOrderTicket == 0) return;

   // Layer 1: Full 1H EMA stack alignment
   ENUM_TREND t1H = GetTrend(emaFast_H1[1], emaMid_H1[1], emaSlow_H1[1]);

   // Layer 2: 1H EMA21 momentum — is it actively moving in signal direction?
   bool ema21_rising  = (emaFast_H1[1] > emaFast_H1[2]) &&
                        (emaFast_H1[1] > emaMid_H1[1]);   // above EMA55
   bool ema21_falling = (emaFast_H1[1] < emaFast_H1[2]) &&
                        (emaFast_H1[1] < emaMid_H1[1]);   // below EMA55

   // Layer 3: 1H candle body strength
   double c1 = iClose(_Symbol, PERIOD_H1, 1);
   double o1 = iOpen (_Symbol, PERIOD_H1, 1);
   double h1 = iHigh (_Symbol, PERIOD_H1, 1);
   double l1 = iLow  (_Symbol, PERIOD_H1, 1);
   double range = h1 - l1;
   bool strongBull = (c1 > o1) && range > 0 && (c1 - o1 > range * 0.5);
   bool strongBear = (c1 < o1) && range > 0 && (o1 - c1 > range * 0.5);

   // Full confirmation requires all three layers
   bool bullConfirm = (t1H == TREND_UP)   && ema21_rising  && strongBull;
   bool bearConfirm = (t1H == TREND_DOWN) && ema21_falling && strongBear;

   // Partial confirmation — EMA aligned but candle not yet strong
   bool bullPartial = (t1H == TREND_UP)   && ema21_rising  && !strongBull;
   bool bearPartial = (t1H == TREND_DOWN) && ema21_falling && !strongBear;

   // For pending mode: hold order but update confirmation display
   if(PendingOrderTicket > 0 && InpExecMode == EXEC_PENDING)
   {
      bool confirmed = (PendingManualSig == SIG_BUY  && bullConfirm) ||
                       (PendingManualSig == SIG_SELL && bearConfirm);
      bool partial   = (PendingManualSig == SIG_BUY  && bullPartial) ||
                       (PendingManualSig == SIG_SELL && bearPartial);
      UpdateConfirmationStatus(confirmed, partial);
      return;
   }

   // For manual/hybrid — update dashboard confirmation row
   if(PendingManualSig != SIG_NONE)
   {
      bool confirmed = (PendingManualSig == SIG_BUY  && bullConfirm) ||
                       (PendingManualSig == SIG_SELL && bearConfirm);
      bool partial   = (PendingManualSig == SIG_BUY  && bullPartial) ||
                       (PendingManualSig == SIG_SELL && bearPartial);
      UpdateConfirmationStatus(confirmed, partial);
   }
}

//==========================================================
//  PLACE PENDING ORDER
//==========================================================
void PlacePendingOrder(ENUM_SIGNAL sig, double price, double sl,
                       double tp, double lots, string reason)
{
   int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double normP   = NormalizeDouble(price, digits);
   double normSL  = NormalizeDouble(sl,    digits);
   double normTP  = NormalizeDouble(tp,    digits);

   datetime expiry = TimeCurrent() + InpOrderExpBars * PeriodSeconds(PERIOD_H4);
   string   cmt    = EaName + " | " + reason;
   bool     ok     = false;

   if(sig == SIG_BUY)
   {
      // Use limit if price is below current ask (expecting pullback)
      // Use stop if price is above current ask (breakout)
      if(InpUseBuyLimit && normP < ask)
         ok = Trade.BuyLimit(lots, normP, _Symbol, normSL, normTP, ORDER_TIME_SPECIFIED, expiry, cmt);
      else if(InpUseBuyStop && normP > ask)
         ok = Trade.BuyStop(lots,  normP, _Symbol, normSL, normTP, ORDER_TIME_SPECIFIED, expiry, cmt);
      else
         ok = Trade.BuyLimit(lots, normP, _Symbol, normSL, normTP, ORDER_TIME_SPECIFIED, expiry, cmt);
   }
   else
   {
      if(InpUseBuyLimit && normP > bid)
         ok = Trade.SellLimit(lots, normP, _Symbol, normSL, normTP, ORDER_TIME_SPECIFIED, expiry, cmt);
      else if(InpUseBuyStop && normP < bid)
         ok = Trade.SellStop(lots,  normP, _Symbol, normSL, normTP, ORDER_TIME_SPECIFIED, expiry, cmt);
      else
         ok = Trade.SellLimit(lots, normP, _Symbol, normSL, normTP, ORDER_TIME_SPECIFIED, expiry, cmt);
   }

   if(ok)
   {
      PendingOrderTicket = Trade.ResultOrder();
      PendingOrderExpiry = expiry;
      Print("Pending order placed: ", reason, " | Ticket=", PendingOrderTicket,
            " Price=", normP, " SL=", normSL, " TP=", normTP);
   }
   else
      Print("Pending order FAILED: err=", GetLastError(), " ret=", Trade.ResultRetcode());
}

//==========================================================
//  EXECUTE MARKET ORDER (Manual button press)
//==========================================================
void ExecuteMarketOrder(ENUM_ORDER_TYPE type, double lots,
                        double sl, double tp, string reason)
{
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double entry  = (type==ORDER_TYPE_BUY) ? ask : bid;
   double normSL = NormalizeDouble(sl, digits);
   double normTP = NormalizeDouble(tp, digits);
   string cmt    = EaName + " | " + reason + " | Manual";

   bool ok = (type==ORDER_TYPE_BUY)
             ? Trade.Buy(lots,  _Symbol, entry, normSL, normTP, cmt)
             : Trade.Sell(lots, _Symbol, entry, normSL, normTP, cmt);

   // Cancel any existing pending order for same setup
   if(ok && PendingOrderTicket > 0)
   {
      Trade.OrderDelete(PendingOrderTicket);
      PendingOrderTicket = 0;
   }

   if(ok) Print("Manual order executed: ", (type==ORDER_TYPE_BUY?"BUY":"SELL"),
                " lots=", lots, " sl=", normSL, " tp=", normTP);
   else   Print("Manual order FAILED: err=", GetLastError());
}

//==========================================================
//  CHECK PENDING ORDER EXPIRY
//==========================================================
void CheckPendingOrderExpiry()
{
   if(PendingOrderTicket == 0) return;
   // Check if order still exists
   if(!OrderSelect(PendingOrderTicket))
   {
      // Order was filled or cancelled externally
      PendingOrderTicket = 0;
      ClearManualSignal();
   }
}

//==========================================================
//  MANAGE OPEN TRADES
//==========================================================
void ManageOpenTrades()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!PosInfo.SelectByIndex(i)) continue;
      if(PosInfo.Symbol()!=_Symbol || PosInfo.Magic()!=212155) continue;

      double open  = PosInfo.PriceOpen();
      double curSL = PosInfo.StopLoss();
      double curTP = PosInfo.TakeProfit();
      int    digs  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double pt    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double atr   = (ArraySize(atr_H4)>1) ? atr_H4[1] : 0;
      double lots  = PosInfo.Volume();

      if(PosInfo.PositionType()==POSITION_TYPE_BUY)
      {
         double sld = open - curSL;
         double prf = bid - open;

         // Partial close at TP1
         if(InpUsePartialClose && !PartialDone && PendingTP1 > 0 && bid >= PendingTP1)
         {
            double closeLots = NormalizeDouble(lots * InpPartialClosePct / 100.0,
                               (int)MathLog10(1.0/SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)));
            if(closeLots >= SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))
            {
               Trade.PositionClosePartial(PosInfo.Ticket(), closeLots);
               PartialDone = true;
               Print("Partial close: ", closeLots, " lots at TP1=", PendingTP1);
            }
         }

         // Break-even
         if(InpUseBreakEven && curSL < open && sld > 0 && prf >= sld * InpBreakEvenAt)
         {
            double nsl = NormalizeDouble(open + pt*2, digs);
            if(nsl > curSL) Trade.PositionModify(PosInfo.Ticket(), nsl, curTP);
         }

         // Trailing
         if(InpUseTrailing && atr > 0)
         {
            double tsl = NormalizeDouble(bid - atr * InpTrailATRMulti, digs);
            if(tsl > curSL && tsl < bid)
               Trade.PositionModify(PosInfo.Ticket(), tsl, curTP);
         }
      }
      else if(PosInfo.PositionType()==POSITION_TYPE_SELL)
      {
         double sld = curSL - open;
         double prf = open - ask;

         if(InpUsePartialClose && !PartialDone && PendingTP1 > 0 && ask <= PendingTP1)
         {
            double closeLots = NormalizeDouble(lots * InpPartialClosePct / 100.0,
                               (int)MathLog10(1.0/SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)));
            if(closeLots >= SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))
            {
               Trade.PositionClosePartial(PosInfo.Ticket(), closeLots);
               PartialDone = true;
            }
         }

         if(InpUseBreakEven && curSL > open && sld > 0 && prf >= sld * InpBreakEvenAt)
         {
            double nsl = NormalizeDouble(open - pt*2, digs);
            if(nsl < curSL) Trade.PositionModify(PosInfo.Ticket(), nsl, curTP);
         }

         if(InpUseTrailing && atr > 0)
         {
            double tsl = NormalizeDouble(ask + atr * InpTrailATRMulti, digs);
            if(tsl < curSL && tsl > ask)
               Trade.PositionModify(PosInfo.Ticket(), tsl, curTP);
         }
      }
   }
}

//==========================================================
//  DRAW STRUCTURE ZONE ON CHART
//==========================================================
void DrawStructureZone(double lo, double hi, bool isBull)
{
   string name = DashPfx + "ZONE_" + IntegerToString(TimeCurrent());
   datetime t1 = iTime(_Symbol, PERIOD_H4, InpStructLookback);
   datetime t2 = iTime(_Symbol, PERIOD_H4, 0) + PeriodSeconds(PERIOD_H4) * 20;
   color zoneClr = isBull ? C'200,240,215' : C'255,210,210';

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, lo, t2, hi);
   ObjectSetInteger(0, name, OBJPROP_COLOR,   zoneClr);
   ObjectSetInteger(0, name, OBJPROP_FILL,    true);
   ObjectSetInteger(0, name, OBJPROP_BACK,    true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ChartRedraw();
}

//==========================================================
//  DRAW DAILY S&R ZONE
//==========================================================
void DrawDailySRZone(double lo, double hi, bool isSupport, string tag)
{
   string name = DashPfx + "DSR_" + tag;
   datetime t1 = iTime(_Symbol, PERIOD_D1, InpDailySR_Lookback);
   datetime t2 = iTime(_Symbol, PERIOD_H4, 0) + PeriodSeconds(PERIOD_H4) * 40;
   color zoneClr = isSupport ? C'220,245,225' : C'250,220,220';
   color lineClr = isSupport ? C'0,160,80'    : C'200,40,40';

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, lo, t2, hi);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      lineClr);
   ObjectSetInteger(0, name, OBJPROP_FILL,       true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

   // Label the zone
   string lblName = DashPfx + "DSRL_" + tag;
   string lblText = isSupport ? "D1 Support" : "D1 Resistance";
   if(tag == "EMA200") lblText = "D1 EMA 200";
   if(ObjectFind(0, lblName) < 0)
      ObjectCreate(0, lblName, OBJ_TEXT, 0, t2, hi);
   ObjectSetString( 0, lblName, OBJPROP_TEXT,      lblText);
   ObjectSetString( 0, lblName, OBJPROP_FONT,      "Arial Bold");
   ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE,  8);
   ObjectSetInteger(0, lblName, OBJPROP_COLOR,     lineClr);
   ObjectSetInteger(0, lblName, OBJPROP_BACK,      false);
   ChartRedraw();
}

//==========================================================
//  UTILITIES
//==========================================================
double CalcLotSize(double slDist)
{
   if(!InpAutoLot) return InpLotSize;
   double bal  = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk = bal * InpRiskPercent / 100.0;
   double tv   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts<=0||tv<=0||slDist<=0) return InpLotSize;
   double lots = risk / ((slDist/ts)*tv);
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots/step)*step;
   return MathMax(minL, MathMin(maxL, lots));
}

int CountMyTrades()
{
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!PosInfo.SelectByIndex(i)) continue;
      if(PosInfo.Symbol()==_Symbol && PosInfo.Magic()==212155) c++;
   }
   return c;
}

bool SpreadOK()
{ return ((ask-bid)/_Point <= InpMaxSpread); }

void ClearManualSignal()
{
   PendingManualSig  = SIG_NONE;
   PendingEntryPrice = 0;
   PendingSL         = 0;
   PendingTP         = 0;
   PendingTP1        = 0;
   PendingLots       = 0;
   PendingReason     = "";
   PartialDone       = false;
   HideManualButtons();
}

void FireAlert(string reason, ENUM_SIGNAL sig)
{
   string dir = (sig==SIG_BUY) ? "BUY" : "SELL";
   string msg = EaName+": "+dir+" Setup — "+reason+" on "+_Symbol;
   if(InpAlertScreen) Alert(msg);
   if(InpAlertEmail)  SendMail(EaName+" Signal", msg);
   if(InpAlertPush)   SendNotification(msg);
   Print(msg);
}

string TrendStr(ENUM_TREND t)
{ return t==TREND_UP?"▲ BULL":t==TREND_DOWN?"▼ BEAR":"— FLAT"; }
color TrendCol(ENUM_TREND t)
{ return t==TREND_UP?C'0,180,100':t==TREND_DOWN?C'210,50,50':C'100,110,135'; }

string ExecModeStr()
{
   if(InpExecMode==EXEC_PENDING) return "PENDING ORDERS";
   if(InpExecMode==EXEC_MANUAL)  return "MANUAL";
   return "HYBRID";
}

//==========================================================
//  DASHBOARD
//==========================================================
void CreateDashboard()
{
   DeleteDashboard();
   int x=InpDashX, y=InpDashY, w=265, h=595;

   Rect(DashPfx+"BG",   x,    y,     w,  h,  C'255,255,255', 245);
   Rect(DashPfx+"BT",   x,    y,     w,  3,  C'30,140,80',   255);
   Rect(DashPfx+"BB",   x,    y+h-3, w,  3,  C'30,140,80',   255);
   Rect(DashPfx+"BL",   x,    y,     3,  h,  C'30,140,80',   255);
   Rect(DashPfx+"BR",   x+w-3,y,     3,  h,  C'30,140,80',   255);

   Lbl(DashPfx+"TITLE", x+10,y+8,  "⟳ SOC SWING EA PRO",    "Arial Bold",10,C'20,120,65');
   Lbl(DashPfx+"SUB",   x+10,y+26, _Symbol+"  |  "+EaVer,    "Arial",     8, C'100,110,130');

   Sep(DashPfx+"S0",x,y+42,w);

   // Mode
   Hdr(DashPfx+"HD0",x,y+49,"EXECUTION MODE");
   Row(DashPfx+"MODE",x,y+63,"Mode:",ExecModeStr());
   Row(DashPfx+"MSTRA",x,y+79,"Strategy:","S1+S2 Combined");

   Sep(DashPfx+"S1",x,y+95,w);

   // Direction
   Hdr(DashPfx+"HD1",x,y+102,"DIRECTION  (4H Primary | 1H Confirm)");
   Row(DashPfx+"RH4",x,y+116,"4H  Trend:","---");
   Row(DashPfx+"RH1",x,y+132,"1H  Trend:","---");
   Row(DashPfx+"RCF",x,y+148,"Confluence:","---");

   Sep(DashPfx+"S1B",x,y+164,w);

   // Daily S&R
   Hdr(DashPfx+"HD1B",x,y+171,"DAILY S&R");
   Row(DashPfx+"DSU",x,y+185,"D1 Support:","---");
   Row(DashPfx+"DRS",x,y+201,"D1 Resist:","---");
   Row(DashPfx+"DEM",x,y+217,"D1 EMA200:","---");
   Row(DashPfx+"DNR",x,y+233,"Near Zone:","---");

   Sep(DashPfx+"S2",x,y+180,w);

   // EMA Values 4H
   Hdr(DashPfx+"HD2",x,y+267,"EMA VALUES  (4H)");
   Row(DashPfx+"E21", x,y+201,"EMA  21:","---");
   Row(DashPfx+"E55", x,y+217,"EMA  55:","---");
   Row(DashPfx+"E200",x,y+313,"EMA 200:","---");

   Sep(DashPfx+"S3",x,y+329,w);

   // Signal
   Hdr(DashPfx+"HD3",x,y+336,"ACTIVE SIGNAL");
   Row(DashPfx+"SIG", x,y+270,"Signal:","SCANNING");
   Row(DashPfx+"SRAT",x,y+366,"Reason:","---");
   Row(DashPfx+"SCON",x,y+382,"1H Confirm:","---");
   Row(DashPfx+"SORD",x,y+398,"Order Type:","---");

   Sep(DashPfx+"S4",x,y+414,w);

   // Market
   Hdr(DashPfx+"HD4",x,y+421,"MARKET");
   Row(DashPfx+"ATR", x,y+355,"ATR (4H):","---");
   Row(DashPfx+"SPR", x,y+371,"Spread:","---");

   Sep(DashPfx+"S5",x,y+467,w);

   // Account
   Hdr(DashPfx+"HD5",x,y+474,"ACCOUNT");
   Row(DashPfx+"OPN", x,y+408,"Open Trades:","0");
   Row(DashPfx+"BAL", x,y+424,"Balance:","---");
   Row(DashPfx+"EQT", x,y+440,"Equity:","---");
   Row(DashPfx+"PNL", x,y+456,"Open P/L:","---");
   Row(DashPfx+"PORD",x,y+552,"Pending Orders:","0");

   ChartRedraw();
}

void UpdateDashboard()
{
   if(!InpShowDash) return;
   if(ArraySize(emaFast_H4)<2) return;

   int    digs  = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double atr   = (ArraySize(atr_H4)>1) ? atr_H4[1] : 0;
   double spread= SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*_Point;

   ENUM_TREND tH4 = GetTrend(emaFast_H4[1],emaMid_H4[1],emaSlow_H4[1]);
   ENUM_TREND tH1 = GetTrend(emaFast_H1[1],emaMid_H1[1],emaSlow_H1[1]);

   bool f4H  = !InpUse4HFilter || tH4 != TREND_NONE;
   bool f1H  = !InpUse1HFilter || (tH1 != TREND_NONE && tH1 == tH4);
   bool conf = f4H && f1H && tH4 != TREND_NONE;

   UpdV(DashPfx+"RH4", TrendStr(tH4), TrendCol(tH4));
   UpdV(DashPfx+"RH1", InpUse1HFilter?TrendStr(tH1):"DISABLED",
                        InpUse1HFilter?TrendCol(tH1):C'160,165,180');
   UpdV(DashPfx+"RCF",
        conf?"✓  4H + 1H ALIGNED":"✗  CONFLICT",
        conf?C'0,180,100':C'210,70,50');

   // Daily S&R rows
   int digs2 = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   UpdV(DashPfx+"DSU",
        DailySR_Support > 0 ? DoubleToString(DailySR_Support, digs2) : "Scanning...",
        C'0,150,80');
   UpdV(DashPfx+"DRS",
        DailySR_Resist  > 0 ? DoubleToString(DailySR_Resist,  digs2) : "Scanning...",
        C'190,40,40');
   UpdV(DashPfx+"DEM",
        DailyEMA200 > 0 ? DoubleToString(DailyEMA200, digs2) : "---",
        C'150,100,0');
   UpdV(DashPfx+"DNR",
        NearDailySR ? "✓ YES — Zone Active" : "No",
        NearDailySR ? C'0,150,80' : clrBlack);

   UpdV(DashPfx+"E21",  DoubleToString(emaFast_H4[1],digs), C'20,120,65');
   UpdV(DashPfx+"E55",  DoubleToString(emaMid_H4[1], digs), C'200,130,0');
   UpdV(DashPfx+"E200", DoubleToString(emaSlow_H4[1],digs), C'190,40,40');

   // Signal status
   string sig="SCANNING...", rat="---", con="---", ord="---";
   color  sigC=C'100,110,135';

   if(PendingManualSig != SIG_NONE)
   {
      sig  = (PendingManualSig==SIG_BUY)?"▲  BUY  SETUP":"▼  SELL SETUP";
      sigC = (PendingManualSig==SIG_BUY)?C'0,180,100':C'210,50,50';
      rat  = PendingReason;
      con  = "Awaiting 1H close";
      ord  = (InpExecMode==EXEC_PENDING)?"Limit/Stop placed":
             (InpExecMode==EXEC_MANUAL) ?"Click button below":"Pending + Button";
   }
   else if(!conf) { sig="NO CONFLUENCE"; sigC=C'180,100,35'; }

   UpdV(DashPfx+"SIG",  sig,  sigC);
   UpdV(DashPfx+"SRAT", rat,  C'60,70,90');
   UpdV(DashPfx+"SCON", con,  C'60,70,90');
   UpdV(DashPfx+"SORD", ord,  C'60,70,90');

   // Market
   UpdV(DashPfx+"ATR", DoubleToString(atr,   digs), clrBlack);
   UpdV(DashPfx+"SPR", DoubleToString(spread,digs),
        spread > atr*0.1 ? C'200,80,30' : C'0,160,90');

   // Account
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double eq =AccountInfoDouble(ACCOUNT_EQUITY);
   double pnl=eq-bal;
   int    trd=CountMyTrades();

   // Count pending orders
   int pendingCnt=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(OrderSelect(t) && OrderGetString(ORDER_SYMBOL)==_Symbol &&
         OrderGetInteger(ORDER_MAGIC)==212155) pendingCnt++;
   }

   UpdV(DashPfx+"OPN",  IntegerToString(trd)+" / "+IntegerToString(InpMaxTrades),
        trd>0?C'20,120,200':clrBlack);
   UpdV(DashPfx+"BAL",  DoubleToString(bal,2), clrBlack);
   UpdV(DashPfx+"EQT",  DoubleToString(eq, 2), clrBlack);
   UpdV(DashPfx+"PNL",  (pnl>=0?"+":"")+DoubleToString(pnl,2),
        pnl>=0?C'0,160,90':C'200,40,40');
   UpdV(DashPfx+"PORD", IntegerToString(pendingCnt),
        pendingCnt>0?C'200,130,0':clrBlack);

   ChartRedraw();
}

//==========================================================
//  MANUAL EXECUTION BUTTONS
//==========================================================
void ShowManualButtons(ENUM_SIGNAL sig)
{
   int x=InpDashX, y=InpDashY+515, w=265;

   Rect(DashPfx+"BTNBG", x, y, w, 70, C'240,243,248', 255);
   Lbl(DashPfx+"BTNHDR",x+10,y+6,"MANUAL EXECUTION","Arial Bold",8,C'60,70,90');

   if(sig==SIG_BUY || sig==SIG_NONE)
   {
      // BUY button
      Rect(BtnBuy,  x+8,  y+22, 72, 36, C'0,160,90',  255);
      Lbl(BtnBuy+"_T", x+20, y+33, "▲  BUY", "Arial Bold", 9, clrWhite);
   }
   if(sig==SIG_SELL || sig==SIG_NONE)
   {
      // SELL button
      Rect(BtnSell, x+90, y+22, 72, 36, C'200,40,40', 255);
      Lbl(BtnSell+"_T", x+100,y+33, "▼  SELL","Arial Bold", 9, clrWhite);
   }
   // CANCEL button
   Rect(BtnCancel,    x+172,y+22, 82, 36, C'140,145,160',255);
   Lbl(BtnCancel+"_T",x+182,y+33,"✕  CANCEL","Arial Bold",8,clrWhite);

   // Make buttons clickable
   ObjectSetInteger(0, BtnBuy,    OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, BtnSell,   OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, BtnCancel, OBJPROP_SELECTABLE, true);

   ChartRedraw();
}

void HideManualButtons()
{
   ObjectsDeleteAll(0, DashPfx+"BTN");
   ObjectDelete(0, BtnBuy);    ObjectDelete(0, BtnBuy+"_T");
   ObjectDelete(0, BtnSell);   ObjectDelete(0, BtnSell+"_T");
   ObjectDelete(0, BtnCancel); ObjectDelete(0, BtnCancel+"_T");
   ObjectDelete(0, DashPfx+"BTNBG");
   ObjectDelete(0, DashPfx+"BTNHDR");
   ChartRedraw();
}

void UpdateConfirmationStatus(bool confirmed, bool partial=false)
{
   string txt  = confirmed ? "✓ EMA + CANDLE OK" :
                 partial   ? "◑ EMA OK, candle pending" :
                             "⏳ Awaiting 1H align...";
   color  clr  = confirmed ? C'0,180,100' :
                 partial   ? C'180,140,20' :
                             C'160,80,30';
   UpdV(DashPfx+"SCON", txt, clr);
}

//==========================================================
//  DASHBOARD DRAW HELPERS
//==========================================================
void Sep(string n,int x,int y,int w)
{ Rect(n,x+5,y,w-10,1,C'210,215,225',255); }

void Hdr(string n,int x,int y,string txt)
{ Lbl(n,x+10,y,txt,"Arial Bold",8,C'100,110,135'); }

void Row(string pfx,int x,int y,string label,string val)
{
   Lbl(pfx+"_L",x+10, y,label,"Arial",    8,C'60,70,90');
   Lbl(pfx+"_V",x+130,y,val,  "Arial Bold",8,clrBlack);
}

void UpdV(string pfx,string txt,color clr)
{
   string n=pfx+"_V";
   if(ObjectFind(0,n)>=0)
   { ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr); }
}

void DeleteDashboard()
{
   ObjectsDeleteAll(0,DashPfx);
   ChartRedraw();
}

void Rect(string name,int x,int y,int w,int h,color clr,uchar alpha)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

void Lbl(string name,int x,int y,string text,string font,int size,color clr)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString( 0,name,OBJPROP_TEXT,text);
   ObjectSetString( 0,name,OBJPROP_FONT,font);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
}
//+------------------------------------------------------------------+
