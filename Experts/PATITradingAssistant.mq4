//+------------------------------------------------------------------+
//|                                         PATITradingAssistant.mq4 |
//|                                                       Dave Hanna |
//|                                http://nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "Dave Hanna"
#property link      "http://nohypeforexrobotreview.com"
#property version   "100.034"
#property strict

#include <stdlib.mqh>
#include <stderror.mqh> 
#include <OrderReliable_2011.01.07.mqh>
#include <Assert.mqh>
#include <Position.mqh>
#include <Broker.mqh>
#include "PTA_Runtests.mqh"
#include <zts\daily_pips.mqh>
#include <zts\daily_pnl.mqh>
#include <zts\trade_tools.mqh>
#include <zts\position_sizing.mqh>

string Title="PATI Trading Assistant"; 
string Prefix="PTA_";
string Version="v0.34z0";
string NTIPrefix = "NTI_";
int DFVersion = 2;


string TextFont="Verdana";
int FiveDig;
double AdjPoint;
int MaxInt=2147483646;
color TextColor=Goldenrod;
int debug = true;
#define DEBUG_EXIT  ((debug & 0x0001) == 0x0001)
#define DEBUG_GLOBAL  ((debug & 0x0002) == 0x0002)
#define DEBUG_ENTRY ((debug & 0x0004) == 0x0004)
#define DEBUG_CONFIG ((debug & 0x0008) == 0x0008)
#define DEBUG_ORDER ((debug & 0x0010) == 0x0010)
#define DEBUG_OANDA ((debug & 0x0020) == 0x0020)
#define DEBUG_TICK  ((debug & 0x0040) == 0x0040)
bool HeartBeat = true;
int rngButtonXOffset = 10;
int rngButtonYOffset = 50;
int rngButtonHeight = 18;
int rngButtonWidth = 150;
string rngButtonName = Prefix + "DrawRangeBtn";

//Configuration variables
extern string General = "===General===";
extern bool Testing = false;
extern int PairOffsetWithinSymbol = 0;
extern bool AlertOnTrade=true;
extern bool MakeTickVisible = false;
extern bool SaveConfiguration = false;
extern string ConfigureStops = "===Configure Stop Loss Levels===";
extern int DefaultStopPips = 12;
extern string ExceptionPairs = "EURUSD/8;AUDUSD,GBPUSD,EURJPY,USDJPY,USDCAD/10";
extern bool SendSLandTPToBroker = true;
extern bool SetLimitsOnPendingOrders = true;
extern bool AdjustStopOnTriggeredPendingOrders = true;
extern string ConfigureDisplay = "===Configure Trade Display===";
extern bool ShowEntry = true;
extern bool ShowInitialStop = true;
extern bool ShowExit = true;
extern bool ShowTradeTrendLine = true;
extern int EntryIndicator = 2;
extern color WinningExitColor = Green;
extern color LosingExitColor = Red;
extern color TradeTrendLineColor = Blue;
extern bool WriteFileTradeStats = true;
extern string ConfigureNoEntryZone = "===Configure No-Entry Zone===";
extern bool ShowNoEntryZone = true;
extern color NoEntryZoneColor = DarkGray;
extern double MinNoEntryPad = 15;
extern string ConfigureTP = "===Configure Take Profit Levels===";
extern bool UseNextLevelTPRule = true;
extern double MinRewardRatio = 1.5;
extern string ConfigureRangeLines = "===Configure Draw Range Lines feature===";
extern bool ShowDrawRangeButton = true;
extern color RangeLinesColor = Yellow;
extern bool SetPendingOrdersOnRanges = true;
extern double MarginForPendingRangeOrders = 1.0;
extern bool AccountForSpreadOnPendingBuyOrders = true;
extern double PendingLotSize = 0.0;
extern bool CancelPendingTrades = true;
extern string TimingRelatedVariables = "===Timing Related Configuration===";
extern int EndOfDayOffsetHours = 0;
extern int BeginningOfDayOffsetHours = 0;
extern string ConfigureScreenShotCapture = "===Configure Screen Shot Capture===";
extern bool CaptureScreenShotsInFiles = true;
extern string ConfigurePositionSizing = "===Configure Position Sizing===";
extern bool PositionSizer = true;
extern double PercentRiskPerPosition = 0.005;
extern bool CalcLockIn = true;

const double  GVUNINIT= -99999999;
const string LASTUPDATENAME = "NTI_LastUpdateTime";
string GVPrefix;

//Copies of configuration variables
bool _testing;
int _pairOffsetWithinSymbol;
int _defaultStopPips;
string _exceptionPairs;
bool _useNextLevelTPRule;
double _minRewardRatio;
bool _showNoEntryZone;
color _noEntryZoneColor;
double _minNoEntryPad;
int _entryIndicator;
bool _showInitialStop;
bool _calcLockIn;
bool _showExit;
bool _writeFileTradeStats;
color _winningExitColor;
color _losingExitColor;
bool _showTradeTrendLine;
color _tradeTrendLineColor;
bool _sendSLandTPToBroker;
bool _showEntry;
bool _alertOnTrade;
int _endOfDayOffsetHours;
bool _setLimitsOnPendingOrders;
bool _adjustStopOnTriggeredPendingOrders;
int _beginningOfDayOffsetHours;
bool _showDrawRangeButton;
bool _setPendingOrdersOnRanges;
bool _accountForSpreadOnPendingBuyOrders;
double _pendingLotSize;
double _marginForPendingRangeOrders;
color _rangeLinesColor;
bool _cancelPendingTrades;
bool _makeTickVisible;
bool _captureScreenShotsInFiles;


bool alertedThisBar = false;
datetime time0;

int longTradeNumberForDay = 0;
int shortTradeNumberForDay =0;
datetime endOfDay;
datetime beginningOfDay;
string normalizedSymbol;
string saveFileName;
string configFileName;
string globalConfigFileName;
datetime lastUpdateTime;
int lastTradeId = 0;
bool lastTradePending = false;
double stopLoss;
double noEntryPad;
Position * activeTrade = NULL;
Broker * broker;
int totalActiveTradeIdsThisTick;
int activeTradeIdsThisTick[]; 
int activeTradeIdsArraySize = 0;
int totalActiveTrades = 0;
Position * activeTradesLastTick[]; //Trade IDs read from global variables at start of tick
int activeTradesArraySize = 0;
int totalDeletedTrades = 0;
Position * deletedTrades[]; // Trades deleted from last tick to this tick 
int deletedTradesArraySize = 0;
int totalNewTrades = 0;
Position * newTrades[]; // new trades since last tick
int newTradesArraySize = 0;
double dayHi;
double dayLo;
int tickNumber = 0;
//int fh1;                // smz: filehandle for trade stats
double RealizedPipsAllPairs = 0.0;
       
datetime dayHiTime;
datetime dayLoTime;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
     Print("---------------------------------------------------------");
   Print("-----",Title," ",Version," Initializing ",Symbol(),"-----"); 
   if(Digits==5||Digits==3)
      FiveDig = 10;
   else
      FiveDig = 1;
   AdjPoint = Point * FiveDig;
   DrawVersion(); 
   UpdateGV();
   CopyInitialConfigVariables();

   
//--- create timer
//   EventSetTimer(60);
      
//---
   if (_testing)
   {
      RunTests();
      return (INIT_FAILED);  // Keep the EA from running if just testing
   }
   Initialize();
   EventSetTimer(600); // 10 minutes
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   //EventKillTimer();
   //----
   if (reason != REASON_CHARTCHANGE && reason!= REASON_PARAMETERS && reason != REASON_RECOMPILE)
      DeleteAllObjects();
   for(int ix=totalActiveTrades - 1;ix >=0;ix--)
     {
      if (CheckPointer(activeTradesLastTick[ix]) == POINTER_DYNAMIC) delete activeTradesLastTick[ix];
     }
   if (CheckPointer(activeTrade) == POINTER_DYNAMIC) delete activeTrade;
   if (CheckPointer(broker) == POINTER_DYNAMIC) delete broker;
   
   //FileClose(fh1);
   //----
   return;
      
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   tickNumber++;
   if(DEBUG_TICK)
     {
      PrintFormat("Entering OnTick # %i", tickNumber);
     }
   if(_makeTickVisible)
     {
      DrawTickNumber();
     }
   if (!_testing)
   { 
      if ( CheckNewBar())
      {
         alertedThisBar = false;
         UpdateGV();

 
        
         if (Time[0] >= endOfDay)
         {
           endOfDay += 24*60*60;
           CleanupEndOfDay();
           beginningOfDay += 24*60*60;
         }
      }
      if (!alertedThisBar)
      {
         CheckNTI();
      }
      
   }
   if(DEBUG_OANDA)
     {
      PrintFormat("Currently %i active trades last tick. ", totalActiveTrades);
     }
  
   PopulateActiveTradeIds();
   PopulateDeletedTrades();
 
   
   //This will populate the new trade array, add new trade to ActiveTrades, and check for replaced Delete trades
   PopulateNewTrades();   
  
   
   CheckForClosedTrades();
   
   
   CheckForPendingTradesGoneActive();
  
   
   CheckForNewTrades();
  
   
   
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
      HeartBeat();
  }
  
  string MakeGVname( int sequence)
  {
   return GVPrefix + IntegerToString(sequence) + "LastOrderId";
  }
  
void OnChartEvent(const int id, const long& lParam, const double& dParam, const string& sParam)
{
   if (id == CHARTEVENT_OBJECT_CLICK)
   {
      if (sParam == rngButtonName)
      {
         PlotRangeLines();
      }
   }
}
//+------------------------------------------------------------------+
void DeleteAllObjects()
   {
   int objs = ObjectsTotal();
   string name;
   
   for(int cnt=ObjectsTotal()-1;cnt>=0;cnt--)
      {
      name=ObjectName(cnt);
      if (StringFind(name,Prefix,0)>-1) 
      {
         ResetLastError();
         bool success = ObjectDelete(name);
         if(!success)
           {
               Print("Failed to delete object " + name +". Error code = " + string(GetLastError()));
           }
      }
      WindowRedraw();
      }
   } //void DeleteAllObjects()
 
void DrawVersion()
   {
   string name;
   name = StringConcatenate(Prefix,"Version");
   ObjectCreate(name,OBJ_LABEL,0,0,0);
   ObjectSetText(name,Version,8,TextFont,TextColor);
   ObjectSet(name,OBJPROP_CORNER,2);
   ObjectSet(name,OBJPROP_XDISTANCE,5);
   ObjectSet(name,OBJPROP_YDISTANCE,2);
   } //void DrawVersion()


void DrawTickNumber()
{
   string name;
   string text = StringFormat("Tick # %i", tickNumber);
   name = StringConcatenate(Prefix,"Tick");
   ObjectCreate(name,OBJ_LABEL,0,0,0);
   ObjectSetText(name,text,8,TextFont,clrBlack);
   ObjectSet(name,OBJPROP_CORNER,2);
   ObjectSet(name,OBJPROP_XDISTANCE,5);
   ObjectSet(name,OBJPROP_YDISTANCE,14);   
}
double GetGV(string VarName)
   {
   string strVarName = //StringConcatenate(Prefix,Symbol(),"_",VarName);
      VarName;
   double VarVal = GVUNINIT;

   if(GlobalVariableCheck(strVarName))
      {
      VarVal = GlobalVariableGet(strVarName);
      if(DEBUG_GLOBAL)
         Print("###Get GV ",strVarName," Value=",VarVal);
      }

   return(VarVal); 
   } //double GetGV(string VarName)

void HeartBeat(int TimeFrame=PERIOD_H1)
   {
   static datetime LastHeartBeat;
   datetime CurrentTime;

   if(GlobalVariableCheck(StringConcatenate(Prefix,"HeartBeat")))
      {
      if(GlobalVariableGet(StringConcatenate(Prefix,"HeartBeat")) == 1)
         HeartBeat = true;
      else
         HeartBeat = false;
   }  //void HeartBeat(int TimeFrame=PERIOD_H1)

   if(HeartBeat)
      { 
      CurrentTime = iTime(NULL,TimeFrame,0);     // NULL: current symbol
      if(CurrentTime > LastHeartBeat)
         {
         Print(Version," HeartBeat ",TimeToStr(TimeLocal(),TIME_DATE|TIME_MINUTES));
         LastHeartBeat = CurrentTime;
 
         } //if(CurrentTime > ...
      } //if(HeartBeat)

   } //HeartBeat()
  //------------------------------------------------------

void Initialize()
{
  lastUpdateTime = 0;
  double updateVar;
  if (GlobalVariableCheck(LASTUPDATENAME))
  {
    GlobalVariableGet(LASTUPDATENAME, updateVar);
    lastUpdateTime = (datetime) (int) updateVar;
  }
     
  //if (fh1 < 0 )
  //{
  //  string fileName= TimeToStr(TimeCurrent(), TIME_DATE | TIME_MINUTES) +
  //        "_" + "trade_stats";
  //  StringReplace(fileName, ":", "_");
  //  fileName += ".csv";
  //  Alert("Open file " + fileName);
  //  fh1=FileOpen(fileName,FILE_WRITE|FILE_CSV);
  //  if(fh1 < 1)
  //  {
  //    int iErrorCode = GetLastError();
  //    Print("Error updating file: ",iErrorCode);
  //  }
  //}

  broker = new Broker(_pairOffsetWithinSymbol);
  GVPrefix = NTIPrefix + broker.NormalizeSymbol(Symbol());
  configFileName = Prefix + Symbol() + "_Configuration.txt";
  globalConfigFileName = Prefix + "_Configuration.txt";
  
     if (!SaveConfiguration)
      ApplyConfiguration();
   else
      SaveConfigurationFile();

  PrintConfigValues();
  normalizedSymbol = broker.NormalizeSymbol(Symbol());
  saveFileName = Prefix + normalizedSymbol + "_SaveFile.txt";
  stopLoss = CalculateStop(normalizedSymbol) * AdjPoint;
  noEntryPad = _minNoEntryPad * AdjPoint;
  MqlDateTime dtStruct;
  TimeToStruct(TimeCurrent(), dtStruct);
  dtStruct.hour = 0;
  dtStruct.min = 0;
  dtStruct.sec = 0;
  endOfDay = StructToTime(dtStruct) +(24*60*60) + (_endOfDayOffsetHours * 60 * 60);
  beginningOfDay = StructToTime(dtStruct) + (_beginningOfDayOffsetHours * 60 * 60);
  longTradeNumberForDay = 0;
  shortTradeNumberForDay = 0;
   InitializeTradeArrays();  
  if(!ValidateActiveTrades())
    {
     Alert("ActiveTrades invalid after InitializeTradeArrrays");
    }
  if (CheckSaveFileValid())
   ReadOldTrades(saveFileName);
  else
   DeleteSaveFile();
  if(!ValidateActiveTrades())
  {
   Alert("ActiveTrades invalid after ReadOldTrades()");
  }
  lastTradeId = 0;
  // Draw buttons
  if (_showDrawRangeButton)
  {
   DrawRangeButton();
  }
 
  

}

void InitializeTradeArrays()
{
  totalActiveTradeIdsThisTick = 0;
  activeTradeIdsArraySize = 5;
  ArrayResize(activeTradeIdsThisTick, activeTradeIdsArraySize);
 
  totalActiveTrades = 0;
  activeTradesArraySize = 5;
  ArrayResize(activeTradesLastTick, activeTradesArraySize);
  totalDeletedTrades = 0;
  deletedTradesArraySize = 5;
  ArrayResize(deletedTrades, deletedTradesArraySize);
  totalNewTrades = 0;
  newTradesArraySize = 5;
  ArrayResize(newTrades, newTradesArraySize);
}
void CheckNTI()
{
   double updateVar;
   GlobalVariableGet(LASTUPDATENAME, updateVar);
   lastUpdateTime = (datetime) (int) updateVar;
   datetime currentTime = TimeLocal();
   int timeDifference = (int) currentTime - (int) lastUpdateTime;
   if (timeDifference > 5)
   {
      Alert("NewTradeIndicator has stopped updating");
      alertedThisBar = true;
   }
}

void CopyInitialConfigVariables()
{
   _testing=Testing;
   _pairOffsetWithinSymbol = PairOffsetWithinSymbol;
   _defaultStopPips = DefaultStopPips;
   _exceptionPairs = ExceptionPairs;
   _useNextLevelTPRule = UseNextLevelTPRule;
   _showNoEntryZone = ShowNoEntryZone;
   _noEntryZoneColor = NoEntryZoneColor;
   _minNoEntryPad = MinNoEntryPad;
   _entryIndicator = EntryIndicator;
   _showInitialStop = ShowInitialStop;
   _calcLockIn = CalcLockIn;
   _showExit = ShowExit;
   _writeFileTradeStats = WriteFileTradeStats;
   _winningExitColor = WinningExitColor;
   _losingExitColor = LosingExitColor;
   _showTradeTrendLine = ShowTradeTrendLine;
   _tradeTrendLineColor = TradeTrendLineColor;
   _minRewardRatio = MinRewardRatio;
   _sendSLandTPToBroker = SendSLandTPToBroker;
   _showEntry = ShowEntry;
   _alertOnTrade = AlertOnTrade;
   _endOfDayOffsetHours = EndOfDayOffsetHours;
   _setLimitsOnPendingOrders = SetLimitsOnPendingOrders;
   _adjustStopOnTriggeredPendingOrders = AdjustStopOnTriggeredPendingOrders;
   _beginningOfDayOffsetHours = BeginningOfDayOffsetHours;
   _showDrawRangeButton = ShowDrawRangeButton;
   _setPendingOrdersOnRanges = SetPendingOrdersOnRanges;
   _accountForSpreadOnPendingBuyOrders = AccountForSpreadOnPendingBuyOrders;
   _pendingLotSize = PendingLotSize;
   _marginForPendingRangeOrders = MarginForPendingRangeOrders;
   _rangeLinesColor = RangeLinesColor;
   _cancelPendingTrades = CancelPendingTrades;
   _makeTickVisible = MakeTickVisible;
   _captureScreenShotsInFiles = CaptureScreenShotsInFiles;

}

bool CheckNewBar()
{
   if(Time[0] == time0) return false;
   time0 = Time[0];
   return true;
   
}

void ApplyConfiguration()
{
   ApplyConfiguration(globalConfigFileName);
   ApplyConfiguration(configFileName);
}

void ApplyConfiguration(string fileName)
{
   if (!FileIsExist(fileName)) return;
   int fileHandle = FileOpen(fileName, FILE_ANSI | FILE_TXT | FILE_READ);
   if (fileHandle == -1) 
   {
      int errcode = GetLastError();
      Print("Failed to open configFile. Error = " + IntegerToString(errcode));
      return;
   }
   while(!FileIsEnding(fileHandle))
     {
      string line = FileReadString(fileHandle);
      string stringParts[];
      int pos = StringSplit(line, ':', stringParts);
      if(pos > 1)
        {
         string var = stringParts[0];
         string value = StringTrimLeft( stringParts[1]);
         if (var == "NoEntryZoneColor")
         {
            _noEntryZoneColor = StringToColor(value);
         }
         else if(var == "Testing")
                {
                  _testing = (bool) StringToInteger(value);
                }
         else if(var == "PairOffsetWithinSymbo")
                {
                  _pairOffsetWithinSymbol =  StringToInteger(value);
                }
         else if(var == "DefaultStopPips")
                {
                  _defaultStopPips =  StringToInteger(value);
                }
         else if(var == "ExceptionPairs")
                {
                  _exceptionPairs = value;
                }
         else if(var == "UseNextLevelTPRule")
                {
                  _useNextLevelTPRule = (bool) StringToInteger(value);
                }
         else if(var == "MinRewardRatio")
                {
                  _minRewardRatio =  StringToDouble(value);
                }
         else if(var == "ShowNoEntryZone")
                {
                  _showNoEntryZone = (bool) StringToInteger(value);
                }
         else if(var == "MinNoEntryPad")
                {
                  _minNoEntryPad = StringToInteger(value);
                }
         else if(var == "EntryIndicator")
                {
                  _entryIndicator =  StringToInteger(value);
                }
         else if(var == "ShowInitialStop")
                {
                  _showInitialStop = (bool) StringToInteger(value);
                }
         else if(var == "CalcLockIn")
                {
                  _calcLockIn = (bool) StringToInteger(value);
                }
         else if(var == "ShowExit")
                {
                  _showExit = (bool) StringToInteger(value);
                }
         else if(var == "WriteFileTradeStats")
                {
                  _writeFileTradeStats = (bool) StringToInteger(value);
                }
         else if(var == "WinningExitColor")
                {
                  _winningExitColor = StringToColor(value);
                }
         else if(var == "LosingExitColor")
                {
                  _losingExitColor = StringToColor(value);
                }
         else if(var == "ShowTradeTrendLine")
                {
                  _showTradeTrendLine = (bool) StringToInteger(value);
                }
         else if(var == "TradeTrendLineColor")
                {
                  _tradeTrendLineColor = StringToColor(value);
                }
         else if(var == "SendSLandTPToBroker")
                {
                  _sendSLandTPToBroker = (bool) StringToInteger(value);
                }
         else if(var == "ShowEntry")
                {
                  _showEntry = (bool) StringToInteger(value);
                }
         else if(var == "AlertOnTrade")
                {
                  _alertOnTrade = (bool) StringToInteger(value);
                }
         else if (var == "EndOfDayOffsetHours")
               {
                  _endOfDayOffsetHours = StringToInteger(value);
               }
         else if (var == "SetLimitsOnPendingOrder")
               {
                  _setLimitsOnPendingOrders = (bool) StringToInteger(value);
               }
         else if (var == "AdjustStopOnTriggeredPendingOrders")
               {
                  _adjustStopOnTriggeredPendingOrders = (bool) StringToInteger(value);
               }
        else if (var == "BeginningOfDayOffsetHours")
               {
                  _beginningOfDayOffsetHours =  StringToInteger(value);
               }
        else if (var == "ShowDrawRangeButton")
               {
                  _showDrawRangeButton = (bool) StringToInteger(value);
               }
        else if (var == "SetPendingOrdersOnRanges")
               {
                  _setPendingOrdersOnRanges  = (bool) StringToInteger(value);
               }
        else if (var == "AccountForSpreadOnPendingBuyOrders")
               {
                  _accountForSpreadOnPendingBuyOrders = (bool) StringToInteger(value); 
               }
        else if (var == "PendingLotSize")
               {
                  _pendingLotSize =  StringToDouble(value); 
               }
        else if (var == "MarginForPendingRangeOrders")
               {
                  _marginForPendingRangeOrders =  StringToDouble(value);
               }
        else if (var == "RangeLinesColor")
               {
                  _rangeLinesColor =  StringToColor(value);
               }
        else if (var == "CancelPendingTrades")
               {
                  _cancelPendingTrades = (bool) StringToInteger(value);
               }
        else if (var == "CaptureScreenShotsInFiles")
               {
                  _captureScreenShotsInFiles = (bool) StringToInteger(value);
               }
        
        }
              
      }
   FileClose(fileHandle);
}

void SaveConfigurationFile()
{
   if (FileIsExist(configFileName))
   {
      FileDelete(configFileName);
   }
   int fileHandle = FileOpen(configFileName, FILE_ANSI | FILE_TXT | FILE_WRITE);
   FileWriteString(fileHandle, "Testing: " + IntegerToString((int) _testing) + "\r\n");

   FileWriteString(fileHandle, "PairOffsetWithinSymbol: " + IntegerToString(_pairOffsetWithinSymbol) + "\r\n");
   FileWriteString(fileHandle, "DefaultStopPips: " + IntegerToString(_defaultStopPips) + "\r\n");
   FileWriteString(fileHandle, "ExceptionPairs: " + _exceptionPairs +"\r\n");
   FileWriteString(fileHandle, "UseNextLevelTPRule: " + IntegerToString((int) _useNextLevelTPRule ) + "\r\n");
   FileWriteString(fileHandle, "MinRewardRatio: " + DoubleToString(_minRewardRatio, 2 ) + "\r\n");
   FileWriteString(fileHandle, "ShowNoEntryZone: " + IntegerToString((int) _showNoEntryZone ) + "\r\n");
   FileWriteString(fileHandle, "NoEntryZoneColor: " + (string) _noEntryZoneColor + "\r\n");
   FileWriteString(fileHandle, "MinNoEntryPad: " + IntegerToString(_minNoEntryPad) + "\r\n");
   FileWriteString(fileHandle, "EntryIndicator: " + IntegerToString(_entryIndicator) + "\r\n");
   FileWriteString(fileHandle, "ShowInitialStop: " + IntegerToString((int) _showInitialStop) + "\r\n");
   FileWriteString(fileHandle, "CalcLockIn: " + IntegerToString((int) _calcLockIn) + "\r\n");
   FileWriteString(fileHandle, "ShowExit: " + IntegerToString((int) _showExit) + "\r\n");
   FileWriteString(fileHandle, "WriteFileTradeStats: " + IntegerToString((int) _writeFileTradeStats) + "\r\n");
   FileWriteString(fileHandle, "WinningExitColor: " + (string) _winningExitColor + "\r\n");
   FileWriteString(fileHandle, "LosingExitColor: " + (string) _losingExitColor + "\r\n");
   FileWriteString(fileHandle, "ShowTradeTrendLine: " + IntegerToString((int) _showTradeTrendLine) + "\r\n");
   FileWriteString(fileHandle, "TradeTrendLineColor: " + (string) _tradeTrendLineColor+ "\r\n");
   FileWriteString(fileHandle, "SendSLandTPToBroker: " + IntegerToString((int) _sendSLandTPToBroker) + "\r\n");
   FileWriteString(fileHandle, "ShowEntry: " + IntegerToString((int) _showEntry) + "\r\n");
   FileWriteString(fileHandle, "AlertOnTrade: " + IntegerToString((int) _alertOnTrade) + "\r\n");
   FileWriteString(fileHandle, "EndOfDayOffsetHours: " + IntegerToString(_endOfDayOffsetHours) + "\r\n");
   FileWriteString(fileHandle, "SetLimitsOnPendingOrders: " + IntegerToString((int) _setLimitsOnPendingOrders) + "\r\n");
   FileWriteString(fileHandle, "AdjustStopOnTriggeredPendingOrders: " + IntegerToString((int) _adjustStopOnTriggeredPendingOrders) + "\r\n");
   FileWriteString(fileHandle, "BeginningOfDayOffsetHours: " + IntegerToString((int) _beginningOfDayOffsetHours) + "\r\n");
   FileWriteString(fileHandle, "ShowDrawRangeButton: " + IntegerToString((int) _showDrawRangeButton) + "\r\n");
   FileWriteString(fileHandle, "SetPendingOrdersOnRanges: " + IntegerToString((int) _setPendingOrdersOnRanges) + "\r\n");
   FileWriteString(fileHandle, "AccountForSpreadOnPendingBuyOrders: " + IntegerToString((int) _accountForSpreadOnPendingBuyOrders) + "\r\n");
   FileWriteString(fileHandle, "PendingLotSize: " + DoubleToString( _pendingLotSize) + "\r\n");
   FileWriteString(fileHandle, "MarginForPendingRangeOrders: " + DoubleToString(_marginForPendingRangeOrders, 1) + "\r\n");
   FileWriteString(fileHandle, "RangeLinesColor: " + (string) _rangeLinesColor + "\r\n");
   FileWriteString(fileHandle, "CancelPendingTrades: " + IntegerToString((int) _cancelPendingTrades) + "\r\n");
   FileWriteString(fileHandle, "CaptureScreenShotsInFiles: " + IntegerToString((int) _captureScreenShotsInFiles) + "\r\n");


   
   FileClose(fileHandle);
}

void PrintConfigValues()
{
   if (!DEBUG_CONFIG) return;
   Print( "PairOffsetWithinSymbol: " + IntegerToString(_pairOffsetWithinSymbol) + "\r\n");
   Print( "DefaultStopPips: " + IntegerToString(_defaultStopPips) + "\r\n");
   Print( "ExceptionPairs: " + _exceptionPairs +"\r\n");
   Print( "UseNextLevelTPRule: " + IntegerToString((int) _useNextLevelTPRule ) + "\r\n");
   Print( "MinRewardRatio: " + DoubleToString(_minRewardRatio, 2 ) + "\r\n");
   Print( "ShowNoEntryZone: " + IntegerToString((int) _showNoEntryZone ) + "\r\n");
   Print( "NoEntryZoneColor: " + (string) _noEntryZoneColor + "\r\n");
   Print( "MinNoEntryPad: " + IntegerToString(_minNoEntryPad) + "\r\n");
   Print( "EntryIndicator: " + IntegerToString(_entryIndicator) + "\r\n");
   Print( "ShowInitialStop: " + IntegerToString((int) _showInitialStop) + "\r\n");
   Print( "CalcLockIn: " + IntegerToString((int) _calcLockIn) + "\r\n");
   Print( "ShowExit: " + IntegerToString((int) _showExit) + "\r\n");
   Print( "WriteFileTradeStats: " + IntegerToString((int) _writeFileTradeStats) + "\r\n");
   Print( "WinningExitColor: " + (string) _winningExitColor + "\r\n");
   Print( "LosingExitColor: " + (string) _losingExitColor + "\r\n");
   Print( "ShowTradeTrendLine: " + IntegerToString((int) _showTradeTrendLine) + "\r\n");
   Print( "TradeTrendLineColor: " + (string) _tradeTrendLineColor+ "\r\n");
   Print( "SendSLandTPToBroker: " + IntegerToString((int) _sendSLandTPToBroker) + "\r\n");
   Print( "ShowEntry: " + IntegerToString((int) _showEntry) + "\r\n");
   Print( "AlertOnTrade: " + IntegerToString((int) _alertOnTrade) + "\r\n");
   Print( "EndOfDayOffsetHours: " + IntegerToString(_endOfDayOffsetHours) + "\r\n");
   Print("SetLimitsOnPendingOrders: " + IntegerToString((int) _setLimitsOnPendingOrders) + "\r\n");
   Print("AdjustStopOnTriggeredPendingOrders: " + IntegerToString((int) _adjustStopOnTriggeredPendingOrders) + "\r\n");
   Print("BeginningOfDayOffsetHours: " + IntegerToString((int) _beginningOfDayOffsetHours) + "\r\n");
   Print("ShowDrawRangeButton: " + IntegerToString((int) _showDrawRangeButton) + "\r\n");
   Print("SetPendingOrdersOnRanges: " + IntegerToString((int) _setPendingOrdersOnRanges) + "\r\n");
   Print("AccountForSpreadOnPendingBuyOrders: " + IntegerToString((int) _accountForSpreadOnPendingBuyOrders) + "\r\n");
   Print("PendingLotSize: " + DoubleToString( _pendingLotSize, 2) + "\r\n");
   Print("MarginForPendingRangeOrders: " + DoubleToString( _marginForPendingRangeOrders, 1) + "\r\n");
   Print("RangeLinesColor: " + (string) _adjustStopOnTriggeredPendingOrders + "\r\n");
   Print("CancelPendingTrades: " + IntegerToString((int) _cancelPendingTrades) + "\r\n");
   Print("CaptureScreenShotsInFiles: " + IntegerToString((int) _captureScreenShotsInFiles) + "\r\n");   
}

   void DrawRangeButton()
   {
      if(ObjectFind(0, rngButtonName )>= 0)
        {
       
         ResetLastError();
         bool success = ObjectDelete( rngButtonName);
         if(!success)
           {
               Print("Failed to delete Range Button (" + rngButtonName +").  Error = " + string(GetLastError()));
           }
        }
      ButtonCreate(
         0, //chart_ID
         rngButtonName, //name
         0, //sub_window
         rngButtonXOffset,
         rngButtonYOffset,
         rngButtonWidth,
         rngButtonHeight,
         CORNER_LEFT_LOWER,
         "Draw Range Lines",
         "Ariel", //fond
         10, // font_size
         clrBlack, //text color
         clrLightGray, //background color
         clrNONE, // border color
         false, //pressed/released state
         false, //selection ??
         false // hidden
         
      );
  
   }
 
   void CheckForClosedTrades()
   {
      if(totalActiveTrades > 0 || totalDeletedTrades > 0)
      {  
         if(DEBUG_ORDER)
           {
               PrintFormat("Entering CheckForClosedTrades(): totalActiveTrades = %i, totalDeletedTrades=%i", totalActiveTrades, totalDeletedTrades);       
           }
      }
      //Because we're modifying the active trade array, do it in reverse order
      for(int ix=totalActiveTrades-1;ix>= 0;ix--)
        {
         int tradeId = activeTradesLastTick[ix].TicketId;
         //Same thing with deleted trade array
         for(int jx=totalDeletedTrades-1;jx>=0;jx--)
           {
             
            if(DEBUG_ORDER)  PrintFormat("ix=%i, tradeId = %i, jx=%i, deleteTradeId = %i",
                  ix, tradeId, jx, deletedTrades[jx].TicketId);
            if(tradeId == deletedTrades[jx].TicketId)
              {
               activeTrade = activeTradesLastTick[ix];
               if(activeTrade.IsPending)
                 {
                    HandleDeletedTrade();  //TODO: Need to specify which trade                  
                 }
               else
                 {
                    HandleClosedTrade();
                 }
               activeTrade = NULL;       
              }
           }
        }
   }
   void CheckForPendingTradesGoneActive()
   {
      int seqNo = 1;
      for(int jx=0; jx<totalActiveTradeIdsThisTick; jx++)
      {         
         int tradeId = activeTradeIdsThisTick[jx];
         if (tradeId != 0)
         {
            for(int ix=0;ix<totalActiveTrades;ix++)
              {
                  if (activeTradesLastTick[ix] !=NULL &&activeTradesLastTick[ix].TicketId == tradeId)
                  {
                     if (activeTradesLastTick[ix].IsPending)
                     {
                        int orderType = broker.GetType(tradeId);
                        if (orderType == OP_BUY || orderType == OP_SELL) //then no longer pending.
                        {
                           if (CheckPointer(activeTradesLastTick[ix]) == POINTER_DYNAMIC) delete activeTradesLastTick[ix];
                           activeTradesLastTick[ix] = broker.GetTrade(tradeId);
                           activeTrade = activeTradesLastTick[ix];
                           HandlePendingTradeGoneActive();
                        }
                     }
                     break;
                  }
              }
           }
         seqNo++;
      }
   }

   
   void CheckForNewTrades()
   {
     
      for(int ix=0;ix<totalNewTrades;ix++)
        {
         if(CheckPointer(newTrades[ix]) != POINTER_INVALID)
         {
           
         //AddActiveTrade(newTrades[ix]);
         HandleNewEntry(newTrades[ix].TicketId);
         }
         else
         {
            PrintFormat("TotalNewTrades = %i; Invalid newTrade pointer at index %i",totalNewTrades, ix);
         }
         newTrades[ix] = NULL;
        }
      totalNewTrades = 0;
   }



void HandleNewEntry( int tradeId, bool savedTrade = false, double initialStopPrice = 0.0)
{
  
   activeTrade = NULL;
   for(int ix=totalActiveTrades-1;ix>=0;ix--)
     {
      if(activeTradesLastTick[ix].TicketId == tradeId)
        {
         activeTrade = activeTradesLastTick[ix];
        }
     }
   if(activeTrade == NULL)
     {
      Alert("tradeId not found in activeTrades array in HandleNewEntry");
     }
   if(CheckPointer(activeTrade) == POINTER_INVALID)
      Alert("INVALID POINTER in Handle New Entry for tradeId %i, initialStopPrice %f", tradeId, initialStopPrice);
   //if (!activeTrade.IsPending && matchesDeletedTrade(activeTrade))       // smz
   //{
   //   activeTrade.IsPending;
   //}
   lastTradeId = tradeId;
   lastTradePending = activeTrade.IsPending;
   if (activeTrade.IsPending && !savedTrade)
   {
      if (DEBUG_ORDER)
      {
         Print("New Pending order found: Symbol: " + activeTrade.Symbol + 
            " OpenPrice: " + DoubleToStr(activeTrade.OpenPrice, 5) + 
            " TakeProfit: " + DoubleToStr(activeTrade.TakeProfitPrice, 5));
      }
      if(_setLimitsOnPendingOrders)
         SetStopAndProfitLevels(activeTrade, false);
      return;
   }
   PrintFormat("Calling HandleTradeEntry() from HandleNewEntry()");
   HandleTradeEntry(false, savedTrade);
}
bool matchesDeletedTrade(Position * newTrade)
{
   if(totalDeletedTrades == 0) return false;
   for(int ix=0;ix<totalDeletedTrades;ix++)
     {
         Position * deletedTrade = deletedTrades[ix];
            if(DEBUG_OANDA)
              {
                  PrintFormat("Checking new trade (ticket %i) matching a deleted trade (ticket %i)",
                     newTrade.TicketId, deletedTrade.TicketId);
              }
            if (CheckForMatchingPendingTrades(newTrade, deletedTrade))
            {
               RemoveDeletedTrade(ix);
               return true;
            }
     }

   return false;
}

void HandlePendingTradeGoneActive()
{
   PrintFormat("Calling HandleTradeEntry() from HandlePendingTradeGoneActive()");
   HandleTradeEntry(true);
}
void HandleTradeEntry(bool wasPending, bool savedTrade = false)
{
      if(!savedTrade &&  !activeTrade.IsPending)
        {
         if (_alertOnTrade)
            Alert("Entered " + normalizedSymbol + " " + (activeTrade.OrderType == OP_BUY ? "long" : "short") +". Id = " + 
            IntegerToString(activeTrade.TicketId) +". OpenPrice = " + DoubleToStr(activeTrade.OpenPrice, 5));
         SaveTradeToFile(saveFileName, activeTrade);
        }
   if(_cancelPendingTrades && !savedTrade)
     {
      for(int ix=totalActiveTrades - 1;ix >=0 ;ix--)
        {
            if(activeTradesLastTick[ix] == activeTrade) continue;
            if(activeTradesLastTick[ix].IsPending && (activeTradesLastTick[ix].OrderType & 0x01) == (activeTrade.OrderType & 0x01))
              {
                  PrintFormat("Attempting to Delete trade %i. OrderType=%i.  ActiveTrade = %i, ActiveTradeType = %i", activeTradesLastTick[ix].TicketId,
                     activeTradesLastTick[ix].OrderType, activeTrade.TicketId, activeTrade.OrderType);
                  broker.DeletePendingTrade(activeTradesLastTick[ix]);
              }
        }
     }
   string objectName = Prefix + "Entry";
   if (!savedTrade) SetStopAndProfitLevels(activeTrade, wasPending);
   if (activeTrade.OrderType == OP_BUY)
   {
      objectName = objectName + "L" + IntegerToString(++longTradeNumberForDay);
   }  
   else
   {
      objectName = objectName + "S" + IntegerToString(++shortTradeNumberForDay);
   }
   if (_showEntry)
   {
   PrintFormat("Drawing Entry arrow. Opened @ %s %f. Stop at %f", 
      TimeToString(activeTrade.OrderOpened, TIME_MINUTES), activeTrade.OpenPrice, activeTrade.StopPrice);
   ObjectCreate(0, objectName, OBJ_ARROW, 0, activeTrade.OrderOpened, activeTrade.OpenPrice);
   ObjectSetInteger(0, objectName, OBJPROP_ARROWCODE, _entryIndicator);
   ObjectSetInteger(0, objectName, OBJPROP_COLOR, Blue);
   }
   if (DEBUG_ENTRY)
   {
      Print("Setting TakeProfit target at " + DoubleToStr(activeTrade.TakeProfitPrice, Digits));
   }
   if (_showInitialStop)
   {
      StringReplace(objectName, "Entry","Stop");
      ObjectCreate(0, objectName, OBJ_ARROW, 0, activeTrade.OrderOpened, activeTrade.StopPrice);
      ObjectSetInteger(0, objectName, OBJPROP_ARROWCODE, 4);
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, Red);
   }
   if(!savedTrade) CaptureScreenShot();
   
   if(_calcLockIn) ShowTradeInfo(activeTrade);

}

void SetStopAndProfitLevels(Position * trade, bool wasPending)
{
      
      if //(trade.OrderType == OP_BUY || trade.OrderType == OP_BUYLIMIT || trade.OrderType == OP_BUYSTOP))
         ((trade.OrderType & 0x0001) == 0)  // All BUY order types are even
      {
         if (trade.StopPrice == 0 || (wasPending && _adjustStopOnTriggeredPendingOrders)) trade.StopPrice = trade.OpenPrice - stopLoss;
         if (DEBUG_ENTRY)
         {
            Print ("Setting stoploss for BUY order (" + IntegerToString(trade.OrderType) +") StopLoss= " + DoubleToStr(trade.StopPrice, 5) + "(OpenPrice = " + DoubleToStr(trade.OpenPrice, 5) + ", stopLoss = " + DoubleToStr(stopLoss, 8));
         }
         if (_useNextLevelTPRule)
            if (trade.TakeProfitPrice == 0 || (wasPending && _adjustStopOnTriggeredPendingOrders)) trade.TakeProfitPrice = GetNextLevel(trade.OpenPrice + _minRewardRatio*stopLoss, 1);
      }
      else //SELL type
      {
         if (trade.StopPrice ==0 ||(wasPending && _adjustStopOnTriggeredPendingOrders ) )trade.StopPrice = trade.OpenPrice + stopLoss;
         if (DEBUG_ENTRY)
         {
            Print ("Setting stoploss for SELL order (" + IntegerToString(trade.OrderType) + ") StopLoss= " + DoubleToStr(trade.StopPrice, 5) + "(OpenPrice = " + DoubleToStr(trade.OpenPrice, 5) + ", stopLoss = " + DoubleToStr(stopLoss, 8));
         }
         
         if (_useNextLevelTPRule)
            if (trade.TakeProfitPrice == 0 || (wasPending && _adjustStopOnTriggeredPendingOrders)) trade.TakeProfitPrice = GetNextLevel(trade.OpenPrice-_minRewardRatio*stopLoss, -1);
      }
      if (_sendSLandTPToBroker && !_testing)
      {
         if (DEBUG_ENTRY)
         {
            Print("Sending to broker: TradeType=" + IntegerToString(trade.OrderType) + 
               " OpenPrice=" + DoubleToString(trade.OpenPrice,Digits) + 
               " StopPrice=" + DoubleToString(trade.StopPrice, Digits) +
               " TakeProfit=" + DoubleToString(trade.TakeProfitPrice, Digits)
               );
         }
         broker.SetSLandTP(trade);
      }    

}
void HandleClosedTrade(bool savedTrade = false)
{
   if(CheckPointer(activeTrade) == POINTER_INVALID)
   {
      if (!savedTrade)
      {
         if(_alertOnTrade)
           {
               Alert("Old Trade "  + " closed. INVALID POINTER for activeTrade");      
           }
      }
   }
   else
   {
     if (!savedTrade)
     {
       broker.GetClose(activeTrade);
       
       
       //double diff = activeTrade.ClosePrice - activeTrade.OpenPrice;
       //if (activeTrade.OrderType == OP_SELL) diff *= -1;
       //double pips = diff/Point;
       //double profit = calcPL(activeTrade.Symbol,activeTrade.OrderType,activeTrade.OpenPrice,activeTrade.ClosePrice,activeTrade.LotSize);

      
       double pips = tradePips(activeTrade);
       double profit = tradePnL(activeTrade);
       
       
       //double profit = activeTrade.ClosePrice - activeTrade.OpenPrice;
       //if (activeTrade.OrderType == OP_SELL) profit = profit * -1;
       //profit = NormalizeDouble(profit, Digits)/Point; 
       if (FiveDig) pips *= .1;
       if(_alertOnTrade)
       {
         Alert("Closed " + IntegerToString (activeTrade.TicketId) + " (" + activeTrade.Symbol + " " + (activeTrade.OrderType == OP_BUY ? "long" : "short") +
               ") (" + DoubleToStr(profit, 1) + ")");            
       }
   
       Print("Handling closed trade.  OrderType= " + IntegerToString(activeTrade.OrderType));
       RealizedPipsAllPairs += pips;
       Alert("Realized PIPs   : " + RealizedPipsAllPairs + "\n" 
             "Digits          : " + Digits + "\n"
             "Point           : " + Point + "\n"
//             "Trade diff      : " + diff + "\n"
             "Trade pips      : " + pips + "\n"
             "calcPL          : " + tradePnL(activeTrade) + "\n"
             "realized Pips   : " + RealizedPipsToday() + "\n"
             "Realized Profits: " + RealizedProfitToday());
       if (_writeFileTradeStats) WriteFileTradeStats(activeTrade);
       if (activeTrade.OrderClosed == 0) return;
     }
     if (_showExit)
     {
       string objName = Prefix + "Exit";
       color arrowColor;
       arrowColor = Blue;    // smz
       if(activeTrade.OrderType == OP_BUY)
       {
         objName += "L" + IntegerToString(longTradeNumberForDay);
       }
       else
       {  
         objName += "S" + IntegerToString(shortTradeNumberForDay);
       }
      
       ObjectCreate(0, objName, OBJ_ARROW, 0, activeTrade.OrderClosed, activeTrade.ClosePrice);
       ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, _entryIndicator + 1);
       ObjectSetInteger(0, objName, OBJPROP_COLOR, arrowColor);
       if (_showTradeTrendLine)
       {
         string trendLineName = objName;
         StringReplace(trendLineName, "Exit", "Trend");
         ObjectCreate(0, trendLineName, OBJ_TREND, 0, activeTrade.OrderOpened, activeTrade.OpenPrice, activeTrade.OrderClosed, activeTrade.ClosePrice);
         ObjectSetInteger(0, trendLineName, OBJPROP_COLOR, Blue);
         ObjectSetInteger(0, trendLineName, OBJPROP_RAY, false);
         ObjectSetInteger(0, trendLineName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, trendLineName, OBJPROP_WIDTH, 1);
       }
       if ( (activeTrade.OrderType == OP_BUY && activeTrade.ClosePrice >= activeTrade.OpenPrice) ||
            (activeTrade.OrderType == OP_SELL && activeTrade.ClosePrice <= activeTrade.OpenPrice)) // Winning trade
       {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, _winningExitColor);
       }
       else //losing trade
       {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, _losingExitColor);
         if (_showNoEntryZone)
         {
           datetime rectStart = activeTrade.OrderClosed;
           if (rectStart == 0) return;
           double rectHigh = NormalizeDouble(GetNextLevel(activeTrade.OpenPrice + noEntryPad,1), Digits);
           if (DEBUG_EXIT)
           {
             PrintFormat("ExitZone high = %s (OpenPrice= %s, noEntryPad=%s, arg=%s", DoubleToStr(rectHigh, Digits),
                        DoubleToStr(activeTrade.OpenPrice, Digits), DoubleToStr(noEntryPad, Digits), DoubleToStr(activeTrade.OpenPrice + noEntryPad));
           }
           double rectLow = NormalizeDouble(GetNextLevel(activeTrade.OpenPrice - noEntryPad, -1), Digits);
           if (DEBUG_EXIT)
           {
             PrintFormat("ExitZone low = %s (OpenPrice= %s, noEntryPad=%s, arg=%s", DoubleToStr(rectLow, Digits),
                        DoubleToStr(activeTrade.OpenPrice, Digits), DoubleToStr(noEntryPad, Digits), DoubleToStr(activeTrade.OpenPrice - noEntryPad));
           }
           string rectName = Prefix + "NoEntryZone";
           if (ObjectFind(rectName) >= 0) 
           {
             double existingHigh = ObjectGetDouble(0, rectName, OBJPROP_PRICE1);
             if (DEBUG_EXIT)
             {
               PrintFormat("Existing ExitZone rectangle high = %s", DoubleToString(existingHigh, Digits));
             }
             if(existingHigh > rectHigh)
             {
               rectHigh = existingHigh;
             }
             double existingLow = ObjectGetDouble(0, rectName, OBJPROP_PRICE2);
             if (DEBUG_EXIT)
             {
               PrintFormat("Existing ExitZone rectangle low = %s", DoubleToString(existingLow, Digits));
             }
             if (existingLow < rectLow)
             {
               if (DEBUG_EXIT)
                 PrintFormat("Existing log (%s) substituted for new Low(%S)", DoubleToStr(existingLow,Digits), DoubleToStr(rectLow, Digits));
               rectLow = existingLow;
             }
             datetime existingStart = ObjectGetInteger(0, rectName, OBJPROP_TIME1);
             if (existingStart < rectStart && existingStart > beginningOfDay)
             {
               rectStart = existingStart;
             }
           }
           ObjectDelete(0, rectName); // Just in case it already exists.
           ObjectCreate(0,rectName, OBJ_RECTANGLE, 0, rectStart, rectHigh, beginningOfDay + 24 * 60 *60 , rectLow);
           ObjectSetInteger(0, rectName, OBJPROP_COLOR, _noEntryZoneColor);
         }
       }
     }
     HandleDeletedTrade();
   }
   activeTrade = NULL;
   
}
void HandleDeletedTrade()
{
      for(int ix=totalDeletedTrades-1;ix>=0;ix--)
        {
         if(CheckPointer(deletedTrades[ix]) == POINTER_INVALID)
           {
            PrintFormat("deletedTrades[%i] is INVALID", ix);
           }
           else
           { 
            if(deletedTrades[ix].TicketId == activeTrade.TicketId)
            {
               RemoveDeletedTrade(ix);
               break;
            }
           }
        }
      for(int ix=totalActiveTrades-1;ix>=0;ix--)
        {
         if(activeTradesLastTick[ix] == activeTrade)
           {
            RemoveActiveTrade(ix);
            break;
           }
        }
      // Before deleting it, make sure it's not in the new trade array
      for(int ix=totalNewTrades-1;ix >= 0;ix--)
        {
         if(newTrades[ix] == activeTrade)
           {
            RemoveNewTrade(ix);
            break;
           }
        }
      if (CheckPointer(activeTrade) == POINTER_DYNAMIC)
         delete activeTrade;
      activeTrade = NULL;

}

void CaptureScreenShot()
{

  if(!_captureScreenShotsInFiles) return;
  int xPixels = ChartWidthInPixels();
  int yPixels = ChartHeightInPixelsGet();
  ChartForegroundSet(0);
  string fileName= TimeToStr(TimeCurrent(), TIME_DATE | TIME_MINUTES) +
          "_" + Symbol();
  StringReplace(fileName, ":", "_");
  fileName +=  (activeTrade.OrderType == OP_BUY)? (" L" +IntegerToString((long) longTradeNumberForDay)): (" S" + IntegerToString((long) shortTradeNumberForDay));
  fileName += ".png";
  if(DEBUG_ORDER)
  {
    Print("Capturing Screen shot into " + fileName );
  }
  ChartScreenShot(0, fileName, xPixels, yPixels);
}

int CalculateStop(string symbol)
{
   int stop = _defaultStopPips;
   int pairPosition = StringFind(_exceptionPairs, symbol, 0);
   if (pairPosition >=0)
   {
      int slashPosition = StringFind(_exceptionPairs, "/", pairPosition) + 1;
      stop = StringToInteger(StringSubstr(_exceptionPairs,slashPosition));
   }
   return stop;
}

double GetNextLevel(double currentLevel, int direction /* 1 = UP, -1 = down */)
{
   //double currentBaseLevel;
   string baseString;
   double isolatedLevel;
   double nextLevel;
   if (currentLevel > 50) // Are we dealing with Yen's or other pairs?
   {
      baseString = DoubleToStr(currentLevel, 3);
      baseString = StringSubstr(baseString, 0, StringLen(baseString) - 3);
      isolatedLevel = currentLevel -  StrToDouble(baseString) ;
   }
   else
   {
      baseString  = DoubleToStr(currentLevel, 5);
      baseString = StringSubstr(baseString,0, StringLen(baseString) - 3);
      isolatedLevel = (currentLevel - StrToDouble(baseString)) * 100;
   }
   if (direction > 0)
   {
      if (isolatedLevel >= .7999)
         nextLevel = 1.00;
      else if (isolatedLevel >= .4999)
         nextLevel = .80;
      else if (isolatedLevel >= .1999)
         nextLevel = .50;
      else nextLevel = .20;   
   }
   else
   {
      if (isolatedLevel >.79999)
         nextLevel = .80;
      else if (isolatedLevel > .49999)
         nextLevel = .50;
      else if (isolatedLevel > .19999)
         nextLevel = .20;
      else nextLevel = .00;
   }
   if (currentLevel > 50)
   {
      return StrToDouble(baseString) + nextLevel;
   }
   else
      return (StrToDouble(baseString) + nextLevel/100);
      
}

bool CheckSaveFileValid()
{
   int fileHandle = FileOpen(saveFileName, FILE_ANSI | FILE_TXT | FILE_READ);
   if (fileHandle != -1)
   {
      string line = FileReadString(fileHandle);
      if (line == StringFormat("DataVersion: %i", DFVersion) || line == "DataVersion: 1") // versions match
      {
         line = FileReadString(fileHandle);
         StringReplace(line, "Server Trade Date: ", "");
         datetime day = StrToTime(line); 
         FileClose(fileHandle);
         if (day == GetDate(TimeCurrent())) return true;
         else return false;
      }
   }
   return false;
}
void CleanupEndOfDay()
{
  Alert("End of Day Cleanup");
  RealizedPipsAllPairs = 0.0;
  DeleteSaveFile();
  DeleteAllObjects();
  // Replace the version legend
  DrawVersion();
}

void DeleteSaveFile()
{
   if (FileIsExist(saveFileName))
      FileDelete(saveFileName);
}
void SaveTradeToFile(string fileName, Position *trade)
{
   int fileHandle = FileOpen(fileName, FILE_TXT | FILE_ANSI | FILE_WRITE | FILE_READ);
   if (fileHandle != -1)
   {
      FileSeek(fileHandle, 0, SEEK_END);
      ulong filePos = FileTell(fileHandle);
      if (filePos == 0)// First write to this file
      {
         FileWriteString(fileHandle,StringFormat("DataVersion: %i\r\n", DFVersion));
         FileWriteString(fileHandle, StringFormat("Server Trade Date: %s\r\n", TimeToString(TimeCurrent(), TIME_DATE)));
      }
      FileWriteString(fileHandle, StringFormat("Trade ID: %i Initial Stop: %f\r\n", trade.TicketId, trade.StopPrice));
      FileClose(fileHandle);
   }
}

void UpdateGV()
{
   if(GlobalVariableCheck(StringConcatenate(Prefix,"debug")))
      {
      if(GlobalVariableGet(StringConcatenate(Prefix,"debug")) != 0)
         debug = GlobalVariableGet(StringConcatenate(Prefix, "debug"));
      else
         debug = 0;
      }
   if(GlobalVariableCheck(StringConcatenate(Prefix, normalizedSymbol + "debug")))
   {
      int debugFlag = GlobalVariableGet(StringConcatenate(Prefix, normalizedSymbol + "debug"));
      debug |= debugFlag;
   }

   if(GlobalVariableCheck(StringConcatenate(Prefix,"HeartBeat")))
      {
      if(GlobalVariableGet(StringConcatenate(Prefix,"HeartBeat")) == 1)
         HeartBeat = true;
      else
         HeartBeat = false;
      }

}

void ReadOldTrades(string fileName)
{
   
   int fileHandle = FileOpen(fileName, FILE_ANSI | FILE_TXT | FILE_READ);
   if (fileHandle != -1)
   {
      string line = FileReadString(fileHandle);
      if (line == StringFormat("DataVersion: %i", DFVersion)|| line == "DataVersion: 1") // versions match
      {
         line = FileReadString(fileHandle);
         StringReplace(line, "Server Trade Date: ", "");
         datetime day = StrToTime(line); 
         if (day == GetDate(TimeCurrent()))
         {
            while (!FileIsEnding(fileHandle))
            {
               line = FileReadString(fileHandle);
               StringReplace(line, "Trade ID: ", "");
               int tradeId = StrToInteger(line);
               double sl = 0.0;
               int stopLossPos = StringFind(line, "Initial Stop");
               if(stopLossPos != -1)
               {
                  line = StringSubstr(line, stopLossPos);
                  StringReplace(line, "Intial Stop: ", "");
                  sl = StrToDouble(line);
               }
               lastTradeId = tradeId;
               Position * lastTrade = broker.GetTrade(lastTradeId);
               AddActiveTrade(lastTrade);
              
               PrintFormat("Calling HandleNewEntry for saved trade %i, with stop loss %f", tradeId, sl);
               HandleNewEntry(tradeId,true, sl);
              
               
               if (activeTrade.OrderClosed != 0)
               {
                  HandleClosedTrade(true);
               if(!ValidateActiveTrades())
                 {
                  Alert("ActiveTrades array invalid after HandleClosedTrade in ReadOldTrades");
                 }
               }
            }
         }

       }         
       FileClose(fileHandle);
      }    
}

datetime GetDate(datetime time)
{
   MqlDateTime timeStruct;
   TimeToStruct(time, timeStruct);
   timeStruct.hour = 0; timeStruct.min = 0; timeStruct.sec = 0;
   return (StructToTime(timeStruct));
}


void PlotRangeLines()
{
   ObjectSetInteger(0, rngButtonName, OBJPROP_STATE, true);
   datetime TimeCopy[];
   ArrayCopy(TimeCopy, Time, 0, 0, WHOLE_ARRAY);
   double HighPrices[];
   ArrayCopy(HighPrices, High, 0, 0, WHOLE_ARRAY);
   double LowPrices[];
   ArrayCopy(LowPrices, Low, 0, 0, WHOLE_ARRAY);
   FindDayMinMax(beginningOfDay, TimeCopy[0], TimeCopy, HighPrices, LowPrices);
   if (ObjectFind(0, Prefix + "_DayRangeHigh") == 0)
    ObjectDelete(0, Prefix + "_DayRangeHigh");
   if (ObjectFind(0, Prefix + "_DayRangeLow") == 0) ObjectDelete(0, Prefix + "_DayRangeLow");
   if (ObjectFind(0, Prefix + "_DayHighArrow") == 0) ObjectDelete(0, Prefix + "_DayHighArrow");
   if (ObjectFind(0, Prefix + "_DayLowArrow") == 0) ObjectDelete(0, Prefix + "_DayLowArrow");
   ObjectCreate(0, Prefix + "_DayRangeHigh", OBJ_TREND, 0, dayHiTime, dayHi, beginningOfDay + 19*60*60, dayHi);
   ObjectSetInteger(0, Prefix + "_DayRangeHigh", OBJPROP_COLOR, _rangeLinesColor);
   ObjectSet(Prefix + "_DayRangeHigh", OBJPROP_RAY, false);
   ObjectCreate(0, Prefix + "_DayHighArrow", OBJ_ARROW_RIGHT_PRICE, 0, beginningOfDay + 19 * 60 *60 +15*60, dayHi);
   ObjectSetInteger(0, Prefix + "_DayHighArrow", OBJPROP_COLOR, Blue);
   ObjectCreate(0, Prefix + "_DayRangeLow", OBJ_TREND, 0, dayLoTime, dayLo, beginningOfDay + 19*60*60, dayLo);
   ObjectSetInteger(0, Prefix + "_DayRangeLow", OBJPROP_COLOR, _rangeLinesColor);
   ObjectSet(Prefix + "_DayRangeLow", OBJPROP_RAY, false);
   ObjectCreate(0, Prefix + "_DayLowArrow", OBJ_ARROW_RIGHT_PRICE, 0, beginningOfDay + 19 * 60 *60 +15*60, dayLo);
   ObjectSetInteger(0, Prefix + "_DayLowArrow", OBJPROP_COLOR, Blue);
   int spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   CreatePendingOrdersForRange(dayHi, OP_BUYSTOP, _setPendingOrdersOnRanges, _accountForSpreadOnPendingBuyOrders, _marginForPendingRangeOrders, spread);
   CreatePendingOrdersForRange(dayLo, OP_SELLSTOP, _setPendingOrdersOnRanges, _accountForSpreadOnPendingBuyOrders, _marginForPendingRangeOrders, spread);
   ObjectSetInteger(0, rngButtonName, OBJPROP_STATE,false);
   
}
   
void FindDayMinMax(datetime start, datetime end, datetime& TimeCopy[], double& HighPrices[], double& LowPrices[])
{
   dayHi = 0.0;
   dayLo = 9999.99;
   datetime now = TimeCopy[0];
   if (now < end) end = now;
   int candlePeriod = TimeCopy[0] - TimeCopy[1];
   int interval = (now - start)/ candlePeriod; 
   while(TimeCopy[interval] <= end && interval > 0)
     {
         if (HighPrices[interval] >dayHi)
         {
            dayHi = HighPrices[interval];
            dayHiTime = TimeCopy[interval];
         }
         if (LowPrices[interval] < dayLo)
         {
            dayLo = LowPrices[interval];
            dayLoTime = TimeCopy[interval];
         }
         interval--;
     }
}

void PopulateActiveTradeIds()
{
        
         totalActiveTradeIdsThisTick = 0; //abandon any contents from previous tick
         for(int ix=0; ;ix++)
           {
            int tradeId = GetGV(MakeGVname(ix+1));
            if (tradeId == GVUNINIT) break;
            if (tradeId == 0) continue;
            AddActiveTradeId(tradeId);
           }
           
}

void PopulateDeletedTrades()
{
   totalDeletedTrades = 0;  //Start fresh
   // Work through active trades and add any that are not in the activeTradeIdsThisTick array
   for(int ix=0;ix<totalActiveTrades;ix++)
     {
      int tradeId = activeTradesLastTick[ix].TicketId;
      bool tradeDeleted = true;
      for(int jx=0;jx<totalActiveTradeIdsThisTick;jx++)
        {
         if(tradeId == activeTradeIdsThisTick[jx]) // Then trade is not deleted
           {
            tradeDeleted = false;
            break;
           }
        }
        if(tradeDeleted)
          {
           AddDeletedTrade(activeTradesLastTick[ix]);
          }
     }
}


void PopulateNewTrades()
{
   totalNewTrades = 0;// Start fresh
   for(int ix=0;ix<totalActiveTradeIdsThisTick;ix++)
     {
         int currentActiveTradeId = activeTradeIdsThisTick[ix];
         bool thisIsANewTrade = true;
         for(int jx=0;jx<totalActiveTrades;jx++)
           {
               if(activeTradesLastTick[jx].TicketId == currentActiveTradeId)
                 {
                     thisIsANewTrade = false;
                     break;
                 }
           }
         if(thisIsANewTrade)
           {
               AddNewTrade(currentActiveTradeId);
           }
     }
}

void AddActiveTradeId(int tradeId)
{
   
   if(activeTradeIdsArraySize <= totalActiveTradeIdsThisTick)
   {
      ArrayResize(activeTradeIdsThisTick, 2* activeTradeIdsArraySize);
      activeTradeIdsArraySize *= 2;
   }
   activeTradeIdsThisTick[totalActiveTradeIdsThisTick++] = tradeId;
}


void AddNewTrade(int tradeId)
{
     Position * newTrade = broker.GetTrade(tradeId);
     if(newTradesArraySize <= totalNewTrades)
       {
        ArrayResize(newTrades, 2* newTradesArraySize);
        newTradesArraySize *= 2;
       }
     PrintFormat("Adding newTtade %i at index %i", tradeId, totalNewTrades);
     newTrades[totalNewTrades++] = newTrade;
     //This adds the new trade to the active trade array, but it remains in newTrades
     AddActiveTrade(newTrade);
     //The only thing this MAY do is set the IsPending flag on newTrade
     CheckForNewTradeReplacingDeletedTrade(newTrade);
}

void AddDeletedTrade(Position * trade)
{
   if(deletedTradesArraySize<= totalDeletedTrades + 1)
     {
         ArrayResize(deletedTrades, deletedTradesArraySize * 2);
         deletedTradesArraySize *= 2;
     }
   deletedTrades[totalDeletedTrades++] = trade;
}

void AddActiveTrade(Position * newTrade)
{
   if(activeTradesArraySize <= totalActiveTrades +1)
   {
      ArrayResize(activeTradesLastTick, activeTradesArraySize * 2);
      activeTradesArraySize *= 2;
   }
   PrintFormat("Adding activeTrade %i at index %i", newTrade.TicketId, totalActiveTrades);
   activeTradesLastTick[totalActiveTrades++] = newTrade;
}
void RemoveActiveTrade(int index)
{

   if(totalActiveTrades <= 0)
     {
      Alert("Attempt to Remove an active trade when there are none.");
     }   
   for(int ix=index;ix<totalActiveTrades-1;ix++)
     {
         activeTradesLastTick[ix] = activeTradesLastTick[ix+1];
     }
   //NULL out the last one
   activeTradesLastTick[--totalActiveTrades] = NULL;
}

void RemoveDeletedTrade(int index)
{
   for(int ix=index;ix<totalDeletedTrades-1;ix++)
     {
         deletedTrades[ix] = deletedTrades[ix+1];
     }
   totalDeletedTrades--;
   deletedTrades[totalDeletedTrades] = NULL;
}

void RemoveNewTrade(int index)
{
   for(int ix=index;ix<totalNewTrades-1;ix++)
     {
         newTrades[ix] = newTrades[ix+1];
     }
   totalNewTrades--;
   newTrades[totalNewTrades] = NULL;
}
bool ValidateActiveTrades()
{
   bool valid = true;
   if (activeTradesArraySize != ArraySize(activeTradesLastTick))
   {
      PrintFormat("activeTradeArraySize=%i; ArraySize(activeTradesLastTick)=%i. Validation fails!", activeTradesArraySize, ArraySize(activeTradesLastTick));
      return false;
   }
   
   if(totalActiveTrades > activeTradesArraySize)
   {
      PrintFormat("totalActiveTrades (%i) > activeTradeArraySize (%i). Validation fails!", totalActiveTrades, activeTradesArraySize);
      return false;
   }
   
   for(int ix=0;ix<totalActiveTrades;ix++)
     {
      if(activeTradesLastTick[ix] == NULL )
      {
         valid = false;
         PrintFormat("activeTrades[%i] is NULL. Validation fails!", ix);
         continue;
      }
      if(CheckPointer(activeTradesLastTick[ix]) == POINTER_INVALID)
        {
         valid = false;
         PrintFormat("activeTrades[%i] is INVALID. Validation fails!", ix);
        }
        if (activeTradesLastTick[ix].TicketId == 0)
        {
            valid = false;
            PrintFormat("activeTrades[%i].TicketId = 0. Validation fails!", ix);
        }
     }
   return valid;
}
bool ValidateDeletedTrades()
{
   bool valid = true;
   if (deletedTradesArraySize != ArraySize(deletedTrades))
   {
      PrintFormat("deletedTradesArraySize = i%; ArraySize(deletedTrades) = %i. Validation fails!",
         deletedTradesArraySize, ArraySize(deletedTrades));
      return false;
   }
   if(totalDeletedTrades > deletedTradesArraySize)
   {
      PrintFormat("totalDeletedTrades (%i) > deletedTradesArraySize (%i). Validation fails!",
         totalDeletedTrades, deletedTradesArraySize);
      return false;
   }
   for(int ix=0;ix<totalDeletedTrades;ix++)
     {
      if(deletedTrades[ix] == NULL)
        {
         valid = false;
         PrintFormat("deletedTrades[%i] is NULL. Validation fails!", ix);
         continue;
        }
      if(CheckPointer(deletedTrades[ix]) == POINTER_INVALID)
        {
         valid = false;
         PrintFormat("deletedTrades[%i] is INVALID. Validation fails!", ix);
        }
      if(deletedTrades[ix].TicketId == 0)
        {
            valid = false;
            PrintFormat("deletedTrades[%i].TicketId = 0. Validation fails!", ix);
        }
     }
     return valid;
}

void CheckForNewTradeReplacingDeletedTrade(Position * newTrade)
{
         if(DEBUG_ORDER)
           {
               PrintFormat("Checking if new trade %i is a replacement for a deleted trade.", newTrade.TicketId);
               PrintFormat("Total Deleted Trades = %i", totalDeletedTrades);
               PrintFormat("New trade %i, OrderType=%i, StopPrice=%f", newTrade.TicketId, newTrade.OrderType, newTrade.StopPrice);
           }
         for(int jx=0;jx<totalDeletedTrades;jx++)
           {
               Position * thisDeletedTrade = deletedTrades[jx];
               if(DEBUG_ORDER)
                 {
                  PrintFormat("Examining trade %i: Order Type=%i, StopPrice = %f", 
                     thisDeletedTrade.TicketId, thisDeletedTrade.OrderType, thisDeletedTrade.StopPrice);
                 }
               //if(thisDeletedTrade.StopPrice == 0.0)  continue; //There's no stop loss on the deleted trade, so it doesn't matter
               //if(thisDeletedTrade.OrderType > 1 // Was deleted a pending trade?
               //   && (newTrade.OrderType <= 1) // Is new trade an active trade?
               //   && (thisDeletedTrade.OrderType& 0x01) == (newTrade.OrderType & 0x01) //Are the trades in the same direction?
               //   && thisDeletedTrade.StopPrice == newTrade.StopPrice)  //Then they match
               if(CheckForMatchingPendingTrades(newTrade, thisDeletedTrade))
                 {
                     PrintFormat("Setting IsPending on newTrade %i", newTrade.TicketId);
                     newTrade.IsPending = true;                  
                 }
           }
 }

bool CheckForMatchingPendingTrades(Position * newTrade, Position * deletedTrade)
{
   if(DEBUG_ORDER) PrintFormat("Checking for match to Pending Trade: newTrade %i, deletedTrade %i", newTrade.TicketId, deletedTrade.TicketId);
   if(deletedTrade.StopPrice == 0.0)
     {
         if(DEBUG_ORDER) PrintFormat("deleted trade %i has no stop Loss", deletedTrade.TicketId);
         return false;
     
     }
   if(deletedTrade.OrderType > 1)
     {
      if(newTrade.OrderType <=1)
        {
         if((deletedTrade.OrderType & 0x01) == (newTrade.OrderType & 0x01))
           {
            if(MathAbs(deletedTrade.StopPrice - newTrade.StopPrice) < .000005)
              {
               if(DEBUG_ORDER)PrintFormat("Trades match.");
               return true;
              }
            else if (DEBUG_ORDER) PrintFormat("Stop prices don't match: deletedTrade = %f, newTrade=%f",deletedTrade.StopPrice, newTrade.StopPrice);
           }
         else if (DEBUG_ORDER) PrintFormat("Trades not in same direction: deletedTrade orderType = %i, newTrade orderType = %i", deletedTrade.OrderType, newTrade.OrderType);
        }
      else if (DEBUG_ORDER) PrintFormat("New Trade is not active: orderType = %i", newTrade.OrderType);
     }
   else if (DEBUG_ORDER) PrintFormat("Deleted Trade is not pending: orderType = %i", deletedTrade.OrderType);
   return false;
}

void CreatePendingOrdersForRange( double triggerPrice, int operation, bool setPendingOrders, bool allowForSpread, int margin, int spread)
{
   // Delete any existing pending order of same operation type
   for(int ix=0;ix<totalActiveTrades;ix++)
     {
         if(activeTradesLastTick[ix].IsPending && activeTradesLastTick[ix].OrderType == operation)
           {
            broker.DeletePendingTrade(activeTradesLastTick[ix]);
            activeTrade = activeTradesLastTick[ix];
            HandleDeletedTrade(); // Don't wait for it to be called at next tick.  Do it now.
            break;
           }
     }
   double price;
   if(DEBUG_ORDER)
     {
      string setPendingOrdersString = setPendingOrders? "TRUE" : "FALSE";
      Print ("About to set pending order. setPendingOrders = " +setPendingOrdersString);
     }
   if (!setPendingOrders) return;
   if (operation == OP_SELLSTOP)
      price = triggerPrice  - (margin * Point * FiveDig);
   else
   {
      price = triggerPrice + (margin * Point * FiveDig);
      if (allowForSpread)
         price += spread * Point;
   }
   Position * trade = new Position();
   trade.IsPending = true;
   trade.OpenPrice = price;
   trade.OrderType = operation;
   trade.Symbol = broker.NormalizeSymbol(Symbol());
   trade.LotSize = _pendingLotSize;
   if (PositionSizer) trade.LotSize = CalcTradeSize(PercentRiskPerPosition);      // smz
   if (trade.LotSize == 0) 
   {
      Position * lastTrade = broker.FindLastTrade();
      if (lastTrade != NULL) trade.LotSize = lastTrade.LotSize;
      if(CheckPointer(lastTrade) == POINTER_DYNAMIC)
        {
         delete(lastTrade);
        }
      if(trade.LotSize == 0 && DEBUG_ORDER)
        {
         Print("Configured LotSize = 0 and no historical order found.  LotSize is 0");
        }
   }
   if(DEBUG_ORDER)
     {
      Print("About to place pending order: Symbol=" +trade.Symbol + " Price = " + DoubleToStr(trade.OpenPrice));
     }
   broker.CreateOrder(trade);
   delete(trade);
   
}
//+------------------------------------------------------------------+
//| Create the button                                                |
//+------------------------------------------------------------------+
bool ButtonCreate(const long              chart_ID=0,               // chart's ID
                  const string            name="Button",            // button name
                  const int               sub_window=0,             // subwindow index
                  const int               x=0,                      // X coordinate
                  const int               y=0,                      // Y coordinate
                  const int               width=50,                 // button width
                  const int               height=18,                // button height
                  const ENUM_BASE_CORNER  corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                  const string            text="Button",            // text
                  const string            font="Arial",             // font
                  const int               font_size=10,             // font size
                  const color             clr=clrBlack,             // text color
                  const color             back_clr=C'236,233,216',  // background color
                  const color             border_clr=clrNONE,       // border color
                  const bool              state=false,              // pressed/released
                  const bool              back=false,               // in the background
                  const bool              selection=false,          // highlight to move
                  const bool              hidden=true,              // hidden in the object list
                  const long              z_order=0)                // priority for mouse click
  {
//--- reset the error value
   ResetLastError();
//--- create the button
   if(!ObjectCreate(chart_ID,name,OBJ_BUTTON,sub_window,0,0))
     {
      Print(__FUNCTION__,
            ": failed to create the button! Error code = ",GetLastError());
      return(false);
     }
//--- set button coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set button size
   ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height);
//--- set the chart's corner, relative to which point coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set the text
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
//--- set text font
   ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
//--- set font size
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
//--- set text color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set background color
   ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr);
//--- set border color
   ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_COLOR,border_clr);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- set button state
   ObjectSetInteger(chart_ID,name,OBJPROP_STATE,state);
//--- enable (true) or disable (false) the mode of moving the button by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
  
//+------------------------------------------------------------------+
//| The function receives the chart width in pixels.                 |
//+------------------------------------------------------------------+
int ChartWidthInPixels(const long chart_ID=0)
  {
//--- prepare the variable to get the property value
   long result=-1;
//--- reset the error value
   ResetLastError();
//--- receive the property value
   if(!ChartGetInteger(chart_ID,CHART_WIDTH_IN_PIXELS,0,result))
     {
      //--- display the error message in Experts journal
      Print(__FUNCTION__+", Error Code = ",GetLastError());
     }
//--- return the value of the chart property
   return((int)result);
  }
  
//+------------------------------------------------------------------+
//| The function receives the chart height value in pixels.          |
//+------------------------------------------------------------------+
int ChartHeightInPixelsGet(const long chart_ID=0,const int sub_window=0)
  {
//--- prepare the variable to get the property value
   long result=-1;
//--- reset the error value
   ResetLastError();
//--- receive the property value
   if(!ChartGetInteger(chart_ID,CHART_HEIGHT_IN_PIXELS,sub_window,result))
     {
      //--- display the error message in Experts journal
      Print(__FUNCTION__+", Error Code = ",GetLastError());
     }
//--- return the value of the chart property
   return((int)result);
  } 
  
//+---------------------------------------------------------------------------+
//| The function enables/disables the mode of displaying a price chart on the |
//| foreground.                                                               |
//+---------------------------------------------------------------------------+
bool ChartForegroundSet(const bool value,const long chart_ID=0)
  {
//--- reset the error value
   ResetLastError();
//--- set property value
   if(!ChartSetInteger(chart_ID,CHART_FOREGROUND,0,value))
     {
      //--- display the error message in Experts journal
      Print(__FUNCTION__+", Error Code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return(true);
  }     
  

//+---------------------------------------------------------------------------+
//| Set lock in for open position but trade ID                                |  
//+---------------------------------------------------------------------------+
void SetLockIn(Position *trade)
{
  //trade.StopPrice
}



//+---------------------------------------------------------------------------+
//| The function calculates the postion size based on stop loss level, risk   |
//| per trade and account balance.                                                               |
//+---------------------------------------------------------------------------+
double CalcTradeSize_old()
{
  Alert("Calculating position sizing");
  //PercentRiskPerPosition
  Alert("Account equity = " + string(AccountEquity()));
  Alert("Account free margin = " + string(AccountFreeMargin()));
  Alert("Account credit= " + string(AccountCredit()));
  //Alert("Account free margin = " + AccountInfoDouble());
  //Alert("Account free margin = " + AccountInfoString());
  //Alert("Account free margin = " + AccountInfoInteger());
  Alert("Account leverage = " + string(AccountLeverage()));
  Alert("Account margin = " + string(AccountMargin()));
  Alert("Account profit = " + string(AccountProfit()));
  Alert("Account stopout mode = " + string(AccountStopoutMode()));
  Alert("Account stopout level = " + string(AccountStopoutLevel()));
  Alert("Account balance = " + string(AccountBalance()));
  Print("Account balance = ",AccountBalance());

  double dollarRisk = (AccountFreeMargin()+ LockedInProfit()) * PercentRiskPerPosition;

  double nTickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
  double LotSize = dollarRisk /(stopLoss * nTickValue);
  LotSize = LotSize * Point;
  LotSize=MathRound(LotSize/MarketInfo(Symbol(),MODE_LOTSTEP)) * MarketInfo(Symbol(),MODE_LOTSTEP);
  int stopLossPips  = stopLoss / Point;

  //If the digits are 3 or 5 we normalize multiplying by 10
  if(Digits==3 || Digits==5)
  {
    nTickValue=nTickValue*10;
    stopLossPips = stopLossPips / 10;
  }  

  Alert(string(stopLossPips) + " = " + string(stopLoss) + " / " + string(Point) + " / " + string(nTickValue));
  
  
  Alert("Account free margin = " + string(AccountFreeMargin()) + "\n"
        "point value in the quote currency = " + DoubleToString(Point,5) + "\n"
        "broker lot size = " + string(MarketInfo(Symbol(),MODE_LOTSTEP)) + "\n"
        "PercentRiskPerPosition = " + string(PercentRiskPerPosition*100.0) + "%" + "\n"
        "dollarRisk = " + string(dollarRisk) + "\n"
        "stop loss = " + string(stopLoss) +", " + string(stopLossPips) + " pips" + "\n"
        "locked in = " + string(LockedInPips()) + "(pips)\n"
        "LotSize = " + string(LotSize) + "\n"
        "Ask = " + string(Ask) + "\n"
        "Bid = " + string(Bid) + "\n"
        "Close = " + string(Close[0]) + "\n"
        "MarketInfo(Symbol(),MODE_TICKVALUE) = " + string(MarketInfo(Symbol(),MODE_TICKVALUE)));
  return(LotSize);
}

// show trade info for dev info
//

void ShowTradeInfo(Position *trade)
{
  printf("Account leverage = %f\n",AccountLeverage());
  printf("Account margin = %f\n",AccountMargin());
  Alert(
    "TicketId        = " + string(trade.TicketId) + "\n" +     // = OrderTicket();
    "OrderType       = " + string(trade.OrderType) + "\n"      // = OrderType();
    "IsPending       = " + string(trade.IsPending) + "\n"      // = newTrade.OrderType != OP_BUY && newTrade.OrderType != OP_SELL;
    "Symbol          = " + trade.Symbol + "\n"      // = NormalizeSymbol(OrderSymbol());
    "OrderOpened     = " + string(trade.OrderOpened) + "\n"      // = OrderOpenTime();
    "OpenPrice       = " + string(trade.OpenPrice) + "\n"      // = OrderOpenPrice();
    "ClosePrice      = " + string(trade.ClosePrice) + "\n"      // = OrderClosePrice();
    "OrderClosed     = " + string(trade.OrderClosed) + "\n"      // = OrderCloseTime();
    "StopPrice       = " + string(trade.StopPrice) + "\n"      // = OrderStopLoss();
    "TakeProfitPrice = " + string(trade.TakeProfitPrice) + "\n"      // = OrderTakeProfit();
    "LotSize         = " + string(trade.LotSize) + "\n" );     // = OrderLots();
  return;
}

void WriteFileTradeStats(Position *trade)
{
  Alert("Entered WriteFileTradeStats()");
  string fileName= TimeToStr(TimeCurrent(), TIME_DATE) +
          "_" + "trade_stats";
  StringReplace(fileName, ":", "_");
  fileName += ".csv";
  Alert("Open file " + fileName);


  //int fh1 = FileOpen(fileName, FILE_TXT | FILE_ANSI | FILE_WRITE | FILE_READ);
  int fh1 = FileOpen(fileName, FILE_TXT | FILE_ANSI | FILE_WRITE | FILE_READ | FILE_CSV);
  if (fh1 != -1)
  {
    FileSeek(fh1, 0, SEEK_END);
    ulong filePos = FileTell(fh1);
    if (filePos == 0)// First write to this file
    {
      //FileWriteString(fh1,StringFormat("DataVersion: %i\r\n", DFVersion));
      //FileWriteString(fh1, StringFormat("Server Trade Date: %s\r\n", TimeToString(TimeCurrent(), TIME_DATE)));
      FileWrite(fh1,"Symbol","PIPs","PnL","Point","Digits","LotSize","OpenPrice","ClosePrice","OrderType","OrderClosed",
              "OrderEntered","OrderOpened","StopPrice","Symbol","TakeProfitPrice","TicketId","RealPips","RealPnL");
    }
    double pips = activeTrade.ClosePrice - activeTrade.OpenPrice;
    if (activeTrade.OrderType == OP_SELL) pips *= -1;
    double profit = NormalizeDouble(pips, Digits)/Point * trade.LotSize; 
    FileWrite(fh1,trade.Symbol,DoubleToStr((pips)*MathPow(10,(Digits-1)),Digits),
    DoubleToStr(profit,2),DoubleToStr(Point,Digits),Digits,
    trade.LotSize,trade.OpenPrice,trade.ClosePrice,trade.OrderType,trade.OrderClosed,
    trade.OrderEntered,
    trade.OrderOpened,DoubleToStr(trade.StopPrice,Digits),trade.TakeProfitPrice,trade.TicketId,RealizedPipsAllPairs,RealizedProfitToday());
    //FileWriteString(fh1, StringFormat("Trade ID: %i Initial Stop: %f\r\n", trade.TicketId, trade.StopPrice));
    FileClose(fh1);
  }
  else
  {
      Alert("fh1 is less than -1");
  }
  

}
