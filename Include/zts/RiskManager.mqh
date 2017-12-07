//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//+------------------------------------------------------------------+
#property strict

extern string _dummy1 = "=== RiskManager Params ===";
extern int RiskModel = 1;
extern int TrailingStopModel = 2;
extern double Percent2risk = 0.5;
extern double MinStopLossDeltaPips = 2.0;
extern ENUM_TIMEFRAMES ATRperiod = 0;
extern int ATRnumBars = 3;
extern double ATRfactor = 2.7;

#include <zts\account.mqh>

class RiskManager {
private:
  string symbol;
  int EquityModel;
  int RiskModel;
  Account *account;

  int oneR_calc_PATI();
  double oneR_calc_ATR(int,int);

  double availableFunds();

public:
  RiskManager(const int=1, const int=1);
  ~RiskManager();

  double oneRpips();
  double calcStopLoss(string,int);
  double getTrailingStop(string,int);
};

RiskManager::RiskManager(const int _equityModel=1, const int _riskModel=1) {
  symbol = Symbol();
  EquityModel = _equityModel;
  RiskModel = _riskModel;
  account = new Account();
}
RiskManager::~RiskManager() {
  if (CheckPointer(account) == POINTER_DYNAMIC) delete account;
}

double RiskManager::oneRpips() {
  double pips;

  switch (RiskModel) {
    case 1:
      pips = double(oneR_calc_PATI());
      break;
    case 2:
      pips = oneR_calc_ATR(ATRperiod,ATRnumBars);
      break;
    default:
      pips=0;
  }
  return(pips);
}

double RiskManager::availableFunds() {
  double dollars;

  switch(EquityModel){
    case 1:
      dollars = account.freeMargin();
      break;
    default:
      dollars = 0.0;
  }
  return(dollars);
}

int RiskManager::oneR_calc_PATI() {
  int __defaultStopPips = 12;
  string __exceptionPairs = "EURUSD/8;AUDUSD,GBPUSD,EURJPY,USDJPY,USDCAD/10";
  
  int stop = __defaultStopPips;
  int pairPosition = StringFind(__exceptionPairs, symbol, 0);
  if (pairPosition >=0) {
     int slashPosition = StringFind(__exceptionPairs, "/", pairPosition) + 1;
     stop =int( StringToInteger(StringSubstr(__exceptionPairs,slashPosition)));
  }
  return stop;
}

double RiskManager::oneR_calc_ATR(int _period, int _numBars) {
  double atr = iATR(symbol,     // symbol
                    _period,     // timeframe
                    _numBars,    // averaging period
                    0);          // shift
  Debug("MODE_DIGITS="+MarketInfo(symbol, MODE_DIGITS));
  atr = NormalizeDouble(atr, int(MarketInfo(symbol, MODE_DIGITS)-1));
  Alert("atr "+string(_numBars)+" bars. period = "+string(_period)+"  atr="+string(atr));
  /*0    Current timeframe
    PERIOD_M1       1        1 minute
    PERIOD_M5       5        5 minutes
    PERIOD_M15     15       15 minutes
    PERIOD_M30     30       30 minutes
    PERIOD_H1      60        1 hour
    PERIOD_H4     240        4 hours
    PERIOD_D1    1440        1 day
    PERIOD_W1   10080        1 week
    PERIOD_MN1  43200        1 month
  */
  return(atr);
}

/*
double RiskManager::calcStopLoss(string side) {
  double stopLoss;
  double freeMargin = account.freeMargin();    //  AccountFreeMargin()
  double dollarRisk = (freeMargin + LockedInProfit()) * Percent2risk/100.0;
  double oneR = oneRpips() * BaseCcyTickValue;
  double lotSize = dollarRisk / oneR * Point;

   lotSize=MathRound(lotSize/MarketInfo(Symbol(),MODE_LOTSTEP)) * MarketInfo(Symbol(),MODE_LOTSTEP);
   
  return(stopLoss);
}
*/

double RiskManager::calcStopLoss(string side, int oneR) {
  int signAdj = 1;
  double currentPrice = Ask;
  double newTrailingStop = 9999.99;
  double pips;
  //double stopLoss;
  
  Debug("Side="+side+"  oneR="+oneR+"  Bid = "+Bid+"   Ask="+Ask);
  if(StringCompare(side,"LONG",false)==0) {
    Debug("Long trade");
    currentPrice = Bid;
    signAdj = -1;
    newTrailingStop = 0.00;
  }
  
  Debug("TralingStopModel="+TrailingStopModel);
  switch (TrailingStopModel) {
    case 0:     // No trailing stop
      pips = 0.0;
      break;
    case 1:     // by oneR
      pips = oneR;
      break;
    case 2:     // current ATR
      pips = oneR_calc_ATR(ATRperiod,ATRnumBars)*decimal2points_factor(symbol)*3.0;
      Debug("trailing stop pips = "+pips);
      break;
    default:
      pips=0;
  }
  if(StringCompare(side,"LONG",false)==0) currentPrice = Bid;
  if(StringCompare(side,"SHORT",false)==0) currentPrice = Ask;
  Debug("newTrailingStop = currentPrice + pips * OnePoint * signAdj");
  Debug(newTrailingStop+" = "+currentPrice+" + "+pips+" * "+OnePoint+" * "+signAdj);
  newTrailingStop = currentPrice + pips * OnePoint * signAdj;
  Debug("newTrailingStop="+newTrailingStop);
/*
  if(side == "Long")
    stopLoss = MathMax(stopLoss,newTrailingStop);
  else if(side == "Short")
    stopLoss = MathMin(stopLoss,newTrailingStop);
  else
    stopLoss = -1.0;
*/    
  return(newTrailingStop); 
}

double RiskManager::getTrailingStop(string side, int oneR) {
  Debug("getTrailingStop:  side="+side+"  oneR="+oneR);
  double newStopLoss = calcStopLoss(side,oneR);
  Debug(__FUNCTION__+": side="+side+"   newStopLoss="+newStopLoss);
  double currStopLoss = OrderStopLoss();
  if(StringCompare(side,"LONG",false)==0) {
    Debug("Long: "+newStopLoss+"-"+currStopLoss+" >= "+MinStopLossDeltaPips+" * "+BaseCcyTickValue+" * "+OnePoint); 
    if(newStopLoss-currStopLoss >= MinStopLossDeltaPips * BaseCcyTickValue * OnePoint) 
      return(newStopLoss);
  } else if(StringCompare(side,"SHORT",false)==0) {
    Debug("Short: "+currStopLoss+"-"+newStopLoss+" >= "+MinStopLossDeltaPips+" * "+BaseCcyTickValue+" * "+OnePoint); 
    if(currStopLoss-newStopLoss >= MinStopLossDeltaPips * BaseCcyTickValue * OnePoint) 
      return(newStopLoss);
  } else
    Warn("Side: "+side+" NOT known !");
  return(-1);
}