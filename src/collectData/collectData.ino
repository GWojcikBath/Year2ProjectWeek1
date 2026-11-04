#include <ESP32TimerInterrupt.h>

ESP32Timer ITimer0(0);

bool dataReady = false;
uint64_t interruptCount = 0;
uint64_t skippedCount = 0;
int dataLogged = 0;

bool IRAM_ATTR TimerHandler0(void * timerNo)
{
	if (dataReady == true){
		skippedCount++;
	}
	dataLogged = analogRead(4);
	dataReady = true;
	interruptCount++;
	return true;
}

void setup()
{
    Serial.begin(2000000);
    pinMode(4, INPUT);

    if (ITimer0.attachInterruptInterval(200, TimerHandler0))
		{
			Serial.print(F("Starting  ITimer0 OK, millis() = "));
			Serial.println(millis());
		}
		else
			Serial.println(F("Can't set ITimer0. Select another freq. or timer"));

    Serial.flush();
}
void loop()
{
    // Do Nothing!
	if (dataReady){
		Serial.println(dataLogged);
		dataReady = false;
	}
}