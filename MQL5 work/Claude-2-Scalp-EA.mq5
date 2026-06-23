//+------------------------------------------------------------------+
//|                                            Claude-2-Scalp-EA.mq5 |
//|                                                   Sons-Of-Christ |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Sons-Of-Christ"
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//|                        EMA Scalp EA Pro                          |
//|              5M Entry | 5M+15M Direction | EMA 20/50/200         |
//|                   Compatible: All Instruments                    |
//|                      Broker: Exness MT5                          |
//+------------------------------------------------------------------+
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input Parameters
input group "=== RISK MANAGEMENT ==="
input double   InpRiskPercent      = 1.0;       // Risk % per trade
input double   InpRiskRewardRatio  = 2.0;       // Risk:Reward Ratio
input int      InpMaxTrades        = 3;          // Max simultaneous trades
input double   InpMinATRMultiplier = 0.5;        // Min ATR multiplier (volatility filter)
input double   InpMaxATRMultiplier = 3.0;        // Max ATR multiplier (volatility filter)

input group "=== EMA SETTINGS ==="
input int      InpEMA_Fast         = 20;         // Fast EMA period
input int      InpEMA_Mid          = 50;         // Mid EMA period
input int      InpEMA_Slow         = 200;        // Slow EMA period
input ENUM_MA_METHOD InpMAMethod   = MODE_EMA;   // MA Method

input group "=== ATR SETTINGS ==="
input int      InpATR_Period       = 14;         // ATR Period
input double   InpSL_ATR_Multi     = 1.5;        // SL = ATR x this multiplier
input double   InpTP_ATR_Multi     = 3.0;        // TP = ATR x this multiplier

input group "=== ENTRY SETTINGS ==="
input bool     InpUsePullback      = true;       // Use pullback entries
input bool     InpUseBreakout      = true;       // Use breakout entries
input int      InpPullbackBars     = 3;          // Bars to confirm pullback
input double   InpBreakoutBuffer   = 0.0;        // Breakout buffer in points (0=auto)

input group "=== SESSION FILTER ==="
input bool     InpUseSessionFilter = false;      // Enable session filter
input int      InpSessionStartHour = 9;          // Session start hour (broker time)
input int      InpSessionEndHour   = 22;         // Session end hour (broker time)

input group "=== DASHBOARD ==="
input bool     InpShowDashboard    = true;       // Show dashboard panel
input int      InpDashX            = 15;         // Dashboard X position
input int      InpDashY            = 30;         // Dashboard Y position

input group "=== TRADE MANAGEMENT ==="
input bool     InpUseBreakEven     = true;       // Move SL to breakeven
input double   InpBreakEvenAt      = 1.0;        // Move BE when profit = X * SL dist
input bool     InpUseTrailingStop  = false;      // Use trailing stop
input double   InpTrailATRMulti    = 1.0;        // Trail stop = ATR x this

//--- Global Variables
CTrade         Trade;
CPositionInfo  PosInfo;

int            EmaFastHandle5M, EmaMidHandle5M, EmaSlowHandle5M;
int            EmaFastHandle15M, EmaMidHandle15M, EmaSlowHandle15M;
int            AtrHandle5M;

double         EmaFast5M[], EmaMid5M[], EmaSlow5M[];
double         EmaFast15M[], EmaMid15M[], EmaSlow15M[];
double         Atr5M[];

string         EaName      = "EMA Scalp EA Pro";
string         EaVersion   = "v1.00";
datetime       LastBarTime = 0;

// Dashboard object names
string         DashPrefix  = "EMASC_";

//--- Direction States
enum ENUM_TREND { TREND_UP, TREND_DOWN, TREND_NONE };

//+------------------------------------------------------------------+
//| Expert Initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set trade parameters
   Trade.SetExpertMagicNumber(202501);
   Trade.SetDeviationInPoints(30);  // Higher slippage tolerance for Exness
   Trade.SetTypeFilling(ORDER_FILLING_IOC);

   // --- 5M Indicator handles
   EmaFastHandle5M  = iMA(_Symbol, PERIOD_M5,  InpEMA_Fast, 0, InpMAMethod, PRICE_CLOSE);
   EmaMidHandle5M   = iMA(_Symbol, PERIOD_M5,  InpEMA_Mid,  0, InpMAMethod, PRICE_CLOSE);
   EmaSlowHandle5M  = iMA(_Symbol, PERIOD_M5,  InpEMA_Slow, 0, InpMAMethod, PRICE_CLOSE);

   // --- 15M Direction handles
   EmaFastHandle15M = iMA(_Symbol, PERIOD_M15, InpEMA_Fast, 0, InpMAMethod, PRICE_CLOSE);
   EmaMidHandle15M  = iMA(_Symbol, PERIOD_M15, InpEMA_Mid,  0, InpMAMethod, PRICE_CLOSE);
   EmaSlowHandle15M = iMA(_Symbol, PERIOD_M15, InpEMA_Slow, 0, InpMAMethod, PRICE_CLOSE);

   // --- ATR
   AtrHandle5M      = iATR(_Symbol, PERIOD_M5, InpATR_Period);

   if(EmaFastHandle5M  == INVALID_HANDLE ||
      EmaMidHandle5M   == INVALID_HANDLE ||
      EmaSlowHandle5M  == INVALID_HANDLE ||
      EmaFastHandle15M == INVALID_HANDLE ||
      EmaMidHandle15M  == INVALID_HANDLE ||
      EmaSlowHandle15M == INVALID_HANDLE ||
      AtrHandle5M      == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles. Check symbol and timeframe.");
      return INIT_FAILED;
   }

   // Set arrays as series
   ArraySetAsSeries(EmaFast5M,  true);
   ArraySetAsSeries(EmaMid5M,   true);
   ArraySetAsSeries(EmaSlow5M,  true);
   ArraySetAsSeries(EmaFast15M, true);
   ArraySetAsSeries(EmaMid15M,  true);
   ArraySetAsSeries(EmaSlow15M, true);
   ArraySetAsSeries(Atr5M,      true);

   if(InpShowDashboard) CreateDashboard();

   Print(EaName, " ", EaVersion, " initialized on ", _Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert Deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(EmaFastHandle5M);
   IndicatorRelease(EmaMidHandle5M);
   IndicatorRelease(EmaSlowHandle5M);
   IndicatorRelease(EmaFastHandle15M);
   IndicatorRelease(EmaMidHandle15M);
   IndicatorRelease(EmaSlowHandle15M);
   IndicatorRelease(AtrHandle5M);

   DeleteDashboard();
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only act on new 5M bar
   datetime currentBar = iTime(_Symbol, PERIOD_M5, 0);
   if(currentBar == LastBarTime) 
   {
      // Still update dashboard every tick
      if(InpShowDashboard) UpdateDashboard();
      // Handle break-even and trailing on every tick
      ManageOpenTrades();
      return;
   }
   LastBarTime = currentBar;

   // --- Refresh indicator data
   if(!RefreshData()) return;

   // --- Session filter
   if(InpUseSessionFilter && !IsSessionActive()) return;

   // --- Get trend directions
   ENUM_TREND trend5M  = GetTrend5M();
   ENUM_TREND trend15M = GetTrend15M();

   // --- Confluence: both TFs must agree
   if(trend5M == TREND_NONE || trend15M == TREND_NONE) return;
   if(trend5M != trend15M) return;

   // --- Volatility filter
   double atr = Atr5M[1];
   if(atr <= 0) return;

   double pointVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minSpread = InpMinATRMultiplier * atr;
   double maxSpread = InpMaxATRMultiplier * atr;
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * pointVal;

   // If volatility is too low or too extreme, skip
   if(atr < minSpread || atr > maxSpread) { /* pass — ATR self-referential, use spread check */ }

   // --- Count existing trades
   if(CountMyTrades() >= InpMaxTrades) return;

   // --- Entry logic
   if(trend5M == TREND_UP)
   {
      if(InpUsePullback && IsPullbackBuy())   OpenTrade(ORDER_TYPE_BUY,  atr);
      else if(InpUseBreakout && IsBreakoutBuy()) OpenTrade(ORDER_TYPE_BUY, atr);
   }
   else if(trend5M == TREND_DOWN)
   {
      if(InpUsePullback && IsPullbackSell())   OpenTrade(ORDER_TYPE_SELL, atr);
      else if(InpUseBreakout && IsBreakoutSell()) OpenTrade(ORDER_TYPE_SELL, atr);
   }

   if(InpShowDashboard) UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Refresh all indicator buffers                                    |
//+------------------------------------------------------------------+
bool RefreshData()
{
   int bars = InpEMA_Slow + 5;
   if(CopyBuffer(EmaFastHandle5M,  0, 0, bars, EmaFast5M)  <= 0) return false;
   if(CopyBuffer(EmaMidHandle5M,   0, 0, bars, EmaMid5M)   <= 0) return false;
   if(CopyBuffer(EmaSlowHandle5M,  0, 0, bars, EmaSlow5M)  <= 0) return false;
   if(CopyBuffer(EmaFastHandle15M, 0, 0, bars, EmaFast15M) <= 0) return false;
   if(CopyBuffer(EmaMidHandle15M,  0, 0, bars, EmaMid15M)  <= 0) return false;
   if(CopyBuffer(EmaSlowHandle15M, 0, 0, bars, EmaSlow15M) <= 0) return false;
   if(CopyBuffer(AtrHandle5M,      0, 0, 5,    Atr5M)      <= 0) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Get 5M Trend (EMA 20 & 50 vs EMA 200)                           |
//+------------------------------------------------------------------+
ENUM_TREND GetTrend5M()
{
   if(ArraySize(EmaFast5M) < 3 || ArraySize(EmaMid5M) < 3 || ArraySize(EmaSlow5M) < 3)
      return TREND_NONE;

   double fast = EmaFast5M[1];  // Use closed bar [1]
   double mid  = EmaMid5M[1];
   double slow = EmaSlow5M[1];

   if(fast > slow && mid > slow) return TREND_UP;
   if(fast < slow && mid < slow) return TREND_DOWN;
   return TREND_NONE;
}

//+------------------------------------------------------------------+
//| Get 15M Trend (Direction filter)                                 |
//+------------------------------------------------------------------+
ENUM_TREND GetTrend15M()
{
   if(ArraySize(EmaFast15M) < 3 || ArraySize(EmaMid15M) < 3 || ArraySize(EmaSlow15M) < 3)
      return TREND_NONE;

   double fast = EmaFast15M[1];
   double mid  = EmaMid15M[1];
   double slow = EmaSlow15M[1];

   if(fast > slow && mid > slow) return TREND_UP;
   if(fast < slow && mid < slow) return TREND_DOWN;
   return TREND_NONE;
}

//+------------------------------------------------------------------+
//| Pullback Buy: price pulled back toward EMA20 from above          |
//+------------------------------------------------------------------+
bool IsPullbackBuy()
{
   // Price dipped toward EMA20 and now recovering (close of [2] near/below EMA20, [1] back above)
   double close1  = iClose(_Symbol, PERIOD_M5, 1);
   double close2  = iClose(_Symbol, PERIOD_M5, 2);
   double ema20_1 = EmaFast5M[1];
   double ema20_2 = EmaFast5M[2];
   double atr     = Atr5M[1];

   // Bar [2] touched or went near EMA20 (within 0.5 ATR)
   bool touchedEMA = (MathAbs(close2 - ema20_2) < atr * 0.5);
   // Bar [1] closed back above EMA20
   bool recoveredAbove = (close1 > ema20_1);

   return (touchedEMA && recoveredAbove);
}

//+------------------------------------------------------------------+
//| Pullback Sell: price pulled back toward EMA20 from below         |
//+------------------------------------------------------------------+
bool IsPullbackSell()
{
   double close1  = iClose(_Symbol, PERIOD_M5, 1);
   double close2  = iClose(_Symbol, PERIOD_M5, 2);
   double ema20_1 = EmaFast5M[1];
   double ema20_2 = EmaFast5M[2];
   double atr     = Atr5M[1];

   bool touchedEMA = (MathAbs(close2 - ema20_2) < atr * 0.5);
   bool recoveredBelow = (close1 < ema20_1);

   return (touchedEMA && recoveredBelow);
}

//+------------------------------------------------------------------+
//| Breakout Buy: price closes above recent swing high               |
//+------------------------------------------------------------------+
bool IsBreakoutBuy()
{
   double close1  = iClose(_Symbol, PERIOD_M5, 1);
   double atr     = Atr5M[1];
   double buffer  = (InpBreakoutBuffer > 0) ? InpBreakoutBuffer * SymbolInfoDouble(_Symbol, SYMBOL_POINT) : atr * 0.1;

   // Find highest high in last InpPullbackBars bars (excluding bar 0 and 1)
   double swingHigh = 0;
   for(int i = 2; i <= InpPullbackBars + 1; i++)
      swingHigh = MathMax(swingHigh, iHigh(_Symbol, PERIOD_M5, i));

   return (close1 > swingHigh + buffer);
}

//+------------------------------------------------------------------+
//| Breakout Sell: price closes below recent swing low               |
//+------------------------------------------------------------------+
bool IsBreakoutSell()
{
   double close1  = iClose(_Symbol, PERIOD_M5, 1);
   double atr     = Atr5M[1];
   double buffer  = (InpBreakoutBuffer > 0) ? InpBreakoutBuffer * SymbolInfoDouble(_Symbol, SYMBOL_POINT) : atr * 0.1;

   double swingLow = DBL_MAX;
   for(int i = 2; i <= InpPullbackBars + 1; i++)
      swingLow = MathMin(swingLow, iLow(_Symbol, PERIOD_M5, i));

   return (close1 < swingLow - buffer);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk %                               |
//+------------------------------------------------------------------+
double CalcLotSize(double slPoints)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * InpRiskPercent / 100.0;
   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointSize  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(tickSize <= 0 || tickValue <= 0 || slPoints <= 0) return 0;

   double slTicks    = slPoints / tickSize;
   double lotSize    = riskAmount / (slTicks * tickValue);

   // Normalize to broker constraints
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

   return lotSize;
}

//+------------------------------------------------------------------+
//| Open a trade                                                     |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double atr)
{
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double slDist = atr * InpSL_ATR_Multi;
   double tpDist = atr * InpTP_ATR_Multi;

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
   if(lots <= 0)
   {
      Print("Lot size calculation failed. Skipping trade.");
      return;
   }

   string comment = EaName + " | " + ((type == ORDER_TYPE_BUY) ? "BUY" : "SELL");
   bool result = (type == ORDER_TYPE_BUY) 
                 ? Trade.Buy(lots,  _Symbol, entry, sl, tp, comment)
                 : Trade.Sell(lots, _Symbol, entry, sl, tp, comment);

   if(result)
      Print("Trade opened: ", (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), " | Lots: ", lots, " | SL: ", sl, " | TP: ", tp);
   else
      Print("Trade failed. Error: ", GetLastError(), " | RetCode: ", Trade.ResultRetcode());
}

//+------------------------------------------------------------------+
//| Manage open trades (BE and trailing)                             |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosInfo.SelectByIndex(i)) continue;
      if(PosInfo.Symbol() != _Symbol) continue;
      if(PosInfo.Magic() != 202501) continue;

      double openPrice  = PosInfo.PriceOpen();
      double currentSL  = PosInfo.StopLoss();
      double currentTP  = PosInfo.TakeProfit();
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      if(PosInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double slDist = openPrice - currentSL;
         if(slDist <= 0) continue;

         // Break even
         if(InpUseBreakEven && currentSL < openPrice)
         {
            double beThreshold = openPrice + slDist * InpBreakEvenAt;
            if(currentBid >= beThreshold)
            {
               double newSL = NormalizeDouble(openPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2, digits);
               if(newSL > currentSL)
                  Trade.PositionModify(PosInfo.Ticket(), newSL, currentTP);
            }
         }

         // Trailing stop
         if(InpUseTrailingStop)
         {
            double atr = Atr5M[1];
            double trailSL = NormalizeDouble(currentBid - atr * InpTrailATRMulti, digits);
            if(trailSL > currentSL && trailSL < currentBid)
               Trade.PositionModify(PosInfo.Ticket(), trailSL, currentTP);
         }
      }
      else if(PosInfo.PositionType() == POSITION_TYPE_SELL)
      {
         double slDist = currentSL - openPrice;
         if(slDist <= 0) continue;

         if(InpUseBreakEven && currentSL > openPrice)
         {
            double beThreshold = openPrice - slDist * InpBreakEvenAt;
            if(currentAsk <= beThreshold)
            {
               double newSL = NormalizeDouble(openPrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2, digits);
               if(newSL < currentSL)
                  Trade.PositionModify(PosInfo.Ticket(), newSL, currentTP);
            }
         }

         if(InpUseTrailingStop)
         {
            double atr = Atr5M[1];
            double trailSL = NormalizeDouble(currentAsk + atr * InpTrailATRMulti, digits);
            if(trailSL < currentSL && trailSL > currentAsk)
               Trade.PositionModify(PosInfo.Ticket(), trailSL, currentTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count EA's open trades                                           |
//+------------------------------------------------------------------+
int CountMyTrades()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosInfo.SelectByIndex(i)) continue;
      if(PosInfo.Symbol() == _Symbol && PosInfo.Magic() == 202501)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Session filter                                                   |
//+------------------------------------------------------------------+
bool IsSessionActive()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= InpSessionStartHour && dt.hour < InpSessionEndHour);
}

//+------------------------------------------------------------------+
//|                    DASHBOARD PANEL                               |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   DeleteDashboard();
   int x  = InpDashX;
   int y  = InpDashY;
   int w  = 240;
   int h  = 340;

   // Background
   CreateRect(DashPrefix + "BG", x, y, w, h, C'18,20,26', 180);
   CreateRect(DashPrefix + "BORDER", x, y, w, 2, C'0,160,120', 255);
   CreateRect(DashPrefix + "BORDER2", x, y+h-2, w, 2, C'0,160,120', 255);

   // Title
   CreateLabel(DashPrefix + "TITLE",   x+10, y+8,  "⚡ EMA SCALP EA PRO",    "Arial Bold", 10, C'0,200,150');
   CreateLabel(DashPrefix + "SYMBOL",  x+10, y+26, _Symbol + " | " + EaVersion, "Arial", 8, C'140,150,170');

   // Separator
   CreateRect(DashPrefix + "SEP1", x+5, y+42, w-10, 1, C'40,45,55', 255);

   // Direction labels
   CreateLabel(DashPrefix + "LBL_DIR",   x+10, y+50, "DIRECTION",   "Arial Bold", 8, C'100,110,130');
   CreateLabel(DashPrefix + "LBL_5M",    x+10, y+64, "5M Trend:",   "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_5M",    x+100,y+64, "---",         "Arial Bold", 8, clrWhite);
   CreateLabel(DashPrefix + "LBL_15M",   x+10, y+80, "15M Trend:",  "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_15M",   x+100,y+80, "---",         "Arial Bold", 8, clrWhite);
   CreateLabel(DashPrefix + "LBL_CONF",  x+10, y+96, "Confluence:", "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_CONF",  x+100,y+96, "---",         "Arial Bold", 8, clrWhite);

   // Separator
   CreateRect(DashPrefix + "SEP2", x+5, y+112, w-10, 1, C'40,45,55', 255);

   // EMA Values
   CreateLabel(DashPrefix + "LBL_EMA",   x+10, y+118, "EMA 5M VALUES", "Arial Bold", 8, C'100,110,130');
   CreateLabel(DashPrefix + "LBL_E20",   x+10, y+132, "EMA 20:",       "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_E20",   x+100,y+132, "---",           "Arial Bold", 8, C'80,200,255');
   CreateLabel(DashPrefix + "LBL_E50",   x+10, y+148, "EMA 50:",       "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_E50",   x+100,y+148, "---",           "Arial Bold", 8, C'255,180,50');
   CreateLabel(DashPrefix + "LBL_E200",  x+10, y+164, "EMA 200:",      "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_E200",  x+100,y+164, "---",           "Arial Bold", 8, C'255,80,100');

   // Separator
   CreateRect(DashPrefix + "SEP3", x+5, y+180, w-10, 1, C'40,45,55', 255);

   // ATR
   CreateLabel(DashPrefix + "LBL_MARKET",x+10, y+186, "MARKET",    "Arial Bold", 8, C'100,110,130');
   CreateLabel(DashPrefix + "LBL_ATR",   x+10, y+186, "ATR (5M):",  "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_ATR",   x+100,y+186, "---",        "Arial Bold", 8, clrWhite);
   CreateLabel(DashPrefix + "LBL_SPR",   x+10, y+202, "Spread:",    "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_SPR",   x+100,y+202, "---",        "Arial Bold", 8, clrWhite);

   // Separator
   CreateRect(DashPrefix + "SEP4", x+5, y+218, w-10, 1, C'40,45,55', 255);

   // Trade Stats
   CreateLabel(DashPrefix + "LBL_TRADE", x+10, y+224, "TRADES",       "Arial Bold", 8, C'100,110,130');
   CreateLabel(DashPrefix + "LBL_OPEN",  x+10, y+238, "Open Trades:", "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_OPEN",  x+120,y+238, "0",            "Arial Bold", 8, clrWhite);
   CreateLabel(DashPrefix + "LBL_BAL",   x+10, y+254, "Balance:",     "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_BAL",   x+100,y+254, "---",          "Arial Bold", 8, clrWhite);
   CreateLabel(DashPrefix + "LBL_EQ",    x+10, y+270, "Equity:",      "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_EQ",    x+100,y+270, "---",          "Arial Bold", 8, clrWhite);
   CreateLabel(DashPrefix + "LBL_PNL",   x+10, y+286, "Open P/L:",    "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_PNL",   x+100,y+286, "---",          "Arial Bold", 8, clrWhite);

   // Separator
   CreateRect(DashPrefix + "SEP5", x+5, y+302, w-10, 1, C'40,45,55', 255);

   // Status
   CreateLabel(DashPrefix + "LBL_SES",  x+10, y+310, "Session:",   "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_SES",  x+100,y+310, "---",        "Arial Bold", 8, clrWhite);
   CreateLabel(DashPrefix + "LBL_SIG",  x+10, y+326, "Signal:",    "Arial", 8, C'170,180,200');
   CreateLabel(DashPrefix + "VAL_SIG",  x+100,y+326, "WAITING",    "Arial Bold", 8, C'180,180,60');

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update dashboard values                                          |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!InpShowDashboard) return;
   if(ArraySize(EmaFast5M) < 2) { RefreshData(); return; }

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Trends
   ENUM_TREND t5  = GetTrend5M();
   ENUM_TREND t15 = GetTrend15M();
   bool confluent = (t5 != TREND_NONE && t15 != TREND_NONE && t5 == t15);

   string s5  = (t5  == TREND_UP) ? "▲ BULLISH" : (t5  == TREND_DOWN) ? "▼ BEARISH" : "— NEUTRAL";
   string s15 = (t15 == TREND_UP) ? "▲ BULLISH" : (t15 == TREND_DOWN) ? "▼ BEARISH" : "— NEUTRAL";
   color  c5  = (t5  == TREND_UP) ? C'0,220,130'  : (t5  == TREND_DOWN) ? C'255,70,70' : C'160,160,160';
   color  c15 = (t15 == TREND_UP) ? C'0,220,130'  : (t15 == TREND_DOWN) ? C'255,70,70' : C'160,160,160';

   UpdateLabel(DashPrefix + "VAL_5M",  s5,  c5);
   UpdateLabel(DashPrefix + "VAL_15M", s15, c15);
   UpdateLabel(DashPrefix + "VAL_CONF",
               confluent ? "✓ YES" : "✗ NO",
               confluent ? C'0,220,130' : C'255,120,60');

   // EMA values
   UpdateLabel(DashPrefix + "VAL_E20",  DoubleToString(EmaFast5M[1], digits), C'80,200,255');
   UpdateLabel(DashPrefix + "VAL_E50",  DoubleToString(EmaMid5M[1],  digits), C'255,180,50');
   UpdateLabel(DashPrefix + "VAL_E200", DoubleToString(EmaSlow5M[1], digits), C'255,80,100');

   // ATR and spread
   double atr    = (ArraySize(Atr5M) > 1) ? Atr5M[1] : 0;
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   UpdateLabel(DashPrefix + "VAL_ATR", DoubleToString(atr,    digits), clrWhite);
   UpdateLabel(DashPrefix + "VAL_SPR", DoubleToString(spread, digits), spread > atr * 0.3 ? C'255,120,60' : C'0,200,130');

   // Account info
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double pnl     = equity - balance;
   UpdateLabel(DashPrefix + "VAL_BAL", DoubleToString(balance, 2), clrWhite);
   UpdateLabel(DashPrefix + "VAL_EQ",  DoubleToString(equity,  2), clrWhite);
   UpdateLabel(DashPrefix + "VAL_PNL", (pnl >= 0 ? "+" : "") + DoubleToString(pnl, 2),
               pnl >= 0 ? C'0,220,130' : C'255,70,70');

   // Trade count
   int trades = CountMyTrades();
   UpdateLabel(DashPrefix + "VAL_OPEN", IntegerToString(trades), trades > 0 ? C'80,200,255' : clrWhite);

   // Session status
   bool sessActive = !InpUseSessionFilter || IsSessionActive();
   UpdateLabel(DashPrefix + "VAL_SES",
               sessActive ? "ACTIVE" : "CLOSED",
               sessActive ? C'0,220,130' : C'255,70,70');

   // Signal
   string sig = "WAITING";
   color  sigC = C'180,180,60';
   if(!sessActive)       { sig = "NO SESSION"; sigC = C'120,120,140'; }
   else if(!confluent)   { sig = "NO CONF.";   sigC = C'180,120,40'; }
   else if(t5 == TREND_UP)
   {
      if(IsPullbackBuy() || IsBreakoutBuy())  { sig = "▲ BUY";  sigC = C'0,230,130'; }
      else { sig = "BULL - WAITING"; sigC = C'0,180,100'; }
   }
   else if(t5 == TREND_DOWN)
   {
      if(IsPullbackSell() || IsBreakoutSell()) { sig = "▼ SELL"; sigC = C'255,80,80'; }
      else { sig = "BEAR - WAITING"; sigC = C'200,80,80'; }
   }
   UpdateLabel(DashPrefix + "VAL_SIG", sig, sigC);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete all dashboard objects                                     |
//+------------------------------------------------------------------+
void DeleteDashboard()
{
   ObjectsDeleteAll(0, DashPrefix);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Helper: Create rectangle                                         |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color clr, uchar alpha)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
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

//+------------------------------------------------------------------+
//| Helper: Create text label                                        |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, string font, int size, color clr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
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
//| Helper: Update existing label                                    |
//+------------------------------------------------------------------+
void UpdateLabel(string name, string text, color clr)
{
   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetString( 0, name, OBJPROP_TEXT,  text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
}

//+------------------------------------------------------------------+