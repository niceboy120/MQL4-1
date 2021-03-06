//+------------------------------------------------------------------+
//|                                       PositionSizeCalculator.mq4 |
//|                             Copyright © 2012-2016, Andriy Moraru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012-2016, Andriy Moraru"
#property link      "https://www.earnforex.com/metatrader-indicators/Position-Size-Calculator/#Legacy_version"
#property version   "1.29"

#property description "Calculates position size based on account balance/equity,"
#property description "currency, currency pair, given entry level, stop-loss level"
#property description "and risk tolerance (set either in percentage points or in base currency)."
#property description "Can display reward/risk ratio based on take-profit."
#property description "Can also show total portfolio risk based on open trades and pending orders."
#property description "2016-12-23, ver. 1.29 - fixed some bugs, errors, and compatibility issues."
// 2016-08-05, ver. 1.28 - fixed TP line deleteion in Separate Window version.
// 2016-06-15, ver. 1.27 - added label color inputs, objects non-selectable.
// 2015-12-12, ver. 1.26 - added DrawTextAsBackground parameter, fixed minor bugs.
// 2015-12-01, ver. 1.25 - fixed rounding bug.
// 2015-11-30, ver. 1.24 - added pips distance, fixed bugs, simplified things.
// 2015-07-01, ver. 1.23 - fixed SL between Ask/Bid bug, fixed minor bug with colors.
// 2015-04-08, ver. 1.22 - added line height parameter, minor bug fixes.
// 2015-04-04, ver. 1.21 - fixed line width bug.
// 2015-03-19, ver. 1.20 - added input parameters to hide some lines.
// 2015-03-08, ver. 1.19 - commission support, minor bug fixes.
// 2015-02-27, ver. 1.18 - two indicator versions - Separate or Main window.
// 2015-02-16, ver. 1.17 - separate window, input/output values, more warnings.
// 2015-02-13, ver. 1.16 - margin, warnings, number formatting, rounding down.
// 2015-01-30, ver. 1.15 - values read from lines are now rounded. DeleteLines also clears old lines when attaching.
// 2014-12-19, ver. 1.14 - fixed minor bug when restarting MT4; also, lines are no longer hidden from object list.
// 2014-10-03, ver. 1.13 - added portfolio risk calculation.
// 2014-09-17, ver. 1.12 - position size is now rounded down.
// 2014-04-11, ver. 1.11 - added potential reward display and color/style input parameters.
// 2013-11-11, ver. 1.10 - added optional Ask/Bid tracking for Entry line.
// 2013-02-11, ver. 1.8 - completely revamped calculation process.
// 2013-01-14, ver. 1.7 - fixed "division by zero" error.
// 2012-12-10, ver. 1.6 - will use local values if both Entry and SL are missing.
// 2012-11-02, ver. 1.5 - a more intelligent name prefix/postfix detection.
// 2012-10-13, ver. 1.4 - fixed contract size in lot size calculation.
// 2012-10-13, ver. 1.3 - proper lot size calculation for gold, silver and oil.
// 2012-09-29, ver. 1.2 - improved account currency and reference pair detection.
// 2012-05-10, ver. 1.1 - added support for setting risk in money.
#property description "WARNING: There is no guarantee that the output of this indicator is correct. Use at your own risk."

#property indicator_chart_window
#property indicator_plots 0

int second_column_x = 0;
#include "PositionSizeCalculator_Base.mqh"
extern int MaxNumberLength = 10; // How many digits will there be in numbers as maximum?

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
{
   IndicatorShortName("Position Size Calculator");
   Window = 0;
   Initialization();
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete("EntryLevel");
   if (DeleteLines) ObjectDelete("EntryLine");
   ObjectDelete("StopLoss");
   if (DeleteLines) ObjectDelete("StopLossLine");
   if (CommissionPerLot > 0) ObjectDelete("CommissionPerLot");
   ObjectDelete("Risk");
   ObjectDelete("AccountSize");
   ObjectDelete("Divider");
   ObjectDelete("RiskMoney");
   ObjectDelete("PositionSize");
  	ObjectDelete("StopLossLabel");
  	ObjectDelete("TakeProfitLabel");
   if (TakeProfitLevel > 0)
   {
      ObjectDelete("TakeProfit");
      if (DeleteLines) ObjectDelete("TakeProfitLine");
      ObjectDelete("RR");
      ObjectDelete("PotentialProfit");
   }
   if (ShowPortfolioRisk)
   {
      ObjectDelete("CurrentPortfolioMoneyRisk");
      ObjectDelete("CurrentPortfolioRisk");
      ObjectDelete("PotentialPortfolioMoneyRisk");
      ObjectDelete("PotentialPortfolioRisk");
   }
   if (ShowMargin)
   {
      ObjectDelete("PositionMargin");
      ObjectDelete("FutureUsedMargin");
      ObjectDelete("FutureFreeMargin");
   }
}