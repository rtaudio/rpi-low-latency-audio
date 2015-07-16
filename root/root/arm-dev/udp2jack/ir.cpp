#include <stdio.h>
#include <sys/ioctl.h>
#include <sys/file.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <cstdlib>
#include <math.h>

#include "lirc.h"

#define BIT_PERIOD 1000

inline void get_bits(char c, char *bits, int n = 8) {
	for(int i = 0; i < n; i++)
		bits[i] = (c & ( 1 << i )) >> i;	
}

inline char from_bits(char *bits, int n = 8) {
	char c = 0;
	for(int i = 0; i < n; i++) {
		if(bits[i])
			c = c | ( 1 << i );
	}
	return c;
}

int ir_fd;


int ir_init()
{
	char *device = "/dev/lirc0";
	unsigned int freq = 38000;
	unsigned int duty_cycle = 50;
	
	
	int fd;	
	__u32 features;	
	
	if ((fd = open(device, O_RDWR)) < 0) {
		printf("Could not open device %s!\n", device);
		return (0);
	}
	
	if (ioctl(fd, LIRC_GET_FEATURES, &features) == -1) {
		printf("Could not get features of device %s\n", device);
		close(fd);
		return 0;
	}
	
	if ( (!LIRC_CAN_SEND(features)) || (!LIRC_CAN_REC(features))) {
		printf("Driver does not support both sending and receiving (%d/%d)\n",LIRC_CAN_SEND(features), LIRC_CAN_REC(features)  );
		close(fd);
		return 0;
	}		
	
	if(ioctl(fd, LIRC_SET_SEND_CARRIER, &freq) == -1) {
		printf("Could not set frequency %d\n", freq);
		close(fd);
		return 0;
	}
	
	if(ioctl(fd, LIRC_SET_SEND_DUTY_CYCLE, &duty_cycle) == -1) {
		printf("Could not set duty cycle %d\n", duty_cycle);
		close(fd);
		return 0;
	}

	ir_fd = fd;	
}

int ir_send_sync(char idx)
{
	char data_bits[255];
	int timings[255];
	int i = 0, t = 0, d = 0;

	// start with 11
	data_bits[i++] = 1;
	data_bits[i++] = 0;
	
	//get_bits('s', &data_bits[i], 8); i+=8;
	get_bits('Y', &data_bits[i], 8); i+=8;
	
	// send it 2 times!
	get_bits(idx, &data_bits[i], 4); i+=4;
	get_bits(idx, &data_bits[i], 4); i+=4;
	
	// end with 11
	data_bits[i++] = 1;
	data_bits[i++] = 1;
	
	
	char p = 1;
	for(t = 0; (t < 255) && (d < i); t++) {
		timings[t] = 0;
		while(data_bits[d] == p) {
			timings[t] += BIT_PERIOD;
			d++;
			if(d >= i) break;
		}
		p = !p;
	}	

	// make sure t is odd!
	if((t % 2) == 0) t--;
	
	int ret;
	if((ret=write(ir_fd, timings, t*sizeof(int))) == -1) {
		printf("Sending IR data failed!\n");
		return 0;
	}			

	return 1;
}

inline int read_timeout(int fd, char *buf, int len, int timeout_sec, int timeout_usec = 0)
{
	fd_set fds;
	struct timeval tv;
	int ret, n;

	FD_ZERO(&fds);
	FD_SET(fd, &fds);
	tv.tv_sec = timeout_sec;
	tv.tv_usec = timeout_usec;

	/* CAVEAT: (from libc documentation)
	   Any signal will cause `select' to return immediately.  So if your
	   program uses signals, you can't rely on `select' to keep waiting
	   for the full time specified.  If you want to be sure of waiting
	   for a particular amount of time, you must check for `EINTR' and
	   repeat the `select' with a newly calculated timeout based on the
	   current time.  See the example below.

	   Obviously the timeout is not recalculated in the example because
	   this is done automatically on Linux systems...
	 */

	do {
		ret = select(fd + 1, &fds, NULL, NULL, &tv);
	}
	while (ret == -1 && errno == EINTR);
	if (ret == -1) {
		printf("select() failed\n");
		return (-1);
	} else if (ret == 0)
		return (0);	/* timeout */
	n = read(fd, buf, len);
	if (n == -1) {
		printf("read() failed\n");
		return (-1);
	}
	return (n);
}

int ir_read_sync(timespec *t_first)
{
	int data[200];

	int ret = read_timeout(ir_fd, (char*)&data[0], sizeof(int)*1, 0, 1000*1000); // 1 sec timeout
	if(ret <= 0)
		return -1;
	
	clock_gettime(CLOCK_REALTIME, t_first);
	
	int i;
	for(i = 1; i < 200;) {
		ret = read_timeout(ir_fd, (char*)&data[i], sizeof(int)*4, 0, 1000*5); // 5ms timeout
		if(ret == 0) {
			break; // on timeout
		}else if(ret == -1) {
			printf("Read failed!\n");
			exit(0);
		} else {
			if(ret % sizeof(int) != 0) {
				printf("Read bytes % 4 != 0!\n");
				exit(0);
			}				
			i += ret / sizeof(int);
		}
	}
	
	int sum = 0;
	char data_bits[255];
	int d = 0;
	
	for(int j = 2; j < i; j++) {
		data[j] &= PULSE_MASK;
		sum += data[j];	
		
		if(sum > BIT_PERIOD * 250) break;
		
		for(int t = 0; t < (int)floor(0.5 + ( (float)data[j] / (float)BIT_PERIOD)); t++) {
			data_bits[d++] = (j%2);
			if(d >= 255) break;
		}
	}
	
	if(d >= 19) {
		char header = from_bits(&data_bits[3],8);
		if(header == 'Y' &&  (data_bits[11]==data_bits[11+4]&&data_bits[12]==data_bits[12+4]&&data_bits[13]==data_bits[13+4]&&data_bits[14]==data_bits[14+4])) {
			char num = from_bits(&data_bits[11], 4);
			return num;
		}
	}
	
	// invalid header or data
	return -1;
}
