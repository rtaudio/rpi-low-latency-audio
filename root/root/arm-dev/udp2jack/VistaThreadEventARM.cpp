#include "VistaThreadEventARM.h"
#include <cerrno>

	
VistaThreadEvent::VistaThreadEvent(bool bCreatePosix): autoreset(true), state(0) {
	pthread_mutex_init(&mtx, 0);
	pthread_cond_init(&cond, 0);
}

VistaThreadEvent::~VistaThreadEvent()
{
	pthread_cond_destroy(&cond);
	pthread_mutex_destroy(&mtx);
}

void VistaThreadEvent::SignalEvent()
{
	pthread_mutex_lock(&mtx);
	state = 1;
	if (autoreset)
		pthread_cond_signal(&cond);
	else
		pthread_cond_broadcast(&cond);
	pthread_mutex_unlock(&mtx);
}

long VistaThreadEvent::WaitForEvent(int msecs)
{
	pthread_mutex_lock(&mtx);
	if (state == 0)
	{
		struct timespec tv;
		tv.tv_sec  = (msecs != 0) ? (msecs / 1000000) : 0;
		tv.tv_nsec = (msecs != 0) ? (msecs % 1000000) : 0;

		if(pthread_cond_timedwait(&cond, &mtx, &tv) == ETIMEDOUT)
			return 0;
	}
	if (autoreset)
		state = 0;
	pthread_mutex_unlock(&mtx);
  return 1;

}

long VistaThreadEvent::WaitForEvent(bool bBlock)
{
	pthread_mutex_lock(&mtx);
	if (state == 0)
		pthread_cond_wait(&cond, &mtx);
	if (autoreset)
		state = 0;
	pthread_mutex_unlock(&mtx);
  return 1;
}

bool VistaThreadEvent::ResetThisEvent()
{
	pthread_mutex_lock(&mtx);
	state = 0;
	pthread_mutex_unlock(&mtx);
	return true;
}
