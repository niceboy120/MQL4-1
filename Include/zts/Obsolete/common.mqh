//+------------------------------------------------------------------+
//|                                                       common.mqh |
//|                        Copyright 2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict


int GetSlippage() {
  if(Digits() == 2 || Digits() == 4)
    return(Slippage);
  else if(Digits() == 3 || Digits() ==5)
    return(Slippage*10);
  return(Digits());
}

double CommonSetPoint() {
  return((Digits==5||Digits==3)?Point*10:Point);
}

double CommonSetPipAdj() {
  //if(Digits==5||Digits==3) return(10);
  //return(1);
  return(0.1);
}
double pips2dollars(string sym, double pips, double lots) {
   double result;
   result = pips * lots * (1 / MarketInfo(sym, MODE_POINT)) * MarketInfo(sym, MODE_TICKVALUE);
   return ( result );
}

int decimal2points_factor(string sym) {
  int factor = 10000;
  if(StringFind(sym,"JPY",0)>0) factor = 100;         // JPY pairs
  Debug(__FUNCTION__+": sym="+sym+"  factor="+string(factor)); 
  return factor;
}

double points2decimal_factor(string sym) {
  double factor = 1.0/10000.0;
  if(StringFind(sym,"JPY",0)>0) factor = 1.0/100.0;         // JPY pairs
  Debug(__FUNCTION__+" "+sym+": factor="+string(factor));
  return factor;
}

#ifndef ZCOMMON
#define ZCOMMON

double OnePoint = CommonSetPoint();
double PipAdj = CommonSetPipAdj();
int UseSlippage = GetSlippage();

double BaseCcyTickValue = MarketInfo(Symbol(),MODE_TICKVALUE); // Tick value in the deposit currency
// Point - The current symbol point value in the quote currency
// MODE_POINT - Point size in the quote currency. For the current symbol, it is stored in the predefined variable Point

#endif

enum Enum_YESNO {
  YN_NO=0,    //No
  YN_YES      //Yes
};
enum Enum_ENTRY_MODELS {
  EM_BidAsk=0,    //Enter long at Ask, short at Bid (pip buffer)
  EM_Pullback,      //Enter on Pullback to prev H/L (bar offset)
  EM_RBO            //RBO of current session (w/ pip offset)
};
enum Enum_MARKET_MODELS{
  MM_200DMA=0,   //200 DMA Market Indicator
  MM_MidPoint=1  //Range MidPoint Market Indicator
};

enum Enum_SIDE{ Long=1, Short=-1 };
enum Enum_OP_ORDER_TYPES { 
  Z_BUY=0,        //Buy operation
  Z_SELL=1,       //Sell operation
  Z_BUYLIMIT=2,   //Buy limit pending order
  Z_SELLLIMIT=3,  //Sell limit pending order
  Z_BUYSTOP=4,    //Buy stop pending order
  Z_SELLSTOP=5,   //Sell stop pending order
};
enum Enum_EXITMODEL {
  EX_Fitch,    // Fitch strategy
  EX_SL_TP     // use stop loss and limit orders
};
enum Enum_TRAILING_STOP_TYPES { 
  TS_None=0,    // Not Applicable
  TS_PrevHL=1,  // Previous Hi/Lo
  TS_ATR=2,     // ATR factor
  TS_OneR=3,    // One R pips
};
enum Enum_PROFIT_TARGET_TYPES { 
  PT_None=0,         // Not Applicable
  PT_PrevHL=1,       // Previous Hi/Lo
  PT_ATR=2,          // ATR factor
  PT_OneR=3,         // One R factor
  PT_PATI_Level=4,   // next PATI level
};

//#include <zts/logger.mqh>

/****
#ifndef LOGGING
#define LOGGING
enum Enum_LogLevels{
  LogAlert,
  LogWarn,
  LogInfo,
  LogDebug
};

#ifndef LOG
//#define LOG(level,text)  Print(__FILE__,"(",__LINE__,") :",text)
#define LOG(level,text)  Print(level+": ",text)
#define LOG2(level,func,line,text)  Print(level+"::"+func+"("+IntegerToString(line)+"): ",text)
#endif
  bool DEBUG() { return(LogLevel>=LogDebug?true:false); }
  bool DEBUG0() { return(true); }
  bool DEBUG1() { return(true); }
  bool DEBUG2() { return(true); }
  bool DEBUG3() { return(true); }
  bool DEBUG4() { return(true); }

  bool INFO() { return(LogLevel>=LogInfo?true:false); }
  bool WARN() { return(LogLevel>=LogInfo?true:false); }

  void Warn(string msg)  { if(WARN())  LOG("WARN",msg); }
  void Info(string msg)  { if(INFO())  LOG("INFO",msg); }
  void Debug(string msg) { if(DEBUG()) LOG("DEBUG",msg); }
  void Debug0(string msg) { if(DEBUG0()) LOG("DEBUG",msg); }
  void Debug1(string msg) { if(DEBUG1()) LOG("DEBUG",msg); }
  void Debug2(string msg) { if(DEBUG2()) LOG("DEBUG",msg); }
  void Debug3(string msg) { if(DEBUG3()) LOG("DEBUG",msg); }
  void Debug4(string f,int l,string msg) { if(DEBUG3()) LOG2("DEBUG",f,l,msg); }
  void Zalert(string msg) { Alert(msg); }
#endif

void SetLogLevel(Enum_LogLevels level) {
  LogLevel = level;
}
****/


/**
enum ENUM_PERSISTER {
  GlobalVar,
  File
 }; 
 **/ 
