//+------------------------------------------------------------------+
//|                                              position_sizing.mqh |
//|                        Copyright 2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict

#include <zts\daily_pnl.mqh>
#include <zts\log_defines.mqh>
#include <zts\common.mqh>
#include <zts\help_tools.mqh>

double CalcTradeSize(Account *_account, double _stopLoss, double percent2risk=0.5) {
  Debug("Calculating position sizing");
  double freeMargin = _account.freeMargin();    //  AccountFreeMargin() 
  double dollarRisk = (freeMargin + LockedInProfit()) * percent2risk/100.0;
  //double oneR = _stopLoss * BaseCcyTickValue * points2decimal_factor(Symbol());
  double oneR = _stopLoss * BaseCcyTickValue;
 
  Print("percent2ris=",percent2risk);
  Print("freeMargin=",freeMargin);   // 10,000
  Print("dollarRisk=",dollarRisk);   // 10,000
  Print("_stopLoss=",_stopLoss);     // 10
  Print("BaseCcyTickValue=",BaseCcyTickValue);  // 1
  Print("OnePoint=",DoubleToString(OnePoint,8));   // 
  Print("Point=",DoubleToString(Point,8));   // 0.00001
  Print("points2decimal_factor("+Symbol()+")=",DoubleToString(points2decimal_factor(Symbol()),8));   // 0.00001
  Print("oneR=",oneR);
 
  double lotSize = dollarRisk / oneR / 100000.0;
  //Print("lotSize=",lotSize);
  lotSize=MathRound(lotSize/MarketInfo(Symbol(),MODE_LOTSTEP)) * MarketInfo(Symbol(),MODE_LOTSTEP);

  //ShowSymbolProperties();
  
  /**
  //If the digits are 3 or 5 we normalize multiplying by 10
  if(Digits==3 || Digits==5)
  {
    nTickValue=nTickValue*10;
    stopLossPips = stopLossPips / 10;
  }    
  
  if(DEBUG()) { 
     string str = "Account free margin = " + string(AccountFreeMargin()) + "\n"
        "point value in the quote currency = " + DoubleToString(Point,5) + "\n"
        "broker lot size = " + string(MarketInfo(Symbol(),MODE_LOTSTEP)) + "\n"
        "PercentRiskPerPosition = " + string(percent2risk*100.0) + "%" + "\n"
        "dollarRisk = " + string(dollarRisk) + "\n"
        "stop loss = " + string(_stopLoss) +", " + string(stopLossPips) + " pips" + "\n"
        //"locked in = " + string(LockedInPips()) + "(pips)\n"
        "LotSize = " + string(LotSize) + "\n"
        "Ask = " + string(Ask) + "\n"
        "Bid = " + string(Bid) + "\n"
        "Close = " + string(Close[0]) + "\n"
        "MarketInfo(Symbol(),MODE_TICKVALUE) = " + string(MarketInfo(Symbol(),MODE_TICKVALUE));
    Debug(str);
  }
  **/
  return(lotSize);
}


/**
double CalcTradeSize(double stopLoss, double PercentRiskPerPosition=0.5)
{
  double dollarRisk = (AccountFreeMargin()+ LockedIn()) * PercentRiskPerPosition/100.0;

  double nTickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
  double LotSize = dollarRisk /(stopLoss * nTickValue);
  Debug("Calculating position sizing");
  //Debug(LotSize + " = " + dollarRisk + " /(" + stopLoss + " * " + nTickValue + ")");
  LotSize = LotSize * Point;
  LotSize=MathRound(LotSize/MarketInfo(Symbol(),MODE_LOTSTEP)) * MarketInfo(Symbol(),MODE_LOTSTEP);

  return(LotSize);
}
**/