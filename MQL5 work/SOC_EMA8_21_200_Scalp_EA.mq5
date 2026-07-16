//+------------------------------------------------------------------+
//|                  SOC EMA 8/21/200 Scalp EA                       |
//|        5M Entry | 15M Direction | 1H Macro | Pullback+BO+S&R     |
//|                 Compatible: All Instruments                      |
//|                    Broker: Exness MT5                            |
//+------------------------------------------------------------------+
#property copyright "Sons-Of-Christ"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade        Trade;
CPositionInfo PosInfo;

//==========================================================
//  INPUTS
//==========================================================
input group "=== RISK MANAGEMENT ==="
input bool   InpAutoLot         = true;    // Auto lot (% risk) or fixed
input double InpLotSize         = 0.02;    // Fixed lot (if AutoLot=false)
input double InpRiskPercent     = 1.0;     // Risk % per trade (if AutoLot=true)
input int    InpMaxTrades       = 2;       // Max open trades per symbol
input int    InpMaxSpread       = 1500;    // Max spread in points

input group "=== EMA SETTINGS ==="
input int    InpEMA_Fast        = 8;       // Fast EMA  (8)
input int    InpEMA_Mid         = 21;      // Mid EMA   (21)
input int    InpEMA_Slow        = 200;     // Slow EMA  (200)

input group "=== ATR / SL / TP ==="
input int    InpATR_Period      = 14;      // ATR period
input double InpSL_ATR_Multi    = 1.5;     // SL = ATR x this
input double InpTP_ATR_Multi    = 3.0;     // TP = ATR x this
input int    InpFallbackSL      = 500;     // Fallback SL points
input int    InpFallbackTP      = 1000;    // Fallback TP points

input group "=== ENTRY SETTINGS ==="
input bool   InpUsePullback     = true;    // Pullback to EMA8 entries
input bool   InpUseBreakout     = true;    // Breakout entries
input bool   InpUseSR           = true;    // S&R / Supply-Demand entries
input int    InpSR_Lookback     = 20;      // Bars to scan for S&R swing points
input double InpSR_ZonePct      = 0.003;   // S&R zone width as % of price
input int    InpBreakoutBars    = 3;       // Swing lookback bars for breakout

input group "=== HTF FILTERS ==="
input bool   InpUse1HFilter     = true;    // 1H macro direction filter
input bool   InpUse15MFilter    = true;    // 15M direction filter

input group "=== TRADE MANAGEMENT ==="
input bool   InpUseBreakEven    = true;    // Move SL to break-even
input double InpBreakEvenAt     = 1.0;     // Trigger BE at X * SL dist in profit
input bool   InpUseTrailing     = true;    // ATR trailing stop
input double InpTrailATRMulti   = 1.0;     // Trail = ATR x this
input int    InpTrailStart      = 500;     // Min profit points before trail starts
input int    InpCooldownMins    = 30;      // Cooldown minutes after max trades hit

input group "=== SESSION FILTER (SAST GMT+2) ==="
input bool   InpUseSession      = true;    // Enable session filter
input bool   InpTradeAsian      = true;    // Trade Asian session  (03:00-05:00)
input bool   InpTradeLondon     = true;    // Trade London session (09:00-11:00 SAST)
input bool   InpTradeNYMorn     = true;    // Trade NY Morning     (14:00-17:00)
input bool   InpTradeNYAft      = true;    // Trade NY Afternoon   (20:00-22:00)

input group "=== DASHBOARD ==="
input bool   InpShowDash        = true;    // Show dashboard panel
input int    InpDashX           = 15;      // Dashboard X position
input int    InpDashY           = 30;      // Dashboard Y position

//==========================================================
//  GLOBALS
//==========================================================
// 5M handles
int h8_5M,  h21_5M,  h200_5M,  hATR5M;
// 15M handles
int h8_15M, h21_15M, h200_15M;
// 1H handles
int h8_1H,  h21_1H,  h200_1H;

// Buffers
double ema8_5M[],  ema21_5M[],  ema200_5M[];
double ema8_15M[], ema21_15M[], ema200_15M[];
double ema8_1H[],  ema21_1H[],  ema200_1H[];
double atr5M[];

datetime LastBar5M     = 0;
datetime CooldownStart = 0;
double   ask, bid;

string DashPfx = "SOC8_";
string EaName  = "SOC EMA 8/21/200 Scalp EA";
string EaVer   = "v1.00";

enum ENUM_TREND { TREND_UP, TREND_DOWN, TREND_NONE };

//==========================================================
//  INIT
//==========================================================
int OnInit()
{
   Trade.SetExpertMagicNumber(821200);
   Trade.SetDeviationInPoints(30);
   Trade.SetTypeFilling(ORDER_FILLING_IOC);

   // 5M
   h8_5M   = iMA(_Symbol, PERIOD_M5,  InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   h21_5M  = iMA(_Symbol, PERIOD_M5,  InpEMA_Mid,  0, MODE_EMA, PRICE_CLOSE);
   h200_5M = iMA(_Symbol, PERIOD_M5,  InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   // 15M
   h8_15M  = iMA(_Symbol, PERIOD_M15, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   h21_15M = iMA(_Symbol, PERIOD_M15, InpEMA_Mid,  0, MODE_EMA, PRICE_CLOSE);
   h200_15M= iMA(_Symbol, PERIOD_M15, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   // 1H
   h8_1H   = iMA(_Symbol, PERIOD_H1,  InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   h21_1H  = iMA(_Symbol, PERIOD_H1,  InpEMA_Mid,  0, MODE_EMA, PRICE_CLOSE);
   h200_1H = iMA(_Symbol, PERIOD_H1,  InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   // ATR
   hATR5M  = iATR(_Symbol, PERIOD_M5, InpATR_Period);

   if(h8_5M==INVALID_HANDLE || h21_5M==INVALID_HANDLE || h200_5M==INVALID_HANDLE ||
      h8_15M==INVALID_HANDLE|| h21_15M==INVALID_HANDLE|| h200_15M==INVALID_HANDLE||
      h8_1H==INVALID_HANDLE || h21_1H==INVALID_HANDLE || h200_1H==INVALID_HANDLE ||
      hATR5M==INVALID_HANDLE)
   { Print("ERROR: Indicator handle failed."); return INIT_FAILED; }

   ArraySetAsSeries(ema8_5M,   true); ArraySetAsSeries(ema21_5M,  true); ArraySetAsSeries(ema200_5M,  true);
   ArraySetAsSeries(ema8_15M,  true); ArraySetAsSeries(ema21_15M, true); ArraySetAsSeries(ema200_15M, true);
   ArraySetAsSeries(ema8_1H,   true); ArraySetAsSeries(ema21_1H,  true); ArraySetAsSeries(ema200_1H,  true);
   ArraySetAsSeries(atr5M,     true);

   if(InpShowDash) CreateDashboard();
   Print(EaName, " ", EaVer, " initialized on ", _Symbol);
   return INIT_SUCCEEDED;
}

//==========================================================
//  DEINIT
//==========================================================
void OnDeinit(const int reason)
{
   int h[] = {h8_5M,h21_5M,h200_5M,h8_15M,h21_15M,h200_15M,h8_1H,h21_1H,h200_1H,hATR5M};
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
   if(InpShowDash) UpdateDashboard();

   if(InpUseSession && !IsSessionActive()) return;
   if(!SpreadOK()) return;

   int trades = CountMyTrades();
   if(trades >= InpMaxTrades)
   { if(CooldownStart==0) CooldownStart=TimeCurrent(); return; }
   if(CooldownActive()) return;

   // New 5M bar gate
   datetime curBar = iTime(_Symbol, PERIOD_M5, 0);
   if(curBar == LastBar5M) return;
   LastBar5M = curBar;

   if(!RefreshData()) return;

   // --- Trend reads ---
   ENUM_TREND t1H  = GetTrend(ema8_1H[1],  ema21_1H[1],  ema200_1H[1]);
   ENUM_TREND t15M = GetTrend(ema8_15M[1], ema21_15M[1], ema200_15M[1]);
   ENUM_TREND t5M  = GetTrend(ema8_5M[1],  ema21_5M[1],  ema200_5M[1]);

   if(t5M == TREND_NONE) return;
   if(InpUse1HFilter  && (t1H  == TREND_NONE || t1H  != t5M)) return;
   if(InpUse15MFilter && (t15M == TREND_NONE || t15M != t5M)) return;

   double atr = atr5M[1];
   if(atr <= 0) return;

   // --- Entry evaluation ---
   string reason = "";

   if(t5M == TREND_UP)
   {
      bool pb = InpUsePullback && IsPullbackBuy();
      bool bo = InpUseBreakout && IsBreakoutBuy();
      bool sr = InpUseSR      && IsSR_Buy();
      if((pb || bo || sr) && !HedgeBlocked(POSITION_TYPE_BUY))
      {
         reason = pb ? "Pullback" : (bo ? "Breakout" : "S&R");
         OpenTrade(ORDER_TYPE_BUY, atr, reason);
      }
   }
   else if(t5M == TREND_DOWN)
   {
      bool pb = InpUsePullback && IsPullbackSell();
      bool bo = InpUseBreakout && IsBreakoutSell();
      bool sr = InpUseSR      && IsSR_Sell();
      if((pb || bo || sr) && !HedgeBlocked(POSITION_TYPE_SELL))
      {
         reason = pb ? "Pullback" : (bo ? "Breakout" : "S&R");
         OpenTrade(ORDER_TYPE_SELL, atr, reason);
      }
   }
}

//==========================================================
//  REFRESH DATA
//==========================================================
bool RefreshData()
{
   int b = InpEMA_Slow + InpSR_Lookback + 5;
   if(CopyBuffer(h8_5M,   0,0,b,ema8_5M)   <=0) return false;
   if(CopyBuffer(h21_5M,  0,0,b,ema21_5M)  <=0) return false;
   if(CopyBuffer(h200_5M, 0,0,b,ema200_5M) <=0) return false;
   if(CopyBuffer(h8_15M,  0,0,b,ema8_15M)  <=0) return false;
   if(CopyBuffer(h21_15M, 0,0,b,ema21_15M) <=0) return false;
   if(CopyBuffer(h200_15M,0,0,b,ema200_15M)<=0) return false;
   if(CopyBuffer(h8_1H,   0,0,b,ema8_1H)   <=0) return false;
   if(CopyBuffer(h21_1H,  0,0,b,ema21_1H)  <=0) return false;
   if(CopyBuffer(h200_1H, 0,0,b,ema200_1H) <=0) return false;
   if(CopyBuffer(hATR5M,  0,0,5,atr5M)     <=0) return false;
   return true;
}

//==========================================================
//  TREND — EMA8 > EMA200 AND EMA21 > EMA200 = BULL
//          EMA8 < EMA200 AND EMA21 < EMA200 = BEAR
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

// Pullback Buy: price tagged EMA8, last bar recovered above it
// Also checks EMA8 is above EMA21 (trend momentum confirmed)
bool IsPullbackBuy()
{
   double c1  = iClose(_Symbol, PERIOD_M5, 1);
   double c2  = iClose(_Symbol, PERIOD_M5, 2);
   double l2  = iLow  (_Symbol, PERIOD_M5, 2);
   double e8_1= ema8_5M[1];
   double e8_2= ema8_5M[2];
   double e21 = ema21_5M[1];
   double atr = atr5M[1];
   // Bar 2 touched or dipped close to EMA8
   bool tagged   = (MathAbs(l2 - e8_2) < atr * 0.4 || l2 <= e8_2);
   // Bar 1 closed above EMA8 and EMA8 still above EMA21
   bool recovered= (c1 > e8_1 && e8_1 > e21);
   return (tagged && recovered);
}

// Pullback Sell: price tagged EMA8, last bar recovered below it
bool IsPullbackSell()
{
   double c1  = iClose(_Symbol, PERIOD_M5, 1);
   double h2  = iHigh (_Symbol, PERIOD_M5, 2);
   double e8_1= ema8_5M[1];
   double e8_2= ema8_5M[2];
   double e21 = ema21_5M[1];
   double atr = atr5M[1];
   bool tagged   = (MathAbs(h2 - e8_2) < atr * 0.4 || h2 >= e8_2);
   bool recovered= (c1 < e8_1 && e8_1 < e21);
   return (tagged && recovered);
}

// Breakout Buy: 5M close above recent swing high with EMA8 > EMA21
bool IsBreakoutBuy()
{
   double c1  = iClose(_Symbol, PERIOD_M5, 1);
   double buf = atr5M[1] * 0.1;
   double swH = 0;
   for(int i=2; i<=InpBreakoutBars+1; i++)
      swH = MathMax(swH, iHigh(_Symbol, PERIOD_M5, i));
   return (c1 > swH + buf && ema8_5M[1] > ema21_5M[1]);
}

// Breakout Sell: 5M close below recent swing low with EMA8 < EMA21
bool IsBreakoutSell()
{
   double c1  = iClose(_Symbol, PERIOD_M5, 1);
   double buf = atr5M[1] * 0.1;
   double swL = DBL_MAX;
   for(int i=2; i<=InpBreakoutBars+1; i++)
      swL = MathMin(swL, iLow(_Symbol, PERIOD_M5, i));
   return (c1 < swL - buf && ema8_5M[1] < ema21_5M[1]);
}

// S&R Buy: price bouncing from 5M swing low support zone
bool IsSR_Buy()
{
   double zoneW = ask * InpSR_ZonePct;
   for(int i=2; i<InpSR_Lookback; i++)
   {
      double lo = iLow(_Symbol, PERIOD_M5, i);
      if(lo < iLow(_Symbol,PERIOD_M5,i-1) && lo < iLow(_Symbol,PERIOD_M5,i+1))
      {
         if(ask >= lo - zoneW && ask <= lo + zoneW)
         {
            double c1=iClose(_Symbol,PERIOD_M5,1), o1=iOpen(_Symbol,PERIOD_M5,1);
            if(c1 > o1 && c1 > lo && ema8_5M[1] > ema21_5M[1]) return true;
         }
      }
   }
   return false;
}

// S&R Sell: price rejecting from 5M swing high resistance zone
bool IsSR_Sell()
{
   double zoneW = bid * InpSR_ZonePct;
   for(int i=2; i<InpSR_Lookback; i++)
   {
      double hi = iHigh(_Symbol, PERIOD_M5, i);
      if(hi > iHigh(_Symbol,PERIOD_M5,i-1) && hi > iHigh(_Symbol,PERIOD_M5,i+1))
      {
         if(bid >= hi - zoneW && bid <= hi + zoneW)
         {
            double c1=iClose(_Symbol,PERIOD_M5,1), o1=iOpen(_Symbol,PERIOD_M5,1);
            if(c1 < o1 && c1 < hi && ema8_5M[1] < ema21_5M[1]) return true;
         }
      }
   }
   return false;
}

//==========================================================
//  LOT SIZE
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

//==========================================================
//  OPEN TRADE
//==========================================================
void OpenTrade(ENUM_ORDER_TYPE type, double atr, string reason)
{
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDist = (atr>0) ? atr*InpSL_ATR_Multi : InpFallbackSL*point;
   double tpDist = (atr>0) ? atr*InpTP_ATR_Multi : InpFallbackTP*point;
   double entry,sl,tp;

   if(type==ORDER_TYPE_BUY)
   { entry=ask; sl=NormalizeDouble(entry-slDist,digits); tp=NormalizeDouble(entry+tpDist,digits); }
   else
   { entry=bid; sl=NormalizeDouble(entry+slDist,digits); tp=NormalizeDouble(entry-tpDist,digits); }

   double lots = CalcLotSize(slDist);
   if(lots<=0){ Print("Lot calc failed — skip."); return; }

   string cmt = EaName+" | "+(type==ORDER_TYPE_BUY?"BUY":"SELL")+" | "+reason;
   bool ok = (type==ORDER_TYPE_BUY)
             ? Trade.Buy(lots,_Symbol,entry,sl,tp,cmt)
             : Trade.Sell(lots,_Symbol,entry,sl,tp,cmt);
   if(ok)
      Print("TRADE: ",(type==ORDER_TYPE_BUY?"BUY":"SELL")," lots=",lots,
            " sl=",sl," tp=",tp," | ",reason);
   else
      Print("FAILED: err=",GetLastError()," ret=",Trade.ResultRetcode());
}

//==========================================================
//  MANAGE OPEN TRADES
//==========================================================
void ManageOpenTrades()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!PosInfo.SelectByIndex(i)) continue;
      if(PosInfo.Symbol()!=_Symbol || PosInfo.Magic()!=821200) continue;

      double open  = PosInfo.PriceOpen();
      double curSL = PosInfo.StopLoss();
      double curTP = PosInfo.TakeProfit();
      int    digs  = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      double pt    = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      double atr   = (ArraySize(atr5M)>1) ? atr5M[1] : 0;

      if(PosInfo.PositionType()==POSITION_TYPE_BUY)
      {
         double sld = open - curSL;
         double prf = (bid - open)/pt;
         if(InpUseBreakEven && curSL<open && sld>0 && bid>=open+sld*InpBreakEvenAt)
         {
            double nsl=NormalizeDouble(open+pt*2,digs);
            if(nsl>curSL) Trade.PositionModify(PosInfo.Ticket(),nsl,curTP);
         }
         if(InpUseTrailing && atr>0 && prf>=InpTrailStart)
         {
            double tsl=NormalizeDouble(bid-atr*InpTrailATRMulti,digs);
            if(tsl>curSL && tsl<bid) Trade.PositionModify(PosInfo.Ticket(),tsl,curTP);
         }
      }
      else if(PosInfo.PositionType()==POSITION_TYPE_SELL)
      {
         double sld = curSL - open;
         double prf = (open - ask)/pt;
         if(InpUseBreakEven && curSL>open && sld>0 && ask<=open-sld*InpBreakEvenAt)
         {
            double nsl=NormalizeDouble(open-pt*2,digs);
            if(nsl<curSL) Trade.PositionModify(PosInfo.Ticket(),nsl,curTP);
         }
         if(InpUseTrailing && atr>0 && prf>=InpTrailStart)
         {
            double tsl=NormalizeDouble(ask+atr*InpTrailATRMulti,digs);
            if(tsl<curSL && tsl>ask) Trade.PositionModify(PosInfo.Ticket(),tsl,curTP);
         }
      }
   }
}

//==========================================================
//  UTILITIES
//==========================================================
int CountMyTrades()
{
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!PosInfo.SelectByIndex(i)) continue;
      if(PosInfo.Symbol()==_Symbol && PosInfo.Magic()==821200) c++;
   }
   return c;
}

bool SpreadOK()
{ return ((ask-bid)/_Point <= InpMaxSpread); }

bool HedgeBlocked(long newType)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_TYPE)!=newType) return true;
   }
   return false;
}

bool CooldownActive()
{
   if(CooldownStart==0) return false;
   if((int)(TimeCurrent()-CooldownStart)>=InpCooldownMins*60)
   { CooldownStart=0; return false; }
   return true;
}

bool IsSessionActive()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(),t); int h=t.hour;
   if(InpTradeAsian  && h>=3  && h<5)  return true;
   if(InpTradeLondon && h>=9 && h<11) return true;
   if(InpTradeNYMorn && h>=14 && h<17) return true;
   if(InpTradeNYAft  && h>=20 && h<22) return true;
   return false;
}

string ActiveSession()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(),t); int h=t.hour;
   if(h>=3  && h<5)  return "Asian";
   if(h>=9 && h<11) return "London";
   if(h>=14 && h<17) return "NY Morning";
   if(h>=20 && h<22) return "NY Afternoon";
   return "OFF";
}

string TrendStr(ENUM_TREND t)
{ return t==TREND_UP?"▲ BULL":t==TREND_DOWN?"▼ BEAR":"— FLAT"; }
color TrendCol(ENUM_TREND t)
{ return t==TREND_UP?C'0,215,130':t==TREND_DOWN?C'255,70,70':C'110,120,145'; }

//==========================================================
//  DASHBOARD
//==========================================================
void CreateDashboard()
{
   DeleteDashboard();
   int x=InpDashX, y=InpDashY, w=255, h=460;

   Rect(DashPfx+"BG",  x,    y,     w,  h,  C'255,255,255', 235);
   Rect(DashPfx+"BT",  x,    y,     w,  3,  C'255,160,30',255);
   Rect(DashPfx+"BB",  x,    y+h-3, w,  3,  C'255,160,30',255);
   Rect(DashPfx+"BL",  x,    y,     3,  h,  C'255,160,30',255);
   Rect(DashPfx+"BR",  x+w-3,y,     3,  h,  C'255,160,30',255);

   Lbl(DashPfx+"TITLE", x+10, y+8,  "⚡ EMA 8 / 21 / 200  SCALP",  "Arial Bold",10,C'255,170,35');
   Lbl(DashPfx+"SUB",   x+10, y+26, _Symbol+"   |   "+EaVer,        "Arial",     8, C'100,110,135');

   Sep(DashPfx+"S0",x,y+42,w);

   // Direction
   Hdr(DashPfx+"HD1",x,y+49,"DIRECTION");
   Row(DashPfx+"R1H", x,y+63, "1H  Trend:","---");
   Row(DashPfx+"R15M",x,y+79, "15M Trend:","---");
   Row(DashPfx+"R5M", x,y+95, "5M  Trend:","---");
   Row(DashPfx+"RCF", x,y+111,"Confluence:","---");

   Sep(DashPfx+"S1",x,y+127,w);

   // EMA Momentum
   Hdr(DashPfx+"HD2",x,y+134,"EMA MOMENTUM  (5M)");
   Row(DashPfx+"E8",  x,y+148,"EMA  8:","---");
   Row(DashPfx+"E21", x,y+164,"EMA 21:","---");
   Row(DashPfx+"E200",x,y+180,"EMA 200:","---");
   Row(DashPfx+"EPOS",x,y+196,"8 vs 21:","---");

   Sep(DashPfx+"S2",x,y+212,w);

   // Signal
   Hdr(DashPfx+"HD3",x,y+219,"SIGNAL");
   Row(DashPfx+"SIG", x,y+233,"Signal:","WAITING");
   Row(DashPfx+"TYP", x,y+249,"Type:","---");

   Sep(DashPfx+"S3",x,y+265,w);

   // Market
   Hdr(DashPfx+"HD4",x,y+272,"MARKET");
   Row(DashPfx+"ATR", x,y+286,"ATR (5M):","---");
   Row(DashPfx+"SPR", x,y+302,"Spread:","---");
   Row(DashPfx+"SES", x,y+318,"Session:","---");

   Sep(DashPfx+"S4",x,y+334,w);

   // Account
   Hdr(DashPfx+"HD5",x,y+341,"ACCOUNT");
   Row(DashPfx+"OPN", x,y+355,"Open Trades:","0");
   Row(DashPfx+"CDN", x,y+371,"Cooldown:","OFF");
   Row(DashPfx+"BAL", x,y+387,"Balance:","---");
   Row(DashPfx+"EQT", x,y+403,"Equity:","---");
   Row(DashPfx+"PNL", x,y+419,"Open P/L:","---");

   ChartRedraw();
}

void UpdateDashboard()
{
   if(!InpShowDash) return;
   if(ArraySize(ema8_5M)<2) return;

   int    digs  = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double atr   = (ArraySize(atr5M)>1)?atr5M[1]:0;
   double spread= SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*_Point;

   ENUM_TREND t1H  = GetTrend(ema8_1H[1], ema21_1H[1], ema200_1H[1]);
   ENUM_TREND t15M = GetTrend(ema8_15M[1],ema21_15M[1],ema200_15M[1]);
   ENUM_TREND t5M  = GetTrend(ema8_5M[1], ema21_5M[1], ema200_5M[1]);

   bool f1H  = !InpUse1HFilter  || (t1H !=TREND_NONE && t1H ==t5M);
   bool f15M = !InpUse15MFilter || (t15M!=TREND_NONE && t15M==t5M);
   bool conf = (t5M!=TREND_NONE) && f1H && f15M;

   // Direction rows
   UpdV(DashPfx+"R1H",  InpUse1HFilter  ? TrendStr(t1H)  : "DISABLED",
                         InpUse1HFilter  ? TrendCol(t1H)  : C'70,80,100');
   UpdV(DashPfx+"R15M", InpUse15MFilter ? TrendStr(t15M) : "DISABLED",
                         InpUse15MFilter ? TrendCol(t15M) : C'70,80,100');
   UpdV(DashPfx+"R5M",  TrendStr(t5M), TrendCol(t5M));
   UpdV(DashPfx+"RCF",
        conf?"✓  ALL ALIGNED":"✗  CONFLICT",
        conf?C'0,215,130':C'255,110,50');

   // EMA values
   UpdV(DashPfx+"E8",   DoubleToString(ema8_5M[1],  digs), C'255,170,35');
   UpdV(DashPfx+"E21",  DoubleToString(ema21_5M[1], digs), C'65,185,255');
   UpdV(DashPfx+"E200", DoubleToString(ema200_5M[1],digs), C'255,70,90');
   bool e8above = ema8_5M[1] > ema21_5M[1];
   UpdV(DashPfx+"EPOS",
        e8above?"8 ABOVE 21  ▲":"8 BELOW 21  ▼",
        e8above?C'0,215,130':C'255,70,70');

   // Signal logic
   bool sessOk = !InpUseSession || IsSessionActive();
   bool spdOk  = SpreadOK();
   string sig="WAITING"; color sigC=C'160,160,55'; string typ="---";

   if(!sessOk)           { sig="NO SESSION";  sigC=C'75,85,110'; }
   else if(!spdOk)       { sig="SPREAD HIGH"; sigC=C'200,100,35'; }
   else if(!conf)        { sig="NO CONF.";    sigC=C'180,100,35'; }
   else if(CooldownActive()){sig="COOLDOWN";  sigC=C'200,150,35'; }
   else if(t5M==TREND_UP)
   {
      bool pb=InpUsePullback&&IsPullbackBuy();
      bool bo=InpUseBreakout&&IsBreakoutBuy();
      bool sr=InpUseSR&&IsSR_Buy();
      if(pb||bo||sr){ sig="▲  BUY  SIGNAL"; sigC=C'0,235,130'; typ=pb?"Pullback":bo?"Breakout":"S&R Zone"; }
      else          { sig="▲ BULL  SETUP";  sigC=C'0,155,90'; }
   }
   else if(t5M==TREND_DOWN)
   {
      bool pb=InpUsePullback&&IsPullbackSell();
      bool bo=InpUseBreakout&&IsBreakoutSell();
      bool sr=InpUseSR&&IsSR_Sell();
      if(pb||bo||sr){ sig="▼  SELL SIGNAL"; sigC=C'255,70,70'; typ=pb?"Pullback":bo?"Breakout":"S&R Zone"; }
      else          { sig="▼ BEAR  SETUP";  sigC=C'180,60,60'; }
   }
   UpdV(DashPfx+"SIG",sig,sigC);
   UpdV(DashPfx+"TYP",typ,C'60,65,80');

   // Market
   UpdV(DashPfx+"ATR",DoubleToString(atr,digs),clrBlack);
   UpdV(DashPfx+"SPR",DoubleToString(spread,digs),
        spread>atr*0.3?C'255,110,50':C'0,200,125');
   UpdV(DashPfx+"SES",ActiveSession(),
        ActiveSession()=="OFF"?C'75,85,110':C'0,215,130');

   // Account
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double eq =AccountInfoDouble(ACCOUNT_EQUITY);
   double pnl=eq-bal;
   int    trds=CountMyTrades();
   UpdV(DashPfx+"OPN",IntegerToString(trds)+" / "+IntegerToString(InpMaxTrades),
        trds>0?C'65,185,255':clrBlack);
   UpdV(DashPfx+"CDN",CooldownActive()?"ACTIVE":"OFF",
        CooldownActive()?C'255,170,35':C'75,85,110');
   UpdV(DashPfx+"BAL",DoubleToString(bal,2),clrBlack);
   UpdV(DashPfx+"EQT",DoubleToString(eq,2),clrBlack);
   UpdV(DashPfx+"PNL",(pnl>=0?"+":"")+DoubleToString(pnl,2),
        pnl>=0?C'0,215,130':C'255,70,70');

   ChartRedraw();
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
   Lbl(pfx+"_L",x+10, y,label,"Arial",    8,C'60,65,80');
   Lbl(pfx+"_V",x+125,y,val,  "Arial Bold",8,clrBlack);
}

void UpdV(string pfx,string txt,color clr)
{
   string n=pfx+"_V";
   if(ObjectFind(0,n)>=0)
   { ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr); }
}

void DeleteDashboard(){ ObjectsDeleteAll(0,DashPfx); ChartRedraw(); }

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
