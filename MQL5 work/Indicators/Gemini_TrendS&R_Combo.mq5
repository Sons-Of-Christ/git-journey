//+------------------------------------------------------------------+
//|                                        Gemini_TrendS&R_Combo.mq5 |
//|                                                   Sons-Of-Christ |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Sons-Of-Christ"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

// Plot EMAs
#property indicator_label1  "EMA 20"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  1

#property indicator_label2  "EMA 50"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  1

#property indicator_label3  "EMA 200"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_width3  2

// Input Parameters
input int      EmaFastPeriod       = 20;
input int      EmaMediumPeriod     = 50;
input int      EmaSlowPeriod       = 200;
input int      HighestLowestPeriod = 20; // Period to find S/R levels

// Indicator Buffers
double Ema20Buffer[];
double Ema50Buffer[];
double Ema200Buffer[];

// Handles
int ema20Handle;
int ema50Handle;
int ema200Handle;

// Global variables for S/R
datetime lastResTime = 0;
datetime lastSupTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, Ema20Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, Ema50Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, Ema200Buffer, INDICATOR_DATA);
   
   // Initialize EMA Handles
   ema20Handle  = iMA(_Symbol, _Period, EmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   ema50Handle  = iMA(_Symbol, _Period, EmaMediumPeriod, 0, MODE_EMA, PRICE_CLOSE);
   ema200Handle = iMA(_Symbol, _Period, EmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ema20Handle == INVALID_HANDLE || ema50Handle == INVALID_HANDLE || ema200Handle == INVALID_HANDLE)
   {
      Print("Failed to create handles for EMAs.");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   // Fill EMA buffers
   if(CopyBuffer(ema20Handle, 0, 0, rates_total, Ema20Buffer) < 0) return(0);
   if(CopyBuffer(ema50Handle, 0, 0, rates_total, Ema50Buffer) < 0) return(0);
   if(CopyBuffer(ema200Handle, 0, 0, rates_total, Ema200Buffer) < 0) return(0);

   int limit = rates_total - prev_calculated;
   if(limit > 1) limit = rates_total - HighestLowestPeriod - 1;

   // Loop to identify dynamic Support/Resistance and Breakouts
   for(int i = limit; i >= 0; i--)
   {
      if(i >= rates_total - HighestLowestPeriod) continue;

      // Find Swing High / Low for Resistance and Support
      int highestIdx = ArrayMaximum(high, i, HighestLowestPeriod);
      int lowestIdx  = ArrayMinimum(low, i, HighestLowestPeriod);
      
      double currentResistance = high[highestIdx];
      double currentSupport    = low[lowestIdx];

      // Identify Trend Direction
      bool isBullish = (close[i] > Ema20Buffer[i]) && (Ema20Buffer[i] > Ema50Buffer[i]) && (Ema50Buffer[i] > Ema200Buffer[i]);
      bool isBearish = (close[i] < Ema20Buffer[i]) && (Ema20Buffer[i] < Ema50Buffer[i]) && (Ema50Buffer[i] < Ema200Buffer[i]);

      // Simple Breakout / Retest Visual Strings on Chart Comment
      if(i == 0) // Current bar processing
      {
         string trendStr = "Neutral";
         if(isBullish) trendStr = "Strong Bullish Trend";
         if(isBearish) trendStr = "Strong Bearish Trend";
         
         string signalStr = "Scanning Market Setup...";
         
         // Resistance Breakout
         if(close[1] > currentResistance && open[1] <= currentResistance)
            signalStr = "BULLISH BREAKOUT detected!";
         // Support Breakout
         else if(close[1] < currentSupport && open[1] >= currentSupport)
            signalStr = "BEARISH BREAKOUT detected!";
         // Retest / Pullback to 20/50 EMA
         else if(isBullish && low[0] <= Ema20Buffer[0] && close[0] > Ema20Buffer[0])
            signalStr = "Bullish Pullback/Retest Zone (20 EMA)";
         else if(isBearish && high[0] >= Ema20Buffer[0] && close[0] < Ema20Buffer[0])
            signalStr = "Bearish Pullback/Retest Zone (20 EMA)";

         Comment("====== Market Condition ======\n",
                 "Trend Bias: ", trendStr, "\n",
                 "Current Res: ", DoubleToString(currentResistance, _Digits), "\n",
                 "Current Sup: ", DoubleToString(currentSupport, _Digits), "\n",
                 "Action Zone: ", signalStr);
                 
         // Draw dynamic lines on the chart for visual aid
         ObjectDelete(0, "CurrentResistanceLine");
         ObjectDelete(0, "CurrentSupportLine");
         
         ObjectCreate(0, "CurrentResistanceLine", OBJ_TREND, 0, time[HighestLowestPeriod], currentResistance, time[0], currentResistance);
         ObjectSetInteger(0, "CurrentResistanceLine", OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, "CurrentResistanceLine", OBJPROP_STYLE, STYLE_DOT);
         
         ObjectCreate(0, "CurrentSupportLine", OBJ_TREND, 0, time[HighestLowestPeriod], currentSupport, time[0], currentSupport);
         ObjectSetInteger(0, "CurrentSupportLine", OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, "CurrentSupportLine", OBJPROP_STYLE, STYLE_DOT);
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Indicator deinitialization                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "CurrentResistanceLine");
   ObjectDelete(0, "CurrentSupportLine");
   Comment("");
}