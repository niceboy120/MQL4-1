//--------------------------------------------------------------------
// rocseparate.mq4 (Priliv_s)
// Ïðåäíàçíà÷åí äëÿ èñïîëüçîâàíèÿ â êà÷åñòâå ïðèìåðà â ó÷åáíèêå MQL4.
//--------------------------------------------------------------- 1 --
#property copyright "Copyright © SK, 2007"
#property link      "http://AutoGraf.dp.ua"
//--------------------------------------------------------------------
#property indicator_separate_window // Èíäèê.ðèñóåòñÿ â îòäåëüíîì îêíå
#property indicator_buffers 6       // Êîëè÷åñòâî áóôåðîâ
#property indicator_color1 Black    // Öâåò ëèíèè 0 áóôåðà
#property indicator_color2 DarkOrange//Öâåò ëèíèè 1 áóôåðà
#property indicator_color3 Green    // Öâåò ëèíèè 2 áóôåðà
#property indicator_color4 Brown    // Öâåò ëèíèè 3 áóôåðà
#property indicator_color5 Blue     // Öâåò ëèíèè 4 áóôåðà
#property indicator_color6 Red      // Öâåò ëèíèè 5 áóôåðà
#property indicator_level1 0
//--------------------------------------------------------------- 2 --
extern int History    =5000;        // Êîëè÷.áàðîâ â ðàñ÷¸òíîé èñòîðèè
extern int Period_MA_1=21;          // Ïåðèîä ðàñ÷¸òíîé ÌÀ
extern int Bars_V     =13;          // Êîëè÷.áàðîâ äëÿ ðàñ÷¸òà ñêîðîñò
extern int Aver_Bars  =5;           // Êîëè÷. áàðîâ äëÿ ñãëàæèâàíèÿ
//--------------------------------------------------------------- 3 --
int
   Period_MA_2,  Period_MA_3,       // Ðàñ÷¸òíûå ïåðèîäû ÌÀ äëÿ äð. ÒÔ
   K2, K3;                          // Êîýôôèöèåíòû ñîîòíîøåíèÿ ÒÔ
double
   Line_0[],                        // Indicator array of supp. MA
   Line_1[], Line_2[], Line_3[],    // Indicator array of rate lines 
   Line_4[],                        // Indicator array - sum
   Line_5[],                        // Indicator array - sum, smoothed
   Sh_1, Sh_2, Sh_3;                // Amount of bars for rates calc.
//--------------------------------------------------------------- 4 --
int init()                          // Ñïåöèàëüíàÿ ôóíêöèÿ init()
  {
   SetIndexBuffer(0,Line_0);        // Assigning an array to a buffer
   SetIndexBuffer(1,Line_1);        
   SetIndexBuffer(2,Line_2);        
   SetIndexBuffer(3,Line_3);        
   SetIndexBuffer(4,Line_4);        
   SetIndexBuffer(5,Line_5);        
   SetIndexStyle (5,DRAW_LINE,STYLE_SOLID,3);// Ñòèëü ëèíèè
//--------------------------------------------------------------- 5 --
   switch(Period())                 // Calculating coefficient for..
     {                              // .. different timeframes
      case     1: K2=5;K3=15; break;// Timeframe M1
      case     5: K2=3;K3= 6; break;// Timeframe M5
      case    15: K2=2;K3= 4; break;// Timeframe M15
      case    30: K2=2;K3= 8; break;// Timeframe M30
      case    60: K2=4;K3=24; break;// Timeframe H1
      case   240: K2=6;K3=42; break;// Timeframe H4
      case  1440: K2=7;K3=30; break;// Timeframe D1
      case 10080: K2=4;K3=12; break;// Timeframe W1
      case 43200: K2=3;K3=12; break;// Timeframe MN
     }
//--------------------------------------------------------------- 6 --
   Sh_1=Bars_V;                     // Period of rate calcul. (bars)
   Sh_2=K2*Sh_1;                    // Calc. period for nearest TF
   Sh_3=K3*Sh_1;                    // Calc. period for next TF
   Period_MA_2 =K2*Period_MA_1;     // Calc. period of MA for nearest TF
   Period_MA_3 =K3*Period_MA_1;     // Calc. period of MA for next TF
//--------------------------------------------------------------- 7 --
   return(INIT_SUCCEEDED);                          // 
  }
//--------------------------------------------------------------- 8 --
int start()                         // 
  {
//--------------------------------------------------------------- 9 --
   double
   MA_c, MA_p,                      // Current and previous MA values
   Sum;                             // Technical param. for sum accumul.
   int
   i,                               // Èíäåêñ áàðà
   n,                               // Ôîðìàëüí. ïàðàìåòð(èíäåêñ áàðà)
   Counted_bars;                    // Êîëè÷åñòâî ïðîñ÷èòàííûõ áàðîâ 
//-------------------------------------------------------------- 10 --
   Counted_bars=IndicatorCounted(); // Êîëè÷åñòâî ïðîñ÷èòàííûõ áàðîâ 
   i=Bars-Counted_bars-1;           // Èíäåêñ ïåðâîãî íåïîñ÷èòàííîãî
   if (i>History-1)                 // Åñëè ìíîãî áàðîâ òî ..
      i=History-1;                  // ..ðàññ÷èòûâàòü çàäàííîå êîëè÷.
//-------------------------------------------------------------- 11 --
   while(i>=0)                      // Öèêë ïî íåïîñ÷èòàííûì áàðàì
     {
      //-------------------------------------------------------- 12 --
      Line_0[i]=0;                  // Ãîðèçîíòàëüíàÿ ëèíèÿ îòñ÷¸òà
      //-------------------------------------------------------- 13 --
      MA_c=iMA(NULL,0,Period_MA_1,0,MODE_LWMA,PRICE_TYPICAL,i);
      MA_p=iMA(NULL,0,Period_MA_1,0,MODE_LWMA,PRICE_TYPICAL,i+Sh_1);
      Line_1[i]= MA_c-MA_p;         // Çíà÷åíèå 1 ëèíèè ñêîðîñòè
      //-------------------------------------------------------- 14 --
      MA_c=iMA(NULL,0,Period_MA_2,0,MODE_LWMA,PRICE_TYPICAL,i);
      MA_p=iMA(NULL,0,Period_MA_2,0,MODE_LWMA,PRICE_TYPICAL,i+Sh_2);
      Line_2[i]= MA_c-MA_p;         // Çíà÷åíèå 2 ëèíèè ñêîðîñòè
      //-------------------------------------------------------- 15 --
      MA_c=iMA(NULL,0,Period_MA_3,0,MODE_LWMA,PRICE_TYPICAL,i);
      MA_p=iMA(NULL,0,Period_MA_3,0,MODE_LWMA,PRICE_TYPICAL,i+Sh_3);
      Line_3[i]= MA_c-MA_p;         // Çíà÷åíèå 3 ëèíèè ñêîðîñòè
      //-------------------------------------------------------- 16 --
      Line_4[i]=(Line_1[i]+Line_2[i]+Line_3[i])/3;// Ñóììàðíûé ìàññèâ
      //-------------------------------------------------------- 17 --
      if (Aver_Bars<0)              // Åñëè íåâåðíî çàäàíî ñãëàæèâàíèå
         Aver_Bars=0;               // .. òî íå ìåíüøå íóëÿ
      Sum=0;                        // Òåõíè÷åñêèé ïðè¸ì
      for(n=i; n<=i+Aver_Bars; n++) // Ñóììèðîâàåíèå ïîñëåäíèõ çíà÷åí.
         Sum=Sum + Line_4[n];       // Íàêîïëåíèå ñóììû ïîñëåäí. çíà÷.
      Line_5[i]= Sum/(Aver_Bars+1); // Èíäèê. ìàññèâ ñãëàæåííîé ëèíèè
      //-------------------------------------------------------- 18 --
      i--;                          // Ðàñ÷¸ò èíäåêñà ñëåäóþùåãî áàðà
      //-------------------------------------------------------- 19 --
     }
   return;                          // Âûõîä èç ñïåö. ô-èè start()
  }
//-------------------------------------------------------------- 20 --