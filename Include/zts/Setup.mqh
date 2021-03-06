//+------------------------------------------------------------------+
//|                                                        Setup.mqh |
//|                                                    Stephen Zagar |
//|                                                 https://www..com |
//+------------------------------------------------------------------+
#property copyright "Stephen Zagar"
#property link      "https://www..com"
#property version   "1.00"
#property strict

#include <zts/MagicNumber.mqh>

// CFoo(string name) : m_name(name) { Print(m_name);}
//--- The base class Setup
class Setup {
protected:
public:
  string symbol;
  Enum_SIDE side;
  bool goLong;
  bool goShort;
  bool callOnTick;
  bool callOnBar;
  string strategyName;
  int roboID;
  int tradeNumber;
  bool triggered;
  MagicNumber *magic;
  
  Setup();
  Setup(string,Enum_SIDE);  // : symbol(_symbol) {};  //{} // constructor

  //virtual bool triggered(){return false;};
  virtual void OnInit() {
    Debug4(__FUNCTION__,__LINE__,"Setup::OnInit");
  };
  virtual void OnTick() {
    Debug4(__FUNCTION__,__LINE__,"Setup::OnTick");
  };
  virtual void OnBar() {
    Debug4(__FUNCTION__,__LINE__,"Setup::OnBar");
  };
  virtual void startOfDay() { };
  void reset() {triggered=false;};  
};


Setup::Setup() {
  symbol = Symbol();
  magic = new MagicNumber();
  triggered = false;
}

Setup::Setup(string _symbol,Enum_SIDE _side) {
  symbol = _symbol;
  side = _side;
  goLong = false;
  goShort = false;
  callOnTick = false;
  callOnBar = false;
  if(side == Long) goLong = true;
  if(side == Short) goShort = true;
  magic = new MagicNumber();
  triggered = false;
}

  
