//+------------------------------------------------------------------+
//|                                                      MTF_CVD.mq5 |
//|                             Multi-Timeframe Volume Delta (CVD)   |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

// 1. Histogram Plot
#property indicator_label1  "CVD Histogram"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrSeaGreen, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// 2. Trend Line Plot
#property indicator_label2  "CVD Line"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Allow user to pick between Forex (Tick) and Centralized Markets (Real)
enum ENUM_VOLUME_TYPE {
    VOL_TICK = 0, // Tick Volume
    VOL_REAL = 1  // Real Volume
};

// Indicator Inputs
input ENUM_TIMEFRAMES    InpTimeFrame = PERIOD_CURRENT; // Timeframe Filter
input ENUM_VOLUME_TYPE   InpVolumeType = VOL_TICK;      // Volume Type

// Data Buffers
double CVDHist[];
double CVDColors[];
double CVDLine[];
double DummyBuffer[]; 

int OnInit()
  {
   // Bind buffers to the chart plots
   SetIndexBuffer(0, CVDHist, INDICATOR_DATA);
   SetIndexBuffer(1, CVDColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, CVDLine, INDICATOR_DATA);
   SetIndexBuffer(3, DummyBuffer, INDICATOR_CALCULATIONS);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "MTF CVD");
   
   return(INIT_SUCCEEDED);
  }

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
   if(rates_total < 2) return 0;
   
   // Set arrays to read from newest (index 0) to oldest
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(CVDHist, true);
   ArraySetAsSeries(CVDLine, true);
   ArraySetAsSeries(CVDColors, true);
   
   ENUM_TIMEFRAMES tf = (InpTimeFrame == PERIOD_CURRENT) ? Period() : InpTimeFrame;
   
   // Calculate how many bars need to be updated to save CPU
   int limit = rates_total - prev_calculated;
   if(prev_calculated == 0)
     {
      limit = rates_total - 1;
      ArrayInitialize(CVDHist, 0.0);
      ArrayInitialize(CVDLine, 0.0);
     }
     
   // --- Fetch Higher Timeframe Data ---
   int htf_bars = iBars(Symbol(), tf);
   if(htf_bars == 0) return 0;
   
   MqlRates htf_rates[];
   int copied = CopyRates(Symbol(), tf, 0, htf_bars, htf_rates); 
   if(copied <= 0) return 0;
   
   // --- Calculate Cumulative Delta on the Higher Timeframe ---
   double cvd_array[];
   ArrayResize(cvd_array, copied);
   double cumulative = 0.0;
   
   // Loop from oldest bar to newest bar to build the continuous wave
   for(int k = 0; k < copied; k++)
     {
      double o = htf_rates[k].open;
      double c = htf_rates[k].close;
      double v = (InpVolumeType == VOL_TICK) ? (double)htf_rates[k].tick_volume : (double)htf_rates[k].real_volume;
      
      // Assign volume to buyers or sellers
      double buyVol = (c > o) ? v : ((c == o) ? v / 2.0 : 0.0);
      double sellVol = (c < o) ? v : ((c == o) ? v / 2.0 : 0.0);
      
      cumulative += (buyVol - sellVol);
      cvd_array[k] = cumulative;
     }
     
   // --- Map the Higher Timeframe Data Down to the Current Chart ---
   for(int i = limit; i >= 0; i--)
     {
      // Find the exact higher timeframe bar that matches the current lower timeframe bar
      int shift = iBarShift(Symbol(), tf, time[i], false);
      if(shift < 0 || shift >= copied) continue;
      
      // Convert the shift index to match our cvd_array
      int htf_index = copied - 1 - shift;
      double currentCVD = cvd_array[htf_index];
      
      // Plot the data
      CVDHist[i] = currentCVD;
      CVDLine[i] = currentCVD;
      
      // Determine color: Green if buyers are pushing higher, Red if sellers are taking over
      double prevCVD = (i == rates_total - 1) ? currentCVD : CVDHist[i + 1];
      CVDColors[i] = (currentCVD > prevCVD) ? 0 : 1; 
     }
     
   return rates_total;
  }