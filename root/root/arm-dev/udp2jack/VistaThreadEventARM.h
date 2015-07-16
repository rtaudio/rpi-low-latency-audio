#pragma once

#include <pthread.h>

#include <time.h>

class VistaThreadEvent
{
private:
	/**
	 *
	 */
	pthread_mutex_t mtx;
	pthread_cond_t cond;
	int state;
	bool autoreset;
protected:
public:

	/**
	 *
	 */
	VistaThreadEvent(bool bCreatePosix=false);

	/**
	 *
	 */
	virtual ~VistaThreadEvent();


	/**
	 *
	 */
	void SignalEvent();

	/**
	 *
	 */
	long WaitForEvent(bool bBlock);

	/**
	 *
	 */
	long WaitForEvent(int iBlockTime);

	bool ResetThisEvent();
};
