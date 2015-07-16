#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef WIN32
#include <windows.h>
#else
#include <pthread.h>
#endif


#define SAMPLE_RATE   (44100)
#define FRAMES_PER_BUFFER  (32)


struct StereoFloatSample {
	float left;
	float right;
};

 
/* Circular buffer object */
template <typename T> 
struct CircularBuffer {
    int         size;   /* maximum number of elements           */
    int         start;  /* index of oldest element              */
    int         end;    /* index at which to write new element  */
	int			num;
    T   *elems;  /* vector of elements                   */

#ifdef WIN32
#define MUTEX_FUNC_LOCK(m) EnterCriticalSection(m)
#define MUTEX_FUNC_UNLOCK(m) LeaveCriticalSection(m)

	CRITICAL_SECTION criticalSection;
#else
#define MUTEX_FUNC_LOCK(m) pthread_mutex_lock(m)
#define MUTEX_FUNC_UNLOCK(m) pthread_mutex_unlock(m)

	pthread_mutex_t criticalSection;
#endif

	void Init(int size)
	{
		this->size  = size + 1; /* include empty elem */
		this->start = 0;
		this->end   = 0;
		this->num = 0;
		this->elems = (T *)calloc(this->size, sizeof(T));
#ifdef WIN32
		InitializeCriticalSection(&this->criticalSection);
#else
		criticalSection = PTHREAD_MUTEX_INITIALIZER;
#endif
	}
	void Free() {  free(this->elems);
#ifdef WIN32
	DeleteCriticalSection(&criticalSection);
#endif
	}
	int isFull() { return (this->end + 1) % this->size == this->start; }
	int isEmpty() { return this->end == this->start; }
	int Write(T &elem) {
		int ret = 0;
		
		MUTEX_FUNC_LOCK(&criticalSection);
		this->elems[this->end] = elem;
		this->end = (this->end + 1) % this->size;
		if (this->end == this->start) {
			this->start = (this->start + 1) % this->size; /* full, overwrite */
			ret = 1;
		} else
			this->num++;
		MUTEX_FUNC_UNLOCK(&criticalSection);
		
		return ret;
	}
	T Read() {
		MUTEX_FUNC_LOCK(&criticalSection);
		T elem = this->elems[this->start];
		this->start = (this->start + 1) % this->size;
		this->num--;
		MUTEX_FUNC_UNLOCK(&criticalSection);
		return elem;
		
	}

	inline float GetNum() { return this->num; }
	
	inline float GetUsagePercentage() { return (((float)this->num / (float)this->size) * 100.0f); }

	void PrintUsageBar() {
		 char bar[128];
		 float bufPerc = this->GetUsagePercentage();
		 bufPerc = (bufPerc > 99.9f) ? 100.0f : bufPerc;
		 memset(bar, '=', sizeof(bar));
		 bar[(int)bufPerc] = '\0';
		 printf("Buffer: %6.2f %%  %s\r\n", bufPerc, bar);
	}
};
