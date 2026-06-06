//+------------------------------------------------------------------+
//|           Session Momentum Alignment Indicator                   |
//|           Tracks pre-open candle bias vs open candle             |
//|           Sessions: Tokyo, London, New York, NY Noon             |
//|           All times in SAST (GMT+2)                              |
//+------------------------------------------------------------------+
#property copyright   "Nick"
#property version     "1.10"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

#property indicator_label1  "London Bullish Align"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "London Bearish Align"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

#property indicator_label3  "NewYork Bullish Align"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

#property indicator_label4  "NewYork Bearish Align"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrange
#property indicator_style4  STYLE_SOLID
#property indicator_width4  3

#property indicator_label5  "Tokyo Bullish Align"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrMagenta
#property indicator_style5  STYLE_SOLID
#property indicator_width5  3

#property indicator_label6  "Tokyo Bearish Align"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrGold
#property indicator_style6  STYLE_SOLID
#property indicator_width6  3

#property indicator_label7  "NYNoon Bullish Align"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrCyan
#property indicator_style7  STYLE_SOLID
#property indicator_width7  3

#property indicator_label8  "NYNoon Bearish Align"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrTomato
#property indicator_style8  STYLE_SOLID
#property indicator_width8  3

//--- Inputs
input int    InpLookback        = 2;     // Pre-open candles to check
input int    InpLondonHour      = 9;    // London Open Hour (SAST)
input int    InpNewYorkHour     = 16;    // New York Open Hour (SAST)
input int    InpTokyoHour       = 2;     // Tokyo Open Hour (SAST)
input int    InpNYNoonHour      = 21;    // NY Noon Session Hour (SAST)
input bool   InpShowStats       = true;  // Show alignment stats

//--- Buffers
double LondonBull[];
double LondonBear[];
double NYBull[];
double NYBear[];
double TokyoBull[];
double TokyoBear[];
double NYNoonBull[];
double NYNoonBear[];

//--- Stats
int londonBullCount=0, londonBearCount=0, londonMissCount=0;
int nyBullCount=0,     nyBearCount=0,     nyMissCount=0;
int tokyoBullCount=0,  tokyoBearCount=0,  tokyoMissCount=0;
int noonBullCount=0,   noonBearCount=0,   noonMissCount=0;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, LondonBull,  INDICATOR_DATA);
   SetIndexBuffer(1, LondonBear,  INDICATOR_DATA);
   SetIndexBuffer(2, NYBull,      INDICATOR_DATA);
   SetIndexBuffer(3, NYBear,      INDICATOR_DATA);
   SetIndexBuffer(4, TokyoBull,   INDICATOR_DATA);
   SetIndexBuffer(5, TokyoBear,   INDICATOR_DATA);
   SetIndexBuffer(6, NYNoonBull,  INDICATOR_DATA);
   SetIndexBuffer(7, NYNoonBear,  INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetInteger(2, PLOT_ARROW, 233);
   PlotIndexSetInteger(3, PLOT_ARROW, 234);
   PlotIndexSetInteger(4, PLOT_ARROW, 233);
   PlotIndexSetInteger(5, PLOT_ARROW, 234);
   PlotIndexSetInteger(6, PLOT_ARROW, 233);
   PlotIndexSetInteger(7, PLOT_ARROW, 234);

   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -10);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT,  10);
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, -20);
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT,  20);
   PlotIndexSetInteger(4, PLOT_ARROW_SHIFT, -30);
   PlotIndexSetInteger(5, PLOT_ARROW_SHIFT,  30);
   PlotIndexSetInteger(6, PLOT_ARROW_SHIFT, -40);
   PlotIndexSetInteger(7, PLOT_ARROW_SHIFT,  40);

   for(int p=0; p<8; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, 0.0);

   IndicatorSetString(INDICATOR_SHORTNAME, "Session Momentum Alignment (SAST)");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
int GetSASTHour(datetime barTime)
  {
   int brokerOffsetSeconds = (int)(TimeCurrent() - TimeGMT());
   datetime gmtTime  = barTime - brokerOffsetSeconds;
   datetime sastTime = gmtTime + 2 * 3600;
   MqlDateTime dt;
   TimeToStruct(sastTime, dt);
   return dt.hour;
  }

//+------------------------------------------------------------------+
int CheckPreOpenAlignment(int idx, const double &open[], const double &close[])
  {
   if(idx + InpLookback >= ArraySize(open)) return 0;
   int bulls=0, bears=0;
   for(int i=1; i<=InpLookback; i++)
     {
      if(close[idx+i] > open[idx+i]) bulls++;
      else if(close[idx+i] < open[idx+i]) bears++;
     }
   if(bulls == InpLookback) return  1;
   if(bears == InpLookback) return -1;
   return 0;
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(prev_calculated == 0)
     {
      londonBullCount=londonBearCount=londonMissCount=0;
      nyBullCount=nyBearCount=nyMissCount=0;
      tokyoBullCount=tokyoBearCount=tokyoMissCount=0;
      noonBullCount=noonBearCount=noonMissCount=0;
     }

   int start = (prev_calculated == 0) ? InpLookback : prev_calculated - 1;

   for(int i=start; i<rates_total; i++)
     {
      LondonBull[i]=LondonBear[i]=0.0;
      NYBull[i]=NYBear[i]=0.0;
      TokyoBull[i]=TokyoBear[i]=0.0;
      NYNoonBull[i]=NYNoonBear[i]=0.0;

      int  sast     = GetSASTHour(time[i]);
      bool isLondon = (sast == InpLondonHour);
      bool isNY     = (sast == InpNewYorkHour);
      bool isTokyo  = (sast == InpTokyoHour);
      bool isNoon   = (sast == InpNYNoonHour);

      if(!isLondon && !isNY && !isTokyo && !isNoon) continue;

      bool bull    = (close[i] > open[i]);
      bool bear    = (close[i] < open[i]);
      int  preAlign = CheckPreOpenAlignment(i, open, close);

      if(isLondon)
        {
         if(preAlign==1  && bull) { LondonBull[i]=low[i];  londonBullCount++; }
         else if(preAlign==-1 && bear) { LondonBear[i]=high[i]; londonBearCount++; }
         else if(preAlign!=0) londonMissCount++;
        }
      if(isNY)
        {
         if(preAlign==1  && bull) { NYBull[i]=low[i];  nyBullCount++; }
         else if(preAlign==-1 && bear) { NYBear[i]=high[i]; nyBearCount++; }
         else if(preAlign!=0) nyMissCount++;
        }
      if(isTokyo)
        {
         if(preAlign==1  && bull) { TokyoBull[i]=low[i];  tokyoBullCount++; }
         else if(preAlign==-1 && bear) { TokyoBear[i]=high[i]; tokyoBearCount++; }
         else if(preAlign!=0) tokyoMissCount++;
        }
      if(isNoon)
        {
         if(preAlign==1  && bull) { NYNoonBull[i]=low[i];  noonBullCount++; }
         else if(preAlign==-1 && bear) { NYNoonBear[i]=high[i]; noonBearCount++; }
         else if(preAlign!=0) noonMissCount++;
        }
     }

   if(InpShowStats)
     {
      int lT=londonBullCount+londonBearCount+londonMissCount;
      int nT=nyBullCount+nyBearCount+nyMissCount;
      int tT=tokyoBullCount+tokyoBearCount+tokyoMissCount;
      int nnT=noonBullCount+noonBearCount+noonMissCount;

      double lP =(lT >0)?100.0*(londonBullCount+londonBearCount)/lT :0;
      double nP =(nT >0)?100.0*(nyBullCount+nyBearCount)/nT         :0;
      double tP =(tT >0)?100.0*(tokyoBullCount+tokyoBearCount)/tT   :0;
      double nnP=(nnT>0)?100.0*(noonBullCount+noonBearCount)/nnT    :0;

      Comment(StringFormat(
         "=== Session Momentum Alignment (SAST/GMT+2) ===\n"
         "Lookback: %d pre-open candles\n"
         "London   (09:00) | Bull: %d  Bear: %d  Miss: %d  Align: %.1f%%\n"
         "New York (16:00) | Bull: %d  Bear: %d  Miss: %d  Align: %.1f%%\n"
         "Tokyo    (02:00) | Bull: %d  Bear: %d  Miss: %d  Align: %.1f%%\n"
         "NY Noon  (21:00) | Bull: %d  Bear: %d  Miss: %d  Align: %.1f%%",
         InpLookback,
         londonBullCount, londonBearCount, londonMissCount, lP,
         nyBullCount,     nyBearCount,     nyMissCount,     nP,
         tokyoBullCount,  tokyoBearCount,  tokyoMissCount,  tP,
         noonBullCount,   noonBearCount,   noonMissCount,   nnP));
     }

   return(rates_total);
  }

void OnDeinit(const int reason)
  {
   Comment("");
   ObjectsDeleteAll(0, "SMA_");
  }
