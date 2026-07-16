//+------------------------------------------------------------------+
//|                     SOC Scalp EA Pro                             |
//|       EMA 20/50/200 Confluence | S&R | Pullback | Breakout       |
//|       1H + 15M Direction | 5M Entry | All Instruments            |
//|                    Broker: Exness MT5                            |
//+------------------------------------------------------------------+
#property copyright "Sons-Of-Christ"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade        Trade;
CPositionInfo PosInfo;

//==========================================================
//  INPUTS
//==========================================================

input group "=== RISK MANAGEMENT ==="
input bool   InpAutoLot        = true;      // Auto lot (% risk) or fixed
input double InpLotSize        = 0.02;      // Fixed lot size (if AutoLot=false)
input double InpRiskPercent    = 1.0;       // Risk % per trade (if AutoLot=true)
input int    InpMaxTrades      = 2;         // Max open trades per symbol
input int    InpMaxSpread      = 1500;      // Max spread in points

input group "=== EMA SETTINGS ==="
input int    InpEMA_Fast       = 20;        // Fast EMA
input int    InpEMA_Mid        = 50;        // Mid EMA
input int    InpEMA_Slow       = 200;       // Slow EMA

input group "=== ATR / SL / TP ==="
input int    InpATR_Period     = 14;        // ATR period (5M)
input double InpSL_ATR_Multi   = 1.5;       // SL = ATR x multiplier
input double InpTP_ATR_Multi   = 3.0;       // TP = ATR x multiplier
input int    InpFallbackSL     = 500;       // Fallback SL points (if ATR unavailable)
input int    InpFallbackTP     = 1000;      // Fallback TP points

input group "=== ENTRY SETTINGS ==="
input bool   InpUsePullback    = true;      // Pullback entries (EMA20 tag & recover)
input bool   InpUseBreakout    = true;      // Breakout entries (swing high/low break)
input bool   InpUseSR          = true;      // S&R / Supply-Demand zone entries
input int    InpSR_LookbackBars= 20;        // Bars to detect S&R swing points
input double InpSR_ZonePct     = 0.003;     // S&R zone width as % of price
input int    InpPullbackBars   = 3;         // Swing lookback for breakout detection

input group "=== HTF FILTERS ==="
input bool   InpUse1HFilter    = true;      // 1H EMA confluence filter
input bool   InpUse15MFilter   = true;      // 15M EMA confluence filter

input group "=== TRADE MANAGEMENT ==="
input bool   InpUseBreakEven   = true;      // Move SL to break-even
input double InpBreakEvenAt    = 1.0;       // Trigger BE at X * SL distance in profit
input bool   InpUseTrailing    = true;      // ATR trailing stop
input double InpTrailATRMulti  = 1.0;       // Trail = ATR x multiplier
input int    InpTrailStart     = 500;       // Min profit points before trailing starts
input int    InpCooldownMins   = 30;        // Cooldown after max trades hit (minutes)

input group "=== SESSION FILTER ==="
input bool   InpUseSession     = true;      // Enable session filter
// Sessions are fixed to SAST (GMT+2): Asian, London, NY Morning, NY Afternoon

input group "=== DASHBOARD ==="
input bool   InpShowDash       = true;      // Show dashboard
input int    InpDashX          = 15;        // Dashboard X
input int    InpDashY          = 30;        // Dashboard Y

//==========================================================
//  GLOBALS
//==========================================================

// Indicator handles — 5M
int hFast5M, hMid5M, hSlow5M, hATR5M;
// Indicator handles — 15M
int hFast15M, hMid15M, hSlow15M;
// Indicator handles — 1H
int hFast1H, hMid1H, hSlow1H;

// Buffers
double emaFast5M[], emaMid5M[], emaSlow5M[];
double emaFast15M[], emaMid15M[], emaSlow15M[];
double emaFast1H[],  emaMid1H[],  emaSlow1H[];
double atr5M[];

datetime LastBar5M     = 0;
datetime CooldownStart = 0;
string   DashPfx       = "SOC_";
string   EaName        = "SOC Scalp EA Pro";
string   EaVer         = "v3.00";

double   ask, bid;

enum ENUM_TREND { TREND_UP, TREND_DOWN, TREND_NONE };

//==========================================================
//  INIT
//==========================================================
int OnInit()
{
   Trade.SetExpertMagicNumber(303030);
   Trade.SetDeviationInPoints(30);
   Trade.SetTypeFilling(ORDER_FILLING_IOC);

   hFast5M  = iMA(_Symbol, PERIOD_M5,  InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hMid5M   = iMA(_Symbol, PERIOD_M5,  InpEMA_Mid,  0, MODE_EMA, PRICE_CLOSE);
   hSlow5M  = iMA(_Symbol, PERIOD_M5,  InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   hFast15M = iMA(_Symbol, PERIOD_M15, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hMid15M  = iMA(_Symbol, PERIOD_M15, InpEMA_Mid,  0, MODE_EMA, PRICE_CLOSE);
   hSlow15M = iMA(_Symbol, PERIOD_M15, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   hFast1H  = iMA(_Symbol, PERIOD_H1,  InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hMid1H   = iMA(_Symbol, PERIOD_H1,  InpEMA_Mid,  0, MODE_EMA, PRICE_CLOSE);
   hSlow1H  = iMA(_Symbol, PERIOD_H1,  InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   hATR5M   = iATR(_Symbol, PERIOD_M5, InpATR_Period);

   if(hFast5M  == INVALID_HANDLE || hMid5M  == INVALID_HANDLE || hSlow5M  == INVALID_HANDLE ||
      hFast15M == INVALID_HANDLE || hMid15M == INVALID_HANDLE || hSlow15M == INVALID_HANDLE ||
      hFast1H  == INVALID_HANDLE || hMid1H  == INVALID_HANDLE || hSlow1H  == INVALID_HANDLE ||
      hATR5M   == INVALID_HANDLE)
   {
      Print("ERROR: Indicator handle creation failed.");
      return INIT_FAILED;
   }

   ArraySetAsSeries(emaFast5M,  true); ArraySetAsSeries(emaMid5M,  true); ArraySetAsSeries(emaSlow5M,  true);
   ArraySetAsSeries(emaFast15M, true); ArraySetAsSeries(emaMid15M, true); ArraySetAsSeries(emaSlow15M, true);
   ArraySetAsSeries(emaFast1H,  true); ArraySetAsSeries(emaMid1H,  true); ArraySetAsSeries(emaSlow1H,  true);
   ArraySetAsSeries(atr5M,      true);

   if(InpShowDash) CreateDashboard();
   Print(EaName, " ", EaVer, " initialized — ", _Symbol);
   return INIT_SUCCEEDED;
}

//==========================================================
//  DEINIT
//==========================================================
void OnDeinit(const int reason)
{
   int handles[] = {hFast5M,hMid5M,hSlow5M,hFast15M,hMid15M,hSlow15M,hFast1H,hMid1H,hSlow1H,hATR5M};
   for(int i = 0; i < ArraySize(handles); i++) IndicatorRelease(handles[i]);
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
   if(InpShowDash) UpdateDashboard();

   // --- Pre-trade guards ---
   if(InpUseSession && !IsSessionActive()) return;
   if(!SpreadOK()) return;

   int trades = CountMyTrades();
   if(trades >= InpMaxTrades)
   {
      if(CooldownStart == 0) CooldownStart = TimeCurrent();
      return;
   }
   if(CooldownActive()) return;

   // --- New 5M bar gate ---
   datetime curBar = iTime(_Symbol, PERIOD_M5, 0);
   if(curBar == LastBar5M) return;
   LastBar5M = curBar;

   if(!RefreshData()) return;

   // --- Trend filters ---
   ENUM_TREND t1H  = GetTrend(emaFast1H[1],  emaMid1H[1],  emaSlow1H[1]);
   ENUM_TREND t15M = GetTrend(emaFast15M[1], emaMid15M[1], emaSlow15M[1]);
   ENUM_TREND t5M  = GetTrend(emaFast5M[1],  emaMid5M[1],  emaSlow5M[1]);

   if(t5M == TREND_NONE) return;
   if(InpUse1HFilter  && (t1H  == TREND_NONE || t1H  != t5M)) return;
   if(InpUse15MFilter && (t15M == TREND_NONE || t15M != t5M)) return;

   double atr = atr5M[1];
   if(atr <= 0) return;

   // --- Entry evaluation ---
   bool longSig  = false;
   bool shortSig = false;
   string entryReason = "";

   if(t5M == TREND_UP)
   {
      if(InpUsePullback && IsPullbackBuy())
         { longSig = true; entryReason = "Pullback"; }
      else if(InpUseBreakout && IsBreakoutBuy())
         { longSig = true; entryReason = "Breakout"; }
      else if(InpUseSR && IsSR_Buy())
         { longSig = true; entryReason = "S&R Zone"; }
   }
   else if(t5M == TREND_DOWN)
   {
      if(InpUsePullback && IsPullbackSell())
         { shortSig = true; entryReason = "Pullback"; }
      else if(InpUseBreakout && IsBreakoutSell())
         { shortSig = true; entryReason = "Breakout"; }
      else if(InpUseSR && IsSR_Sell())
         { shortSig = true; entryReason = "S&R Zone"; }
   }

   if(longSig  && !HedgeBlocked(POSITION_TYPE_BUY))
      OpenTrade(ORDER_TYPE_BUY,  atr, entryReason);
   if(shortSig && !HedgeBlocked(POSITION_TYPE_SELL))
      OpenTrade(ORDER_TYPE_SELL, atr, entryReason);
}

//==========================================================
//  DATA REFRESH
//==========================================================
bool RefreshData()
{
   int b = InpEMA_Slow + InpSR_LookbackBars + 5;
   if(CopyBuffer(hFast5M,  0, 0, b, emaFast5M)  <= 0) return false;
   if(CopyBuffer(hMid5M,   0, 0, b, emaMid5M)   <= 0) return false;
   if(CopyBuffer(hSlow5M,  0, 0, b, emaSlow5M)  <= 0) return false;
   if(CopyBuffer(hFast15M, 0, 0, b, emaFast15M) <= 0) return false;
   if(CopyBuffer(hMid15M,  0, 0, b, emaMid15M)  <= 0) return false;
   if(CopyBuffer(hSlow15M, 0, 0, b, emaSlow15M) <= 0) return false;
   if(CopyBuffer(hFast1H,  0, 0, b, emaFast1H)  <= 0) return false;
   if(CopyBuffer(hMid1H,   0, 0, b, emaMid1H)   <= 0) return false;
   if(CopyBuffer(hSlow1H,  0, 0, b, emaSlow1H)  <= 0) return false;
   if(CopyBuffer(hATR5M,   0, 0, 5, atr5M)      <= 0) return false;
   return true;
}

//==========================================================
//  TREND LOGIC  (same rule on all 3 TFs)
//  BUY:  EMA20 > EMA200  AND  EMA50 > EMA200
//  SELL: EMA20 < EMA200  AND  EMA50 < EMA200
//==========================================================
ENUM_TREND GetTrend(double fast, double mid, double slow)
{
   if(fast > slow && mid > slow) return TREND_UP;
   if(fast < slow && mid < slow) return TREND_DOWN;
   return TREND_NONE;
}

//==========================================================
//  ENTRY CONDITIONS
//==========================================================

// --- Pullback Buy: price tagged EMA20, recovered above it ---
bool IsPullbackBuy()
{
   double c1 = iClose(_Symbol, PERIOD_M5, 1);
   double c2 = iClose(_Symbol, PERIOD_M5, 2);
   double e1 = emaFast5M[1], e2 = emaFast5M[2];
   double atr = atr5M[1];
   return (MathAbs(c2 - e2) < atr * 0.5) && (c1 > e1);
}

// --- Pullback Sell: price tagged EMA20, recovered below it ---
bool IsPullbackSell()
{
   double c1 = iClose(_Symbol, PERIOD_M5, 1);
   double c2 = iClose(_Symbol, PERIOD_M5, 2);
   double e1 = emaFast5M[1], e2 = emaFast5M[2];
   double atr = atr5M[1];
   return (MathAbs(c2 - e2) < atr * 0.5) && (c1 < e1);
}

// --- Breakout Buy: 5M close above recent swing high ---
bool IsBreakoutBuy()
{
   double c1  = iClose(_Symbol, PERIOD_M5, 1);
   double buf = atr5M[1] * 0.1;
   double swHigh = 0;
   for(int i = 2; i <= InpPullbackBars + 1; i++)
      swHigh = MathMax(swHigh, iHigh(_Symbol, PERIOD_M5, i));
   return (c1 > swHigh + buf);
}

// --- Breakout Sell: 5M close below recent swing low ---
bool IsBreakoutSell()
{
   double c1  = iClose(_Symbol, PERIOD_M5, 1);
   double buf = atr5M[1] * 0.1;
   double swLow = DBL_MAX;
   for(int i = 2; i <= InpPullbackBars + 1; i++)
      swLow = MathMin(swLow, iLow(_Symbol, PERIOD_M5, i));
   return (c1 < swLow - buf);
}

//==========================================================
//  S&R / SUPPLY-DEMAND ZONE ENTRIES
//  Detects swing highs (resistance) and swing lows (support)
//  on the 5M chart over the last InpSR_LookbackBars bars.
//  BUY:  price bounces up from support zone
//  SELL: price rejects down from resistance zone
//==========================================================
bool IsSR_Buy()
{
   double zoneW = ask * InpSR_ZonePct;
   // Find swing lows (support)
   for(int i = 2; i < InpSR_LookbackBars; i++)
   {
      double low = iLow(_Symbol, PERIOD_M5, i);
      // Is this bar a swing low? (lower than neighbors)
      if(low < iLow(_Symbol, PERIOD_M5, i-1) && low < iLow(_Symbol, PERIOD_M5, i+1))
      {
         // Is current ask near this support zone?
         if(ask >= low - zoneW && ask <= low + zoneW)
         {
            // Confirmation: last closed bar is bullish and closed above zone
            double c1 = iClose(_Symbol, PERIOD_M5, 1);
            double o1 = iOpen (_Symbol, PERIOD_M5, 1);
            if(c1 > o1 && c1 > low) return true;
         }
      }
   }
   return false;
}

bool IsSR_Sell()
{
   double zoneW = bid * InpSR_ZonePct;
   // Find swing highs (resistance)
   for(int i = 2; i < InpSR_LookbackBars; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M5, i);
      if(high > iHigh(_Symbol, PERIOD_M5, i-1) && high > iHigh(_Symbol, PERIOD_M5, i+1))
      {
         if(bid >= high - zoneW && bid <= high + zoneW)
         {
            double c1 = iClose(_Symbol, PERIOD_M5, 1);
            double o1 = iOpen (_Symbol, PERIOD_M5, 1);
            if(c1 < o1 && c1 < high) return true;
         }
      }
   }
   return false;
}

//==========================================================
//  LOT SIZE CALCULATION
//==========================================================
double CalcLotSize(double slDist)
{
   if(!InpAutoLot) return InpLotSize;
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt    = balance * InpRiskPercent / 100.0;
   double tickVal    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz <= 0 || tickVal <= 0 || slDist <= 0) return InpLotSize;
   double lots       = riskAmt / ((slDist / tickSz) * tickVal);
   double minL       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / step) * step;
   return MathMax(minL, MathMin(maxL, lots));
}

//==========================================================
//  OPEN TRADE
//==========================================================
void OpenTrade(ENUM_ORDER_TYPE type, double atr, string reason)
{
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDist = (atr > 0) ? atr * InpSL_ATR_Multi : InpFallbackSL * point;
   double tpDist = (atr > 0) ? atr * InpTP_ATR_Multi : InpFallbackTP * point;

   double entry, sl, tp;
   if(type == ORDER_TYPE_BUY)
   {
      entry = ask;
      sl    = NormalizeDouble(entry - slDist, digits);
      tp    = NormalizeDouble(entry + tpDist, digits);
   }
   else
   {
      entry = bid;
      sl    = NormalizeDouble(entry + slDist, digits);
      tp    = NormalizeDouble(entry - tpDist, digits);
   }

   double lots = CalcLotSize(slDist);
   if(lots <= 0) { Print("CalcLotSize returned 0 — skipping."); return; }

   string comment = EaName + " | " + (type == ORDER_TYPE_BUY ? "BUY" : "SELL") + " | " + reason;
   bool ok = (type == ORDER_TYPE_BUY)
             ? Trade.Buy(lots,  _Symbol, entry, sl, tp, comment)
             : Trade.Sell(lots, _Symbol, entry, sl, tp, comment);

   if(ok)
      Print("Trade opened: ", (type==ORDER_TYPE_BUY?"BUY":"SELL"),
            " | Lots=",lots," SL=",sl," TP=",tp," | ",reason);
   else
      Print("Trade FAILED: ", GetLastError(), " | RetCode=", Trade.ResultRetcode());
}

//==========================================================
//  MANAGE OPEN TRADES — Break-Even + Trailing
//==========================================================
void ManageOpenTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosInfo.SelectByIndex(i)) continue;
      if(PosInfo.Symbol() != _Symbol || PosInfo.Magic() != 303030) continue;

      double open   = PosInfo.PriceOpen();
      double curSL  = PosInfo.StopLoss();
      double curTP  = PosInfo.TakeProfit();
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double atr    = (ArraySize(atr5M) > 1) ? atr5M[1] : 0;

      if(PosInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double slDist  = open - curSL;
         double profit  = (bid - open) / point;

         // Break-even
         if(InpUseBreakEven && curSL < open && slDist > 0)
         {
            if(bid >= open + slDist * InpBreakEvenAt)
            {
               double newSL = NormalizeDouble(open + point * 2, digits);
               if(newSL > curSL) Trade.PositionModify(PosInfo.Ticket(), newSL, curTP);
            }
         }
         // Trailing
         if(InpUseTrailing && atr > 0 && profit >= InpTrailStart)
         {
            double trailSL = NormalizeDouble(bid - atr * InpTrailATRMulti, digits);
            if(trailSL > curSL && trailSL < bid)
               Trade.PositionModify(PosInfo.Ticket(), trailSL, curTP);
         }
      }
      else if(PosInfo.PositionType() == POSITION_TYPE_SELL)
      {
         double slDist  = curSL - open;
         double profit  = (open - ask) / point;

         if(InpUseBreakEven && curSL > open && slDist > 0)
         {
            if(ask <= open - slDist * InpBreakEvenAt)
            {
               double newSL = NormalizeDouble(open - point * 2, digits);
               if(newSL < curSL) Trade.PositionModify(PosInfo.Ticket(), newSL, curTP);
            }
         }
         if(InpUseTrailing && atr > 0 && profit >= InpTrailStart)
         {
            double trailSL = NormalizeDouble(ask + atr * InpTrailATRMulti, digits);
            if(trailSL < curSL && trailSL > ask)
               Trade.PositionModify(PosInfo.Ticket(), trailSL, curTP);
         }
      }
   }
}

//==========================================================
//  UTILITY FUNCTIONS
//==========================================================
int CountMyTrades()
{
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosInfo.SelectByIndex(i)) continue;
      if(PosInfo.Symbol() == _Symbol && PosInfo.Magic() == 303030) c++;
   }
   return c;
}

bool SpreadOK()
{
   return ((ask - bid) / _Point <= InpMaxSpread);
}

bool HedgeBlocked(long newType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_TYPE)  != newType)
         return true;
   }
   return false;
}

bool CooldownActive()
{
   if(CooldownStart == 0) return false;
   if((int)(TimeCurrent() - CooldownStart) >= InpCooldownMins * 60)
   {
      CooldownStart = 0;
      return false;
   }
   return true;
}

// SAST Sessions (GMT+2)
bool IsSessionActive()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   int h = t.hour;
   return (h >= 2  && h < 4)  ||   // Asian
          (h >= 9  && h < 11) ||   // London
          (h >= 14 && h < 17) ||   // NY Morning
          (h >= 20 && h < 22);     // NY Afternoon
}

string ActiveSession()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   int h = t.hour;
   if(h >= 2  && h < 4)  return "Asian";
   if(h >= 9  && h < 11) return "London";
   if(h >= 14 && h < 17) return "NY Morning";
   if(h >= 20 && h < 22) return "NY Afternoon";
   return "OFF";
}

// Helpers for display
string TrendStr(ENUM_TREND t)
{
   if(t == TREND_UP)   return "BULLISH";
   if(t == TREND_DOWN) return "BEARISH";
   return "NEUTRAL";
}
color TrendCol(ENUM_TREND t)
{
   if(t == TREND_UP)   return C'0,215,130';
   if(t == TREND_DOWN) return C'255,70,70';
   return C'120,125,145';
}

//==========================================================
//  DASHBOARD
//==========================================================
void CreateDashboard()
{
   DeleteDashboard();
   int x = InpDashX, y = InpDashY;
   int w = 255, h = 430;

   // Background + accent borders
   CreateRect(DashPfx+"BG",  x,   y,     w,   h,   C'255,255,255',  230);
   CreateRect(DashPfx+"BT",  x,   y,     w,   3,   C'0,175,120', 255);
   CreateRect(DashPfx+"BB",  x,   y+h-3, w,   3,   C'0,175,120', 255);
   CreateRect(DashPfx+"BL",  x,   y,     3,   h,   C'0,175,120', 255);
   CreateRect(DashPfx+"BR",  x+w-3,y,    3,   h,   C'0,175,120', 255);

   // Header
   CreateLabel(DashPfx+"TITLE",  x+10, y+8,  "⚡ SOC SCALP EA PRO",         "Arial Bold", 10, C'0,210,145');
   CreateLabel(DashPfx+"SUB",    x+10, y+26, _Symbol + "  |  " + EaVer,     "Arial",       8, C'100,110,135');

   Sep(DashPfx+"S1", x, y+42, w);

   // Direction
   Hdr(DashPfx+"H1",  x, y+49,  "DIRECTION");
   Row(DashPfx+"1H",  x, y+63,  "1H  Trend:", "---");
   Row(DashPfx+"15M", x, y+79,  "15M Trend:", "---");
   Row(DashPfx+"5M",  x, y+95,  "5M  Trend:", "---");
   Row(DashPfx+"CF",  x, y+111, "Confluence:", "---");

   Sep(DashPfx+"S2", x, y+127, w);

   // Entry
   Hdr(DashPfx+"H2",   x, y+134, "ENTRY");
   Row(DashPfx+"SIG",  x, y+148, "Signal:",   "WAITING");
   Row(DashPfx+"TYPE", x, y+164, "Type:",     "---");

   Sep(DashPfx+"S3", x, y+180, w);

   // EMAs
   Hdr(DashPfx+"H3",    x, y+187, "EMA  5M");
   Row(DashPfx+"E20",   x, y+201, "EMA 20:", "---");
   Row(DashPfx+"E50",   x, y+217, "EMA 50:", "---");
   Row(DashPfx+"E200",  x, y+233, "EMA 200:","---");

   Sep(DashPfx+"S4", x, y+249, w);

   // Market
   Hdr(DashPfx+"H4",   x, y+256, "MARKET");
   Row(DashPfx+"ATR",  x, y+270, "ATR (5M):", "---");
   Row(DashPfx+"SPR",  x, y+286, "Spread:",   "---");
   Row(DashPfx+"SES",  x, y+302, "Session:",  "---");

   Sep(DashPfx+"S5", x, y+318, w);

   // Account
   Hdr(DashPfx+"H5",    x, y+325, "ACCOUNT");
   Row(DashPfx+"OPEN",  x, y+339, "Open Trades:", "0");
   Row(DashPfx+"CD",    x, y+355, "Cooldown:",    "OFF");
   Row(DashPfx+"BAL",   x, y+371, "Balance:",     "---");
   Row(DashPfx+"PNL",   x, y+387, "Open P/L:",    "---");

   ChartRedraw();
}

void UpdateDashboard()
{
   if(!InpShowDash) return;
   if(ArraySize(emaFast5M) < 2) return;

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr    = (ArraySize(atr5M) > 1) ? atr5M[1] : 0;
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

   ENUM_TREND t1H  = GetTrend(emaFast1H[1],  emaMid1H[1],  emaSlow1H[1]);
   ENUM_TREND t15M = GetTrend(emaFast15M[1], emaMid15M[1], emaSlow15M[1]);
   ENUM_TREND t5M  = GetTrend(emaFast5M[1],  emaMid5M[1],  emaSlow5M[1]);

   bool f1H  = !InpUse1HFilter  || (t1H  != TREND_NONE && t1H  == t5M);
   bool f15M = !InpUse15MFilter || (t15M != TREND_NONE && t15M == t5M);
   bool conf = (t5M != TREND_NONE) && f1H && f15M;

   // Direction rows
   string s1H = InpUse1HFilter  ? TrendStr(t1H)  : "DISABLED";
   color  c1H = InpUse1HFilter  ? TrendCol(t1H)  : C'70,80,100';
   string s15 = InpUse15MFilter ? TrendStr(t15M) : "DISABLED";
   color  c15 = InpUse15MFilter ? TrendCol(t15M) : C'70,80,100';

   UpdVal(DashPfx+"1H",  s1H, c1H);
   UpdVal(DashPfx+"15M", s15, c15);
   UpdVal(DashPfx+"5M",  TrendStr(t5M), TrendCol(t5M));
   UpdVal(DashPfx+"CF",
          conf ? "✓  ALL ALIGNED" : "✗  CONFLICT",
          conf ? C'0,215,130' : C'255,110,50');

   // Signal
   string sig = "WAITING"; color sigC = C'170,170,55';
   string sigType = "---";
   bool sessOk = !InpUseSession || IsSessionActive();
   bool spdOk  = SpreadOK();

   if(!sessOk)        { sig = "NO SESSION";  sigC = C'80,90,115'; }
   else if(!spdOk)    { sig = "SPREAD HIGH"; sigC = C'200,100,40'; }
   else if(!conf)     { sig = "NO CONF.";    sigC = C'180,100,40'; }
   else if(CooldownActive()) { sig = "COOLDOWN"; sigC = C'150,120,40'; }
   else if(t5M == TREND_UP)
   {
      bool pb = InpUsePullback && IsPullbackBuy();
      bool bo = InpUseBreakout && IsBreakoutBuy();
      bool sr = InpUseSR      && IsSR_Buy();
      if(pb || bo || sr)
      {
         sig = "▲  BUY  SIGNAL"; sigC = C'0,235,130';
         sigType = pb ? "Pullback" : (bo ? "Breakout" : "S&R Zone");
      }
      else { sig = "▲ BULL SETUP"; sigC = C'0,160,95'; }
   }
   else if(t5M == TREND_DOWN)
   {
      bool pb = InpUsePullback && IsPullbackSell();
      bool bo = InpUseBreakout && IsBreakoutSell();
      bool sr = InpUseSR      && IsSR_Sell();
      if(pb || bo || sr)
      {
         sig = "▼  SELL SIGNAL"; sigC = C'255,70,70';
         sigType = pb ? "Pullback" : (bo ? "Breakout" : "S&R Zone");
      }
      else { sig = "▼ BEAR SETUP"; sigC = C'185,65,65'; }
   }

   UpdVal(DashPfx+"SIG",  sig,     sigC);
   UpdVal(DashPfx+"TYPE", sigType, C'170,175,195');

   // EMAs
   UpdVal(DashPfx+"E20",  DoubleToString(emaFast5M[1], digits), C'65,185,255');
   UpdVal(DashPfx+"E50",  DoubleToString(emaMid5M[1],  digits), C'255,170,40');
   UpdVal(DashPfx+"E200", DoubleToString(emaSlow5M[1], digits), C'255,70,90');

   // Market
   UpdVal(DashPfx+"ATR", DoubleToString(atr,    digits), clrBlack);
   UpdVal(DashPfx+"SPR", DoubleToString(spread, digits),
          spread > atr * 0.3 ? C'255,110,50' : C'0,200,125');
   UpdVal(DashPfx+"SES", ActiveSession(),
          ActiveSession() == "OFF" ? C'80,90,115' : C'0,215,130');

   // Account
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double pnl     = equity - balance;
   int    trades  = CountMyTrades();

   UpdVal(DashPfx+"OPEN", IntegerToString(trades) + " / " + IntegerToString(InpMaxTrades),
          trades > 0 ? C'65,185,255' : clrBlack);
   UpdVal(DashPfx+"CD",
          CooldownActive() ? "ACTIVE" : "OFF",
          CooldownActive() ? C'255,175,40' : C'80,90,115');
   UpdVal(DashPfx+"BAL", DoubleToString(balance, 2), clrBlack);
   UpdVal(DashPfx+"PNL",
          (pnl >= 0 ? "+" : "") + DoubleToString(pnl, 2),
          pnl >= 0 ? C'0,215,130' : C'255,70,70');

   ChartRedraw();
}

//==========================================================
//  DASHBOARD HELPERS
//==========================================================
void Sep(string n, int x, int y, int w)
{ CreateRect(n, x+5, y, w-10, 1, C'210,215,225', 255); }

void Hdr(string n, int x, int y, string txt)
{ CreateLabel(n, x+10, y, txt, "Arial Bold", 8, C'100,110,135'); }

void Row(string pfx, int x, int y, string lbl, string val)
{
   CreateLabel(pfx+"_L", x+10,  y, lbl, "Arial",      8, C'60,65,80');
   CreateLabel(pfx+"_V", x+120, y, val, "Arial Bold",  8, clrBlack);
}

void UpdVal(string pfx, string txt, color clr)
{
   string n = pfx + "_V";
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString( 0, n, OBJPROP_TEXT,  txt);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}

void DeleteDashboard() { ObjectsDeleteAll(0, DashPfx); ChartRedraw(); }

void CreateRect(string name, int x, int y, int w, int h, color clr, uchar alpha)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateLabel(string name, int x, int y, string text, string font, int size, color clr)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetString( 0, name, OBJPROP_TEXT,       text);
   ObjectSetString( 0, name, OBJPROP_FONT,       font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   size);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
}
//+------------------------------------------------------------------+
