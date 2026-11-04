/* 
  MyoWare Example_01_analogRead_SINGLE 
  SparkFun Electronics 
  Pete Lewis 
  3/24/2022 
  License: This code is public domain but you buy me a beverage if you use this and we meet someday. 
  This code was adapted from the MyoWare analogReadValue.ino example found here: 
  https://github.com/AdvancerTechnologies/MyoWare_MuscleSensor 
  This example streams the data from a single MyoWare sensor attached to ADC A0. 
  Graphical representation is available using Serial Plotter (Tools > Serial Plotter menu). 
  
  *Only run on a laptop using its battery. Do not plug in laptop charger/dock/monitor. 
  *Do not touch your laptop trackpad or keyboard while the MyoWare sensor is powered. 
  Hardware: 
  SparkFun RedBoard Artemis (or Arduino of choice) 
  USB from Artemis to Computer. 
  Output from sensor connected to your Arduino pin A0 
  This example code is in the public domain. 
*/ 

/*
  From here on, the code has been modified completely by Gabriel Wojcik, GW803
*/

#include <TimerOne.h>

void Timer1_ISR(void)
{
  int value = analogRead(A0);
  Serial.println(value);
}

void setup()  
{
  Serial.begin(250000); 
  while (!Serial); // optionally wait for serial terminal to open 
  pinMode(A0, INPUT);

  Timer1.initialize(100);   // 10khz sampling rate
  Timer1.attachInterrupt(Timer1_ISR);
} 

void loop()  
{
} 